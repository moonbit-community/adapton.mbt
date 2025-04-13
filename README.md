# illusory0x0/adapton

Moonbit classic adapton 的实现

classic adapton 

* lazyiness 
  * `set` 并不会立刻更新，而是会把对应的依赖图的节点标记为`Dirty`
  * `get` 只会把依赖源实际改变的依赖目标更新
* dependency graph
  * 当源实际改变的时候， `dirty` 把需要更新的节点标记为 `Dirty`
  * 当目标被获取的时候， `propagate` 对需要更新的节点调用 `update` 并且标记为 `Clean`
  * `Thunk::get` 第一次调用的时候会自动构建依赖图，其中有一个 `target_stack` 全局变量来帮助构建
* memorization
  * 这里 memo 的部分是 DCG 的节点

大多数情景使用 lazyiness 和 dependency graph 部分就足够了。

spread sheet 的确挺需要 memorization 的，memorization 是为了解决依赖图是动态的，GUI 应用的依赖图一般是静态的，也相对比较小，这个是粒度控制的问题。

adapton 本身也是 pure functional programming， `Thunk[Unit]` 会导致依赖它的计算永远不会更新，
需要写 `Thunk[State]` 一直返回下一个状态，来触发对应的 action.


## Warning

因为 Moonibt 现在没有 `WeakRef`, `WeakMap`, `WeakSet`, `WeakArray`, 导致会存在内存泄漏，在使用 memorization 会更严重。

增量计算本身也是比较吃内存。


## Reference

* [plum-umd/adapton.ocaml](https://github.com/plum-umd/adapton.ocaml)

* [illusory0x0/adapton.ocaml](https://github.com/illusory0x0/adapton.ocaml) 这个仓库，把构建改成用 `dune`, 修复了一些 Ocaml 弃用一些 API 无法编译的 Bug.



* [Adapton/adapton.rust](https://github.com/Adapton/adapton.rust)


* [Adapton: Composable, demand-driven incremental computation, PLDI 2014](http://matthewhammer.org/adapton/)
  adapton.mbt 用的 `dirty` & `propagate` 算法是从这里改编的
