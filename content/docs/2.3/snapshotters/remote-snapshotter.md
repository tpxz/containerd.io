# 远程 snapshotter {#remote-snapshotter}

Containerd 允许 snapshotter 复用已经存在于自己所管理的某处的 snapshot。

_远程 snapshotter_ 就是利用这一能力、复用存放在远端共享位置的 snapshot 的 snapshotter。
这些远端共享的 snapshot 被称为 _远程 snapshot_。
远程 snapshotter 让 containerd 无需从 registry 拉取 layer 即可准备好这些远程 snapshot，有望缩短 image 拉取所需的时间。

远程 snapshotter 的实现之一是 [Stargz Snapshotter](https://github.com/containerd/stargz-snapshotter)。
它利用远程 snapshotter 能力和 google/crfs 的 stargz image，使 containerd 能够从符合标准的 registry 中惰性拉取 image。

## containerd 客户端 API {#the-containerd-client-api}

containerd 客户端带 unpacking 模式的 `Pull` API 允许底层 snapshotter 在拉取内容之前先查询远程 snapshot。
远程 snapshotter 需要[以与普通 snapshotter 相同的方式](/docs/PLUGINS.md)接入 containerd。

```go
import (
	containerd "github.com/containerd/containerd/v2/client"
)

image, err := client.Pull(ctx, ref,
	containerd.WithPullUnpack,
	containerd.WithPullSnapshotter("my-remote-snapshotter"),
)
```

## 传递 snapshotter 专有信息 {#passing-snapshotter-specific-information}

有些远程 snapshotter 需要通过 `Pull` API 获得 snapshotter 专有的信息。
这些信息会被用在多种场景中，包括从远端存储中搜索 snapshot 内容。
需要 snapshotter 专有信息的 snapshotter 例子之一是 stargz snapshotter。
它需要 image 引用名和 layer digest 等信息，以便从 registry 中搜索 layer 内容。

snapshotter 通过以 `containerd.io/snapshot/` 为前缀的用户自定义标签接收这些信息。
containerd 客户端支持两种方式把这些标签传给底层 snapshotter。

### 使用 snapshotter 的 `WithLabels` 选项 {#using-snapshotters-withlabels-option}

用户自定义标签可以通过 snapshotter 选项 `WithLabels` 传递给底层 snapshotter。
指定的标签会在 containerd 客户端每次查询远程 snapshot 时传下去。
如果这些标签的取值与具体 snapshot 无关、是静态确定的，这种方式很有用。
这些用户自定义标签必须以 `containerd.io/snapshot/` 为前缀。

```go
import (
	containerd "github.com/containerd/containerd/v2/client"
	"github.com/containerd/containerd/v2/core/snapshots"
)

image, err := client.Pull(ctx, ref,
	containerd.WithPullUnpack,
	containerd.WithPullSnapshotter(
		"my-remote-snapshotter",
		snapshots.WithLabels(map[string]string{
			"containerd.io/snapshot/reference": ref,
		}),
	),
)
```

### 使用 containerd 客户端的 `WithImageHandlerWrapper` 选项 {#using-the-containerd-clients-withimagehandlerwrapper-option}

用户自定义标签也可以通过 image handler wrapper 传递。
当标签随 snapshot 不同而变化时，这种方式很有用。

containerd 客户端每次查询远程 snapshot 时，都会把附加在目标 layer descriptor（即为准备该 snapshot 而将被拉取和解包的那个 layer descriptor）上的 `Annotations` 传给底层 snapshotter。
这些 annotation 会作为用户自定义标签传给 snapshotter。
annotation 的取值可以在 handler wrapper 中动态添加和修改。
注意 annotation 必须以 `containerd.io/snapshot/` 为前缀。
`github.com/containerd/containerd/v2/pkg/snapshotters` 是 CRI 包、nerdctl 和 moby 所使用的一个 handler 实现。

```go
import (
	containerd "github.com/containerd/containerd/v2/client"
	"github.com/containerd/containerd/v2/pkg/snapshotters"
)

if _, err := client.Pull(ctx, ref,
	containerd.WithPullUnpack,
	containerd.WithPullSnapshotter("my-remote-snapshotter"),
	containerd.WithImageHandlerWrapper(snapshotters.AppendInfoHandlerWrapper(ref)),
)
```

## 用于查询远程 snapshot 的 snapshotter API {#snapshotter-apis-for-querying-remote-snapshots}

containerd 客户端通过 snapshotter API 向底层的远程 snapshotter 查询远程 snapshot。
本节概要介绍 snapshotter API 是如何被用于实现远程 snapshot 功能的，并给出一些伪代码来描述 containerd 客户端中实现的简化逻辑。
更多细节见实现该逻辑的 [`unpacker.go`](../core/unpack/unpacker.go)。

在 image 拉取过程中，containerd 客户端会带着标签 `containerd.io/snapshot.ref` 调用 `Prepare` API。
这是一个 containerd 定义的标签，其中包含指向客户端试图准备的那个已提交 snapshot 的 ChainID。
此时，用户自定义标签（以 `containerd.io/snapshot/` 为前缀）也会被合并进 labels 选项中。

```go
// Gets annotations appended to the targeting layer which would contain
// snapshotter-specific information passed by the user.
labels := snapshots.FilterInheritedLabels(desc.Annotations)
if labels == nil {
	labels = make(map[string]string)
}

// Specifies ChainID of the targeting committed snapshot.
labels["containerd.io/snapshot.ref"] = chainID

// Merges snapshotter options specified by the user which would contain
// snapshotter-specific information passed by the user.
opts := append(rCtx.SnapshotterOpts, snapshots.WithLabels(labels))

// Calls `Prepare` API with target identifier and snapshotter-specific
// information.
mounts, err = sn.Prepare(ctx, key, parent.String(), opts...)
```

如果这个 snapshotter 是远程 snapshotter，那么那个已提交的 snapshot 有望存在于某处，例如某个共享的远端存储中。
远程 snapshotter 必须定义并执行关于是否使用已有 snapshot 的策略。
当远程 snapshotter 允许用户使用该 snapshot 时，它必须返回 `ErrAlreadyExists`。

如果 containerd 客户端从 `Prepare` 得到 `ErrAlreadyExists`，它会用 ChainID 调用 `Stat` 来确认该已提交 snapshot 的存在。
如果该 snapshot 可用，containerd 客户端就会跳过原本为准备并提交该 snapshot 所需的 layer 拉取和解包。

```go
mounts, err = sn.Prepare(ctx, key, parent.String(), opts...)
if err != nil {
	if errdefs.IsAlreadyExists(err) {
		// Ensures the layer existence
		if _, err := sn.Stat(ctx, chainID); err != nil {
			// Handling error
		} else {
			// snapshot found with ChainID
			// pulling/unpacking will be skipped
			continue
		}
	} else {
		return err
	}
}
```
