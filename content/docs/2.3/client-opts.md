# 客户端选项 {#client-options}

containerd 客户端在设计上便于使用方进行扩展。
目标是让各种实现的调用执行流程保持一致，同时通过编写 `Opts` 来扩展功能。
为此我们依赖 Go 中的 `Opts` 模式。

## 方法调用 {#method-calls}

在客户端包中的许多函数和方法上，你通常会看到最后一个参数是可变参数。

以客户端上的 `NewContainer` 方法为例，可以看到它有一个必填参数 `id`，其后是额外的
`NewContainerOpts`。

内置的选项中有几个允许使用已有的 spec 创建容器，例如 `WithSpec`，以及用于创建或使用已有
snapshot 的 snapshot opts。

```go
func (c *Client) NewContainer(ctx context.Context, id string, opts ...NewContainerOpts) (Container, error) {
}
```

## 扩展客户端 {#extending-the-client}

作为 containerd 客户端的使用方，你需要能够添加自己领域相关的功能。
实现方式有几种：修改客户端代码、向 containerd 客户端提交 PR，或者 fork 客户端。
只有在尝试过其他所有办法之后，才应考虑这些扩展方式。

正确且受支持的客户端扩展方式，是构建一个包含 `Opts` 的包，在其中定义你的应用专属逻辑。

举例来说，如果 Docker 要集成 containerd 支持，并且需要引入 Volume 之类的概念，就应该创建一个
带有选项的 `docker` 包。

#### 不好的扩展示例 {#bad-extension-example}

```go
// example code
container, err := client.NewContainer(ctx, id)

// add volumes with their config and bind mounts
container.Labels["volumes"] = VolumeConfig{}
container.Spec.Binds  = append({"/var/lib/docker/volumes..."})
```

#### 好的扩展示例 {#good-extension-example}

```go
// example code
import "github.com/docker/docker"
import "github.com/docker/libnetwork"

container, err := client.NewContainer(ctx, id,
	docker.WithVolume("volume-name"),
	libnetwork.WithOverlayNetwork("cluster-network"),
)
```

使用这种模式有几个优点。

1. 你的应用代码不会散落在 containerd 客户端的执行流程中。
2. 你的代码无需 mock containerd 客户端即可进行单元测试。
3. 贡献者可以更好地理解你的 containerd 实现，明白你的应用逻辑在何时、何处被加入到标准的 containerd 客户端调用中。

## SpecOpt 示例 {#example-specopt}

如果我们想编写一个 `SpecOpt`，让容器通过 `htop` 监控宿主机系统，完全不用改动 containerd
仓库中的任何一行代码就能轻松做到。

```go
package monitor

import (
	"github.com/containerd/containerd/v2/pkg/oci"
	specs "github.com/opencontainers/runtime-spec/specs-go"
)

// WithHtop configures a container to monitor the host system via `htop`
func WithHtop(s *specs.Spec) error {
	// make sure we are in the host pid namespace
	if err := oci.WithHostNamespace(specs.PIDNamespace)(s); err != nil {
		return err
	}
	// make sure we set htop as our arg
	s.Process.Args = []string{"htop"}
	// make sure we have a tty set for htop
	if err := oci.WithTTY(s); err != nil {
		return err
	}
	return nil
}
```

把新选项加入 spec 生成过程非常简单，只需导入你的新包，并在创建 spec 时加上该选项。

```go
import "github.com/crosbymichael/monitor"

container, err := client.NewContainer(ctx, id,
	containerd.WithNewSpec(oci.WithImageConfig(image), monitor.WithHtop),
)
```

你可以在[这里](https://github.com/crosbymichael/monitor)查看完整代码并运行这个 monitor 容器。
