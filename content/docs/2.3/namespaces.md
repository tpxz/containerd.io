# containerd namespace 与多租户 {#containerd-namespaces-and-multi-tenancy}

containerd 提供了完全 namespace 化的 API，因此多个使用方可以共用同一个 containerd 实例而互不冲突。
namespace 让单个 daemon 内部得以实现多租户，从而无需再采用嵌套容器这种常见模式来达成隔离。
使用方可以创建同名的容器，但各自的设置和/或配置可以截然不同。
例如，系统级或基础设施级的容器可以隐藏在一个 namespace 中，而用户级容器放在另一个 namespace 中。
底层的 image 内容仍然通过内容寻址共享，但 image 名称和元数据在各个 namespace 之间是相互独立的。

需要特别注意的是，当前实现的 namespace 是一种管理层面的构造，并不打算作为安全特性使用。
客户端切换 namespace 是非常容易的。

## 由谁指定 namespace？ {#who-specifies-the-namespace}

由客户端通过 `context` 指定 namespace。
`github.com/containerd/containerd/v2/namespaces` 包允许用户在 context 上读取和设置 namespace。

```go
// set a namespace
ctx := namespaces.WithNamespace(context.Background(), "my-namespace")

// get the namespace
ns, ok := namespaces.Namespace(ctx)
```

由于客户端是通过调用 containerd 的 gRPC API 与 daemon 交互的，所有 API 调用都要求 context 中已设置 namespace。

> 注意 namespace 不能命名为 `"version"`（[#6944](https://github.com/containerd/containerd/issues/6944)）。

## 这个实现处于多低的层次？ {#how-low-level-is-the-implementation}

namespace 会通过 containerd API 传递给提供实际功能的底层 plugin。
plugin 在编写时必须考虑 namespace。
文件系统路径、ID 以及其他系统级资源都必须做 namespace 区分，plugin 才能正常工作。

## 多租户是怎么工作的？ {#how-does-multi-tenancy-work}

只需创建一个新的 `context`，并在该 `context` 上设置你的应用所用的 namespace。
请确保为应用使用一个不与现有 namespace 冲突的唯一 namespace。可以使用 namespace API，
或者 `ctr namespaces` 客户端命令，来查询/列出以及创建新的 namespace。

```go
ctx := context.Background()

var (
	docker = namespaces.WithNamespace(ctx, "docker")
	vmware = namespaces.WithNamespace(ctx, "vmware")
	ecs = namespaces.WithNamespace(ctx, "aws-ecs")
	cri = namespaces.WithNamespace(ctx, "cri")
)
```

## namespace 标签 {#namespace-labels}

namespace 可以关联一组标签。这在为特定 namespace 附加元数据时很有用。
标签还可以用来配置 containerd 的默认值，例如：

```bash
> sudo ctr namespaces label k8s.io containerd.io/defaults/snapshotter=btrfs
> sudo ctr namespaces label k8s.io containerd.io/defaults/runtime=testRuntime
```

这会把默认的 snapshotter 设为 `btrfs`，默认的 runtime 设为 `testRuntime`。
注意目前只有这两个标签会用于配置默认值，并且 `default` namespace 的标签不会用于此目的。

## 查看 namespace {#inspecting-namespaces}

如果需要查看不同 namespace 中的容器、image 或其他资源，`ctr` 工具可以做到这一点。
只需在 `ctr` 上设置 `--namespace,-n` 标志即可切换 namespace。如果不提供 namespace，`ctr` 客户端命令
都会使用默认 namespace，其名称就是「`default`」。

```bash
> sudo ctr -n docker tasks
> sudo ctr -n cri tasks
```

你也可以使用 `CONTAINERD_NAMESPACE` 环境变量，为任意 `ctr` 客户端命令指定要使用的默认
namespace。
