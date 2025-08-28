///|
/// TODO
/// https://github.com/WebAssembly/gc/blob/main/proposals/gc/Post-MVP.md#weak-references
/// wasm and wasm-gc can't support weak ref now.
typealias Array as WeakArray

///|
typealias WeakArray[Node] as IncomingEdges

///|
typealias Array[Node] as OutgoingEdges

///|
struct Cell[A] {
  id : Int
  mut value : A
  incoming_edges : IncomingEdges
}

///|
struct Thunk[A] {
  id : Int
  mut value : A?
  incoming_edges : IncomingEdges
  outgoing_edges : OutgoingEdges
  thunk : () -> A
  mut flag : Flag
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
}

///|
priv trait Target: Source {
  outgoing_edges(Self) -> OutgoingEdges
  update(Self) -> Bool
  set_flag(Self, Flag) -> Unit
  flag(Self) -> Flag
}

///|
typealias &Target as Node

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
            self.outgoing_edges().clear()
            self.incoming_edges().clear()
            self.update()
          } else {
            false
          }
      }
    }
  }
}

///|
/// do not short-circuit.
/// f isn't pure function. in other words, f has side effect.
fn[A] any(xs : Array[A], f : (A) -> Bool) -> Bool {
  let mut res = false
  for x in xs {
    res = res || f(x)
  }
  res
}

///|
pub impl[A] Source for Thunk[A] with id(self) {
  self.id
}

///|
pub impl[A] Source for Cell[A] with id(self) {
  self.id
}

///|
pub impl[A] Eq for Thunk[A] with op_equal(self, other) {
  self.id == other.id
}

///|
pub impl[A] Eq for Cell[A] with op_equal(self, other) {
  self.id == other.id
}

///|
pub impl[A] Hash for Thunk[A] with hash_combine(self, hasher) {
  self.id.hash_combine(hasher)
}

///|
pub impl[A] Hash for Cell[A] with hash_combine(self, hasher) {
  self.id.hash_combine(hasher)
}

///|
let node_counter : Ref[Int] = Ref::new(0)

///|
fn next_id() -> Int {
  node_counter.update(x => x + 1)
  node_counter.val
}

///|
pub fn[A] Thunk::new(thunk : () -> A) -> Thunk[A] {
  {
    id: next_id(),
    value: None,
    thunk,
    incoming_edges: [],
    outgoing_edges: [],
    flag: Clean,
  }
}

///|
pub fn[A] Cell::new(value : A) -> Cell[A] {
  { id: next_id(), value, incoming_edges: [] }
}

///|
/// The same as `Thunk::new`
pub fn[A] thunk(thunk : () -> A) -> Thunk[A] {
  Thunk::new(thunk)
}

///|
/// The same as `Cell::new`
pub fn[A] cell(value : A) -> Cell[A] {
  Cell::new(value)
}

///|
pub fn[A : Eq] Cell::set(self : Cell[A], value : A) -> Unit {
  if self.value != value {
    self.value = value
    for dependent in self.incoming_edges() {
      &Target::dirty(dependent)
    }
  }
}

///|
pub fn[A : Eq] Cell::modify(self : Cell[A], f : (A) -> A) -> Unit {
  self.set(f(self.get()))
}

///|
let target_stack : Array[&Target] = []

///|
pub fn[A : Eq] Thunk::get(self : Thunk[A]) -> A {
  if target_stack.last() is Some(target) {
    self.incoming_edges.push(target)
    target.outgoing_edges().push(self)
  }
  match self.value {
    None => self.update() |> ignore
    Some(_) => &Target::propagate(self) |> ignore
  }
  self.value.unwrap()
}

///|
pub fn[A] Cell::get(self : Cell[A]) -> A {
  if target_stack.last() is Some(target) {
    self.incoming_edges.push(target)
  }
  self.value
}

///|
typealias Array[() -> Unit] as MemoTables

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
pub fn[A : Hash + Eq, B] memo(f : (A) -> B) -> (A) -> Thunk[B] {
  let h = {}
  memo_tables.push(fn() { h.clear() })
  fn(x) {
    match h.get(x) {
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
pub fn[A : Hash + Eq, B] memo_rec(
  f : ((A) -> Thunk[B], A) -> B,
) -> (A) -> Thunk[B] {
  let h : Map[A, Thunk[B]] = {}
  memo_tables.push(fn() { h.clear() })
  fn g(x : A) -> Thunk[B] {
    match h.get(x) {
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
  self.outgoing_edges
}

///|
/// if actually update then return true else false
impl[A : Eq] Target for Thunk[A] with update(self) {
  target_stack.push(self)
  self.flag = Clean
  let old = self.value
  let new = Some((self.thunk)())
  self.value = new
  target_stack.unsafe_pop() |> ignore
  old != new
}

///|
impl[A : Eq] Target for Thunk[A] with flag(self) {
  self.flag
}

///|
impl[A : Eq] Target for Thunk[A] with set_flag(self, flag) {
  self.flag = flag
}

///|
pub impl[A] Source for Cell[A] with incoming_edges(self) {
  self.incoming_edges
}

///|
pub impl[A] Source for Thunk[A] with incoming_edges(self) {
  self.incoming_edges
}
