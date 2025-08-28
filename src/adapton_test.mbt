///|
test "in degree > 1" {
  let mut cnt = 0
  let a = @adapton.Cell::new(1)
  let b0 = @adapton.Thunk::new(fn() {
    cnt += 1
    a.get() * 2
  })
  let b1 = @adapton.Thunk::new(fn() {
    cnt += 1
    a.get() * 3
  })
  let c = @adapton.Thunk::new(fn() {
    cnt += 1
    b0.get() + b1.get()
  })
  inspect(b1.get(), content="3")
  inspect(c.get(), content="5")
  inspect(cnt, content="3")
  a.set(20)
  inspect(cnt, content="3")
  inspect(c.get(), content="100")
  inspect(cnt, content="6")
}

///|
test "propagate" {
  let mut cnt = 0
  let x = @adapton.Cell::new(2)
  let y = @adapton.Cell::new(3)
  let z = @adapton.Thunk::new(fn() {
    cnt += 1
    x.get() * y.get()
  })
  let w = @adapton.Thunk::new(fn() {
    cnt += 1
    z.get() + 1
  })
  inspect(w.get(), content="7")
  inspect(cnt, content="2")
  // swap x and y
  x.set(3)
  y.set(2)
  inspect(w.get(), content="7")
  inspect(cnt, content="3") // cnt: +1
  // incr x and incr y
  x.modify(x => x + 1)
  y.modify(y => y + 1)
  inspect(w.get(), content="13")
  inspect(cnt, content="5") // cnt: +2
}

///|
test "sum" {
  let xs = Array::makei(1024, @adapton.Cell::new)
  let mut cnt = 0
  fn add(x, y) {
    cnt += 1
    x + y
  }

  fn sum(xs : ArrayView[@adapton.Cell[Int]]) -> @adapton.Thunk[Int] {
    match xs {
      [] => panic()
      [x, y] => @adapton.Thunk::new(fn() { add(x.get(), y.get()) })
      _ => {
        let m = xs.length() / 2
        let left = sum(xs[0:m])
        let right = sum(xs[m:]) // eval sum must outside the thunk
        @adapton.Thunk::new(fn() { add(left.get(), right.get()) })
      }
    }
  }

  fn acc_sum(xs : Array[@adapton.Cell[Int]]) {
    xs.fold(init=0, (acc, x) => x.get() + acc)
  }

  let s = sum(xs[:])
  s.get() |> ignore // init dependency graph
  //
  inspect(s.get(), content="523776")
  assert_eq(acc_sum(xs), s.get())
  inspect(cnt, content="1023")
  //
  xs[0].modify(x => x + 1)
  inspect(s.get(), content="523777")
  assert_eq(acc_sum(xs), s.get())
  inspect(cnt, content="1033")
  //
  xs[0].modify(x => x + 1)
  inspect(s.get(), content="523778")
  assert_eq(acc_sum(xs), s.get())
  inspect(cnt, content="1043")
}

///|
priv enum Formula {
  Num(Int)
  Plus(@adapton.Cell[Formula], @adapton.Cell[Formula])
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
  let n1 = @adapton.Cell::new(Num(1))
  let n2 = @adapton.Cell::new(Num(2))
  let n3 = @adapton.Cell::new(Num(3))
  let p1 = @adapton.Cell::new(Plus(n1, n2))
  let p2 = @adapton.Cell::new(Plus(p1, n3))
  let mut cnt = 0
  let eval = @adapton.memo_rec(fn(eval, c : @adapton.Cell[Formula]) {
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
  inspect(t1.get(), content="3") // demands eval(p1)
  inspect(cnt, content="1")
  //
  inspect(t2.get(), content="6") // memo matches eval(p1)
  inspect(cnt, content="2")
  //
  n1.set(Num(5)) // mutate leaf value
  inspect(t1.get(), content="7") // does not re-eval p2
  inspect(cnt, content="3")
  //
  p2.set(Plus(n3, p1)) // swaps operand cells
  inspect(t2.get(), content="10")
  inspect(cnt, content="4") // memo matches twice
}
