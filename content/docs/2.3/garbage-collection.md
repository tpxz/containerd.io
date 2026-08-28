# 垃圾回收 {#garbage-collection}

`containerd` 带有一个垃圾回收器，能够移除不再被使用的资源。客户端有责任确保自己创建的
所有资源在任何时刻都处于被使用或被 lease 持有的状态，否则这些资源将被视为可回收。Go
客户端库（`github.com/containerd/containerd/v2/client`）内置了相应行为，保证资源被正确
跟踪和租约化。不过，lease 的生命周期由该库的调用方负责管理。`containerd` daemon 采用
严格的资源管理策略，会回收任何未被使用的资源。

## 什么是 lease？ {#what-is-a-lease}

lease 是 `containerd` 中的一种资源，由客户端创建，用于引用 snapshot、content 等其他资源。
lease 可以配置过期时间，也可以在客户端完成某项操作后由客户端删除。lease 的作用是告知
`containerd` daemon：某个资源在客户端完成操作之后仍可能被使用，即使它当前看起来并未被
占用。

## 如何使用 lease {#how-to-use-leases}

### 使用 Go 客户端 {#using-go-client}

使用 lease 的最佳方式是在 Go context 创建之后立即把 lease 加入其中。通常 lease 的存活期
与 Go context 的生命周期一致。

```.go
	ctx, done, err := client.WithLease(ctx)
	if err != nil {
		return err
	}
	defer done(ctx)
```

这会创建一个 lease，它会通过 defer 自行删除，并具有 24 小时的默认过期时间（以防进程在
defer 执行前崩溃）。对大多数使用场景来说，这就足够了，无需在 lease 上再花心思。

<em>当然，更复杂的使用场景同样是支持的……</em>

如果程序或 lease 需要更长的存活期，可以不使用非常简便的 `client.WithLease`，而是直接使用
lease 管理器。这样还可以在 lease 上设置自定义标签，或者操作其引用的资源。
使用 `client.LeasesService()` 获取 [lease Manager](https://godoc.org/github.com/containerd/containerd/v2/leases#Manager)，
它可以用来创建、列出和删除 lease，也可以管理该 lease 所引用的资源。

```.go
	manager := client.LeasesService()

	// this lease will never expire
	// Use `leases.WithExpiration` to make it expire
	// Use `leases.WithLabels` to apply any labels
	l, err := manager.Create(ctx, leases.WithRandomID())
	if err != nil {
		return err
	}

	// Update current context to add lease
	ctx = leases.WithLease(ctx, l.ID)

	// Do something, lease will be used...

	// Delete lease at any time, or track it to delete later
	if err := ls.Delete(ctx, l); err != nil {
		return err
	}
```


### 使用 gRPC {#using-grpc}

lease 并不是 API 中的显式字段（当然 leases 服务本身除外），而是任何 API 服务都可以使用的
一个可选字段。可以通过 gRPC header 在任意 gRPC 服务端点上设置 lease。把 gRPC header
`containerd-lease` 设为 lease 标识符，API 服务就会在该 lease 的上下文中执行操作。

要管理 lease 的创建和删除，请使用 leases gRPC 服务。

## 垃圾回收标签 {#garbage-collection-labels}

垃圾回收通过两种不同方式定义资源之间的关系：一种是类型特有的资源属性，另一种是资源标签。
类型特有的属性无需用户管理，因为它们本身就是资源结构的自然组成部分（例如容器的 snapshot、
snapshot 的 parent、image 的 target 等）。然而资源之间也可能存在并非由 `containerd` 定义、
而是由客户端定义的关系。例如，一个 OCI image 的 manifest 会引用一个配置文件和若干 layer
tar 包。这些资源在 `containerd` 中都以通用 blob 的形式存储，只有客户端才理解这些 blob 之间
的关系，并通过 content 资源上的标签把它们关联起来。

资源标签还可以用来向垃圾回收器提示其他属性，例如过期时间、某个对象是否在没有任何引用时
也要保留，或者限制其引用范围。

支持的垃圾回收标签如下：

| 标签键 | 标签值 | 支持的资源 | 说明 |
|---|---|---|---|
| `containerd.io/gc.root` | _非空_ | Content、Snapshots | 保留该对象及其引用的一切内容。（客户端可以将其设为 [rfc3339](https://tools.ietf.org/html/rfc3339) 时间戳以标记该值的设置时间，不过垃圾回收器并不解析该值） |
| `containerd.io/gc.ref.snapshot.<snapshotter>` | `<identifier>` | Content、Snapshots | 该资源引用了 snapshotter `<snapshotter>` 下标识为 `<identifier>` 的 snapshot |
| `containerd.io/gc.ref.content` | _digest_ | Content、Snapshots、Images、Containers | 该资源引用了指定的 content blob |
| `containerd.io/gc.ref.content.<user defined>` | _digest_ | Content、Snapshots、Images、Containers | 该资源以 `<user defined>` 标签键引用了指定的 content blob |
| `containerd.io/gc.expire` | 按 [rfc3339](https://tools.ietf.org/html/rfc3339) 格式化的 _时间戳_ | Leases | lease 的过期时间。垃圾回收器会在过期后删除该 lease。 |
| `containerd.io/gc.flat` | _非空_ | Leases | 忽略被租约资源的标签引用。该设置只在引用来自该 lease 时生效；如果被租约资源在其他地方也被引用，那么它们的标签引用仍会被使用。 |
| `containerd.io/gc.bref.container` | `<identifier>` | Content、Snapshots、Images | 该资源被标识为 `<identifier>` 的容器引用 |
| `containerd.io/gc.bref.content` | _digest_ | Content、Snapshots、Images | 该资源被指定的 content blob 引用 |
| `containerd.io/gc.bref.image` | _image 名称_ | Content、Snapshots、Images | 该资源被指定的 image 引用 |
| `containerd.io/gc.bref.snapshot.<snapshotter>` | `<identifier>` | Content、Snapshots、Images | 该资源被 snapshotter `<snapshotter>` 下标识为 `<identifier>` 的 snapshot 引用 |

## 垃圾回收配置 {#garbage-collection-configuration}

垃圾回收器（gc）运行在一个后台 goroutine 上，其调度取决于若干可配置因素。默认情况下，
垃圾回收器会根据以往垃圾回收的加锁时长计算，尽量让数据库在 98% 的时间里处于未加锁状态。
同样在默认配置下，如果没有发生删除操作，或者未达到每 100 次数据库写入的阈值，垃圾回收器
不会调度自身。

垃圾回收调度器把数据库被锁定的时间视为暂停时间。当有资源被移除时，垃圾回收耗时会超过这个
暂停时间，例如清理 snapshot 可能会比较慢。调度器只会在整轮垃圾回收完成之后再进行调度，
但会使用平均暂停时间来决定下一次运行的时机。

垃圾回收可以通过 `containerd` daemon 的配置文件进行配置，该文件通常位于
`/etc/containerd/config.toml`。相关配置位于 `scheduler` plugin 之下。

### 配置参数 {#configuration-parameters}

| 配置项 | 默认值 | 说明 |
|---|---|---|
| `pause_threshold` | 0.02 | 表示基于平均暂停时间，gc 最多可占用的时间比例。为防止过度调度，强制上限为 .5（50%）。 |
| `deletion_threshold` | 0 | 立即触发 gc 的删除次数阈值。0 表示不会因删除次数触发 gc，但发生删除会确保下一次已调度的 gc 得以运行。 |
| `mutation_threshold` | 100 | 在达到指定数量的数据库变更后运行 gc 的阈值。注意任何执行了删除的变更都总是会触发 gc，此项用于处理诸如标签引用移除这类较少见的事件。 |
| `schedule_delay` | "0ms" | 触发事件与实际运行 gc 之间的延迟。当变更可能出现快速突发时，可以设置为非零值。 |
| `startup_delay` | "100ms" | daemon 启动后运行首次垃圾回收之前的延迟。首次回收应当在其他启动流程完成之后再运行，并且在该延迟之前不会调度任何 gc。 |

默认配置表示如下……
```.toml
version = 2
[plugins]
  [plugins."io.containerd.gc.v1.scheduler"]
    pause_threshold = 0.02
    deletion_threshold = 0
    mutation_threshold = 100
    schedule_delay = "0ms"
    startup_delay = "100ms"
```

## 同步垃圾回收 {#synchronous-garbage-collection}

除了通过调度器进行的垃圾回收之外，客户端还可以在移除资源时请求执行一次垃圾回收。这种情况下，
垃圾回收会被立即调度（如果配置了非零的 `schedule_delay`，则在该延迟之后调度）。服务会等到
垃圾回收完成后才返回。目前该能力在移除 image 和 lease 时受支持。对
[`images.Store`](https://godoc.org/github.com/containerd/containerd/v2/images#Store) 的
`Delete` 使用 [`images.SynchronousDelete()`](https://godoc.org/github.com/containerd/containerd/v2/images#SynchronousDelete)，
对 [`leases.Manager`](https://godoc.org/github.com/containerd/containerd/v2/leases#Manager) 的
`Delete` 使用
[`leases.SynchronousDelete`](https://godoc.org/github.com/containerd/containerd/v2/leases#SynchronousDelete)。
