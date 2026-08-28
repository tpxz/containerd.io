
# 特性 {#features}

下面各节介绍 `containerd` 的核心特性。

## 客户端 {#client}

containerd 提供了一个完整的客户端包，帮助你把 containerd 集成到自己的平台中。

```go

import (
  "context"

  containerd "github.com/containerd/containerd/v2/client"
  "github.com/containerd/containerd/v2/pkg/cio"
  "github.com/containerd/containerd/v2/pkg/namespaces"
)


func main() {
	client, err := containerd.New("/run/containerd/containerd.sock")
	defer client.Close()
}

```

## Namespace {#namespaces}

namespace 让多个使用方可以共用同一个 containerd 而互不冲突。它的好处是在共享内容的同时，保持容器和 image 之间的隔离。

为发往 API 的请求设置 namespace：

```go
context = context.Background()
// create a context for docker
docker = namespaces.WithNamespace(context, "docker")

containerd, err := client.NewContainer(docker, "id")
```

为客户端设置默认 namespace：

```go
client, err := containerd.New(address, containerd.WithDefaultNamespace("docker"))
```

## 分发 {#distribution}

```go
// pull an image
image, err := client.Pull(context, "docker.io/library/redis:latest")

// push an image
err := client.Push(context, "docker.io/library/redis:latest", image.Target())
```

## 容器 {#containers}

在 containerd 中，容器是一个元数据对象。OCI 运行时规范、image、根文件系统以及其他元数据等资源都可以关联到一个容器上。

```go
redis, err := client.NewContainer(context, "redis-master")
defer redis.Delete(context)
```

## OCI 运行时规范 {#oci-runtime-specification}

containerd 完整支持用于运行容器的 OCI 运行时规范。containerd 内置了一些函数，帮助你基于 image 以及自定义参数生成运行时规范。

创建容器时可以通过选项来指定如何修改该规范。

```go
redis, err := client.NewContainer(context, "redis-master", containerd.WithNewSpec(oci.WithImageConfig(image)))
```

## 根文件系统 {#root-filesystems}

containerd 允许你为容器使用 overlay 或快照文件系统。它内置支持 overlayfs 和 btrfs。

```go
// pull an image and unpack it into the configured snapshotter
image, err := client.Pull(context, "docker.io/library/redis:latest", containerd.WithPullUnpack)

// allocate a new RW root filesystem for a container based on the image
redis, err := client.NewContainer(context, "redis-master",
	containerd.WithNewSnapshot("redis-rootfs", image),
	containerd.WithNewSpec(oci.WithImageConfig(image)),
)

// use a readonly filesystem with multiple containers
for i := 0; i < 10; i++ {
	id := fmt.Sprintf("id-%s", i)
	container, err := client.NewContainer(ctx, id,
		containerd.WithNewSnapshotView(id, image),
		containerd.WithNewSpec(oci.WithImageConfig(image)),
	)
}
```

## Task {#tasks}

把一个容器对象变成系统上可运行的进程，是通过从该容器创建一个新的 `Task` 来完成的。task 表示 containerd 内部的可运行对象。

```go
// create a new task
task, err := redis.NewTask(context, cio.NewCreator(cio.WithStdio))
defer task.Delete(context)

// the task is now running and has a pid that can be used to setup networking
// or other runtime settings outside of containerd
pid := task.Pid()

// start the redis-server process inside the container
err := task.Start(context)

// wait for the task to exit and get the exit status
status, err := task.Wait(context)
```

## 检查点与恢复 {#checkpoint-and-restore}

如果你的机器上安装了 [criu](https://criu.org/Main_Page)，就可以对容器及其 task 做检查点（checkpoint）和恢复（restore）。这让你可以把容器克隆到其他机器上，或者进行热迁移。

```go
// checkpoint the task then push it to a registry
checkpoint, err := task.Checkpoint(context)

err := client.Push(context, "myregistry/checkpoints/redis:master", checkpoint)

// on a new machine pull the checkpoint and restore the redis container
checkpoint, err := client.Pull(context, "myregistry/checkpoints/redis:master")

redis, err = client.NewContainer(context, "redis-master", containerd.WithNewSnapshot("redis-rootfs", checkpoint))
defer container.Delete(context)

task, err = redis.NewTask(context, cio.NewCreator(cio.WithStdio), containerd.WithTaskCheckpoint(checkpoint))
defer task.Delete(context)

err := task.Start(context)
```

## 快照 plugin {#snapshot-plugins}

除了 containerd 内置的快照 plugin 之外，还可以通过 GRPC 配置额外的外部 plugin。
外部 plugin 会以所配置的名称提供服务，并与内置 plugin 一起出现在 plugin 列表中。

要添加一个外部快照 plugin，需要把该 plugin 加入 containerd 的配置文件
（默认位于 `/etc/containerd/config.toml`）。`proxy_plugin.` 之后的字符串会被用作
snapshotter 的名称，而 address 应当指向一个提供 containerd Snapshot GRPC API 的
GRPC 监听 socket。记得重启 containerd，配置变更才会生效。

```
[proxy_plugins]
  [proxy_plugins.customsnapshot]
    type = "snapshot"
    address =  "/var/run/mysnapshotter.sock"
```

关于如何创建 plugin，参见 [PLUGINS.md](PLUGINS.md)
