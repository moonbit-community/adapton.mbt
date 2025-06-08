///|
test "in degree > 1" {
  let mut cnt = 0
  let a = Cell::new(1)
  let b0 = Thunk::new(fn() {
    cnt += 1
    a.get() * 2
  })
  let b1 = Thunk::new(fn() {
    cnt += 1
    a.get() * 3
  })
  let c = Thunk::new(fn() {
    cnt += 1
    b0.get() + b1.get()
  })
  inspect!(b1.get(), content="3")
  inspect!(c.get(), content="5")
  inspect!(cnt, content="3")
  a.set(20)
  inspect!(cnt, content="3")
  inspect!(c.get(), content="100")
  inspect!(cnt, content="6")
}

///|
test "propagate" {
  let mut cnt = 0
  let x = Cell::new(2)
  let y = Cell::new(3)
  let z = Thunk::new(fn() {
    cnt += 1
    x.get() * y.get()
  })
  let w = Thunk::new(fn() {
    cnt += 1
    z.get() + 1
  })
  inspect!(w.get(), content="7")
  inspect!(cnt, content="2")
  // swap x and y
  x.set(3)
  y.set(2)
  inspect!(w.get(), content="7")
  inspect!(cnt, content="3") // cnt: +1
  // incr x and incr y 
  x.modify(fn { x => x + 1 })
  y.modify(fn { y => y + 1 })
  inspect!(w.get(), content="13")
  inspect!(cnt, content="5") // cnt: +2
}

///|
test "sum" {
  let xs = Array::makei(1024, Cell::new)
  let mut cnt = 0
  fn add(x, y) {
    cnt += 1
    x + y
  }

  fn sum(xs : ArrayView[Cell[Int]]) -> Thunk[Int] {
    match xs {
      [] => panic()
      [x, y] => Thunk::new(fn() { add(x.get(), y.get()) })
      _ => {
        let m = xs.length() / 2
        let left = sum(xs[0:m])
        let right = sum(xs[m:]) // eval sum must outside the thunk
        Thunk::new(fn() { add(left.get(), right.get()) })
      }
    }
  }

  fn acc_sum(xs : Array[Cell[Int]]) {
    xs.fold(init=0, fn { acc, x => x.get() + acc })
  }

  let s = sum(xs[:])
  s.get() |> ignore // init dependency graph
  // 
  inspect!(s.get(), content="523776")
  assert_eq!(acc_sum(xs), s.get())
  inspect!(cnt, content="1023")
  // 
  xs[0].modify(fn { x => x + 1 })
  inspect!(s.get(), content="523777")
  assert_eq!(acc_sum(xs), s.get())
  inspect!(cnt, content="1033")
  // 
  xs[0].modify(fn { x => x + 1 })
  inspect!(s.get(), content="523778")
  assert_eq!(acc_sum(xs), s.get())
  inspect!(cnt, content="1043")
}

///|
priv enum Formula {
  Num(Int)
  Plus(Cell[Formula], Cell[Formula])
}

///|
impl Eq for Formula with op_equal(self, other) {
  match (self, other) {
    (Num(x1), Num(x2)) => x1 == x2
    (Plus(x1, y1), Plus(x2, y2)) => x1.get() == x2.get() && x1.get() == x2.get()
    _ => false
  }
}

///|
test "spreadsheet" {
  let n1 = Cell::new(Num(1))
  let n2 = Cell::new(Num(2))
  let n3 = Cell::new(Num(3))
  let p1 = Cell::new(Plus(n1, n2))
  let p2 = Cell::new(Plus(p1, n3))
  let mut cnt = 0
  let eval = memo_rec(fn(eval, c : Cell[Formula]) {
    match c.get() {
      Num(x) => x
      Plus(c1, c2) => {
        cnt += 1
        eval(c1).get() + eval(c2).get()
      }
    }
  })
  let t1 = eval(p1)
  let t2 = eval(p2)
  //
  inspect!(t1.get(), content="3") // demands eval(p1)
  inspect!(cnt, content="1")
  //
  inspect!(t2.get(), content="6") // memo matches eval(p1)
  inspect!(cnt, content="2")
  //
  n1.set(Num(5)) // mutate leaf value
  inspect!(t1.get(), content="7") // does not re-eval p2
  inspect!(cnt, content="3")
  //
  p2.set(Plus(n3, p1)) // swaps operand cells
  inspect!(t2.get(), content="10")
  inspect!(cnt, content="4") // memo matches twice
}
