# illusory0x0/adapton

MoonBit implementation of classic adapton

Classic adapton features:

* Laziness 
  * `set` does not update immediately, but marks the corresponding dependency graph nodes as `Dirty`
  * `get` only updates dependency targets when the dependency source actually changes
* Dependency graph
  * When the source actually changes, `dirty` marks nodes that need updating as `Dirty`
  * When the target is accessed, `propagate` calls `update` on nodes that need updating and marks them as `Clean`
  * `Thunk::get` automatically builds the dependency graph on first call, with a global `target_stack` variable to help with construction
* Memoization
  * The memo part here refers to DCG (Demanded Computation Graph) nodes

For most scenarios, using the laziness and dependency graph parts is sufficient.

Spreadsheets do need memoization quite a bit. Memoization is designed to solve the problem of dynamic dependency graphs. GUI application dependency graphs are generally static and relatively small - this is a matter of granularity control.

Adapton itself is also pure functional programming. `Thunk[Unit]` will cause computations that depend on it to never update, so you need to write `Thunk[State]` that always returns the next state to trigger corresponding actions.

## Warning

Because MoonBit currently lacks `WeakRef`, `WeakMap`, `WeakSet`, `WeakArray`, memory leaks will occur, and this becomes more severe when using memoization.

Incremental computation itself is also quite memory-intensive.

## Reference

* [plum-umd/adapton.ocaml](https://github.com/plum-umd/adapton.ocaml)

* [illusory0x0/adapton.ocaml](https://github.com/illusory0x0/adapton.ocaml) This repository changes the build system to use `dune` and fixes some bugs where deprecated OCaml APIs prevented compilation.

* [Adapton/adapton.rust](https://github.com/Adapton/adapton.rust)

* [Adapton: Composable, demand-driven incremental computation, PLDI 2014](http://matthewhammer.org/adapton/)
  The `dirty` & `propagate` algorithm used in adapton.mbt is adapted from here