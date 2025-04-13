///| TODO
/// https://github.com/WebAssembly/gc/blob/main/proposals/gc/Post-MVP.md#weak-references
/// wasm and wasm-gc can't support weak ref now.
typealias WeakArray[A] = Array[A]

///|
typealias IncomingEdges = WeakArray[Node]

///|
typealias OutgoingEdges = Array[Node]

///|
struct Cell[A] {
  _id : Int
  mut _value : A
  _incoming_edges : IncomingEdges
}

///|
struct Thunk[A] {
  _id : Int
  mut _value : A?
  _incoming_edges : IncomingEdges
  mut _outgoing_edges : OutgoingEdges
  _thunk : () -> A
  mut _flag : Flag
}

///|
fn Thunk::debug_string[A](self : Thunk[A]) -> String {
  "{ id : \{self._id}, out: \{self._outgoing_edges}, in: \{self._incoming_edges}}"
}

///|
fn Cell::debug_string[A](self : Cell[A]) -> String {
  "{ id : \{self._id}, in: \{self._incoming_edges}}"
}

///|
priv enum Flag {
  Clean
  Dirty
} derive(Eq, Show)

///|
trait Source {
  id(Self) -> Int
  incoming_edges(Self) -> IncomingEdges
  to_node(Self) -> Node?
}

///|
impl Show for &Source with output(self, logger) {
  logger.write_object(self.id())
}

///|
impl Show for &Target with output(self, logger) {
  logger.write_object(self.id())
}

///|
priv trait Target: Source {
  outgoing_edges(Self) -> OutgoingEdges
  update(Self) -> Bool
  set_flag(Self, Flag) -> Unit
  flag(Self) -> Flag
}

///|
typealias Node = &Target

///|
/// invairent: 
/// If a node is clean, 
/// then all transitively reachable nodes from the incoming edge of this node are clean
fn &Target::dirty(self : Node) -> Unit {
  match self.flag() {
    Clean => {
      self.set_flag(Dirty)
      for dependent in self.incoming_edges() {
        &Target::dirty(dependent)
      }
    }
    Dirty => ()
  }
}

///|
/// invairent:
/// If a node is dirty
/// then all transitively reachable nodes from the outgoing edge of this node are dirty
fn &Target::propagate(self : Node) -> Bool {
  match self.flag() {
    Clean => true
    Dirty => {
      self.set_flag(Clean)
      match self.outgoing_edges() {
        [] => self.update()
        [..] as xs =>
          if any(xs, &Target::propagate) {
            self.update()
          } else {
            false
          }
      }
    }
  }
}

///| do not short-circuit.
/// f isn't pure function. in other words, f has side effect.
fn any[A](xs : Array[A], f : (A) -> Bool) -> Bool {
  let mut res = false
  for x in xs {
    res = res || f(x)
  }
  res
}

///|
pub impl[A : Eq] Source for Thunk[A] with id(self) {
  self._id
}

///|
pub impl[A : Eq] Source for Cell[A] with id(self) {
  self._id
}

///|
pub impl[A] Eq for Thunk[A] with op_equal(self, other) {
  self._id == other._id
}

///|
pub impl[A] Eq for Cell[A] with op_equal(self, other) {
  self._id == other._id
}

///|
pub impl[A] Hash for Thunk[A] with hash_combine(self, hasher) {
  self._id.hash_combine(hasher)
}

///|
pub impl[A] Hash for Cell[A] with hash_combine(self, hasher) {
  self._id.hash_combine(hasher)
}

///|
let node_counter : Ref[Int] = Ref::new(0)

///|
fn next_id() -> Int {
  node_counter.update(fn { x => x + 1 })
  node_counter.val
}

///|
pub fn Thunk::new[A : Eq](thunk : () -> A) -> Thunk[A] {
  {
    _id: next_id(),
    _value: None,
    _thunk: thunk,
    _incoming_edges: [],
    _outgoing_edges: [],
    _flag: Clean,
  }
}

///|
pub fn Cell::new[A : Eq](value : A) -> Cell[A] {
  { _id: next_id(), _value: value, _incoming_edges: [] }
}

///|
pub fn Cell::set[A : Eq](self : Cell[A], value : A) -> Unit {
  if self._value != value {
    self._value = value
    for dependent in self.incoming_edges() {
      &Target::dirty(dependent)
    }
  }
}

///|
pub fn Cell::modify[A : Eq](self : Cell[A], f : (A) -> A) -> Unit {
  self.set(f(self.get()))
}

///|
let target_stack : Array[&Target] = []

///|
pub fn Thunk::get[A : Eq](self : Thunk[A]) -> A {
  if not(target_stack.is_empty()) {
    let target = target_stack.last().unwrap()
    self._incoming_edges.push(target)
    target.outgoing_edges().push(self)
  }
  if self._value.is_empty() {
    target_stack.push(self)
    self.update() |> ignore
    target_stack.unsafe_pop() |> ignore
  }
  &Target::propagate(self) |> ignore
  self._value.unwrap()
}

///|
pub fn Cell::get[A : Eq](self : Cell[A]) -> A {
  if not(target_stack.is_empty()) {
    let target = target_stack.last().unwrap()
    self._incoming_edges.push(target)
  }
  self._value
}

///|
typealias Clear = () -> Unit

///|
typealias MemoTables = Array[Clear]

///|
let memo_tables : MemoTables = []

///|
pub fn clear_memo() -> Unit {
  for x in memo_tables {
    x()
  }
  memo_tables.clear()
}

///|
pub fn memo[A : Hash + Eq, B : Eq](f : (A) -> B) -> (A) -> Thunk[B] {
  let h = {}
  memo_tables.push(fn() { h.clear() })
  fn(x) {
    match h[x] {
      None => {
        let r = Thunk::new(fn() { f(x) })
        h[x] = r
        r
      }
      Some(r) => r
    }
  }
}

///|
pub fn memo_rec[A : Hash + Eq, B : Eq](
  f : ((A) -> Thunk[B], A) -> B
) -> (A) -> Thunk[B] {
  let h : Map[A, Thunk[B]] = {}
  memo_tables.push(fn() { h.clear() })
  fn g(x : A) -> Thunk[B] {
    match h[x] {
      None => {
        let r = Thunk::new(fn() { f(g, x) })
        h[x] = r
        r
      }
      Some(r) => r
    }
  }

  g
}

///|
impl[A : Eq] Target for Thunk[A] with outgoing_edges(self) {
  self._outgoing_edges
}

///|
/// if actually update then return true else false
impl[A : Eq] Target for Thunk[A] with update(self) {
  self._flag = Clean
  let old = self._value
  let new = Some((self._thunk)())
  self._value = new
  old != new
}

///|
impl[A : Eq] Target for Thunk[A] with flag(self) {
  self._flag
}

///|
impl[A : Eq] Target for Thunk[A] with set_flag(self, flag) {
  self._flag = flag
}

///|
pub impl[A : Eq] Source for Cell[A] with to_node(self) {
  None
}

///|
pub impl[A : Eq] Source for Thunk[A] with to_node(self) {
  Some(self)
}

///|
pub impl[A : Eq] Source for Cell[A] with incoming_edges(self) {
  self._incoming_edges
}

///|
pub impl[A : Eq] Source for Thunk[A] with incoming_edges(self) {
  self._incoming_edges
}
