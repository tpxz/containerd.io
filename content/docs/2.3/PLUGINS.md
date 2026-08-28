# containerd Plugin {#containerd-plugins}

containerd 支持通过它定义的大部分接口来扩展自身功能。这包括使用自定义的
runtime、snapshotter、content store，甚至添加 gRPC 接口。

## 智能客户端模型 {#smart-client-model}

containerd 采用智能客户端架构，也就是说凡是 daemon 不需要负责的功能都由客户端完成。
这包括大多数高层交互，例如创建容器的 specification、与 image registry 交互，或者从 tar
加载 image。containerd 的 Go 客户端为用户提供了许多扩展点，从创建容器时自定义选项，
到解析 image registry 名称。

参见 [containerd 的 Go 文档](https://godoc.org/github.com/containerd/containerd/v2/client)

## 外部 Plugin {#external-plugins}

外部 plugin 让你可以在使用官方发布版本的 containerd 时扩展其功能，无需为添加 plugin
而重新编译 daemon。

containerd 支持两种扩展方式：
 - 通过 containerd 的 PATH 中的某个二进制文件
 - 通过配置 containerd 代理到另一个 gRPC 服务

### V2 Runtime {#v2-runtimes}

containerd 支持多种 container runtime。每个容器都可以使用不同的 runtime 来调用。

使用 Container Runtime Interface（CRI）plugin 时，可以在 containerd 配置文件中定义具名
runtime。运行容器时如果没有指定 runtime，就会使用配置的默认 runtime。也可以在通过 CRI gRPC
创建容器时，通过选择要使用的 runtime handler 来显式指定另一个具名 runtime。

当 `ctr` 或 `nerdctl` 之类的客户端创建容器时，可以选择性地指定要使用的 runtime 和选项。
如果没有指定 runtime，containerd 会使用它的默认 runtime。

containerd 以系统上的二进制文件形式调用 v2 runtime，这些二进制文件用于为 containerd
启动 shim 进程。进而，containerd 可以使用该二进制文件返回的 runtime shim api 来启动和管理
这些容器。

关于 runtime 和 shim 的更多细节，包括如何调用和配置它们，
参见 [runtime v2 文档](../core/runtime/v2/README.md)

### Proxy Plugin {#proxy-plugins}

proxy plugin 通过 containerd 的配置文件进行配置，会在 containerd 启动时与内部 plugin
一同加载。这些 plugin 通过一个提供 containerd gRPC API 服务之一的本地 socket 连接到
containerd。每个 plugin 都像内部 plugin 一样配置有类型和名称。

#### 配置 {#configuration}

更新 containerd 配置文件（默认位于 `/etc/containerd/config.toml`）。添加一个
`[proxy_plugins]` 段，以及对应你的 plugin 的段 `[proxy_plugins.myplugin]`。`address` 必须
指向一个 containerd 进程能够访问的本地 socket 文件。目前支持的类型有 `snapshot`、`content`
和 `diff`。

```toml
version = 2

[proxy_plugins]
  [proxy_plugins.customsnapshot]
    type = "snapshot"
    address = "/var/run/mysnapshotter.sock"
```

#### 实现 {#implementation}

实现一个 proxy plugin 就跟实现某个服务的 gRPC API 一样简单。若要用 Go 实现 proxy plugin，
可以参考以下 go doc：
[content store 服务](https://godoc.org/github.com/containerd/containerd/v2/api/services/content/v1#ContentServer)、[snapshotter 服务](https://godoc.org/github.com/containerd/containerd/v2/api/services/snapshots/v1#SnapshotsServer)以及 [diff 服务](https://pkg.go.dev/github.com/containerd/containerd/v2/api/services/diff/v1#DiffServer)。

下面的例子创建了一个 snapshot plugin 二进制文件，它可以配合
[containerd 的 Snapshotter 接口](https://godoc.org/github.com/containerd/containerd/v2/snapshots#Snapshotter)
的任意实现使用
```go
package main

import (
	"fmt"
	"net"
	"os"

	"google.golang.org/grpc"

	snapshotsapi "github.com/containerd/containerd/api/services/snapshots/v1"
	"github.com/containerd/containerd/v2/contrib/snapshotservice"
	"github.com/containerd/containerd/v2/plugins/snapshots/native"
)

func main() {
	// Provide a unix address to listen to, this will be the `address`
	// in the `proxy_plugin` configuration.
	// The root will be used to store the snapshots.
	if len(os.Args) < 3 {
		fmt.Printf("invalid args: usage: %s <unix addr> <root>\n", os.Args[0])
		os.Exit(1)
	}

	// Create a gRPC server
	rpc := grpc.NewServer()

	// Configure your custom snapshotter, this example uses the native
	// snapshotter and a root directory. Your custom snapshotter will be
	// much more useful than using a snapshotter which is already included.
	// https://godoc.org/github.com/containerd/containerd/snapshots#Snapshotter
	sn, err := native.NewSnapshotter(os.Args[2])
	if err != nil {
		fmt.Printf("error: %v\n", err)
		os.Exit(1)
	}

	// Convert the snapshotter to a gRPC service,
	// example in github.com/containerd/containerd/contrib/snapshotservice
	service := snapshotservice.FromSnapshotter(sn)

	// Register the service with the gRPC server
	snapshotsapi.RegisterSnapshotsServer(rpc, service)

	// Listen and serve
	l, err := net.Listen("unix", os.Args[1])
	if err != nil {
		fmt.Printf("error: %v\n", err)
		os.Exit(1)
	}
	if err := rpc.Serve(l); err != nil {
		fmt.Printf("error: %v\n", err)
		os.Exit(1)
	}
}
```

使用前面的配置和示例，你可以这样运行一个 snapshot plugin
```
# Start plugin in one terminal
$ go run ./main.go /var/run/mysnapshotter.sock /tmp/snapshots

# Use ctr in another
$ CONTAINERD_SNAPSHOTTER=customsnapshot ctr images pull docker.io/library/alpine:latest
$ tree -L 3 /tmp/snapshots
/tmp/snapshots
|-- metadata.db
`-- snapshots
    `-- 1
        |-- bin
        |-- dev
        |-- etc
        |-- home
        |-- lib
        |-- media
        |-- mnt
        |-- proc
        |-- root
        |-- run
        |-- sbin
        |-- srv
        |-- sys
        |-- tmp
        |-- usr
        `-- var

18 directories, 1 file
```

## 内置 Plugin {#built-in-plugins}

containerd 在内部也使用 plugin，以确保内部实现是解耦的、稳定的，并且与外部 plugin
受到同等对待。要查看 containerd 拥有的全部 plugin，使用 `ctr plugins ls`

```
$ ctr plugins ls
TYPE                            ID                    PLATFORMS      STATUS
io.containerd.content.v1        content               -              ok
io.containerd.snapshotter.v1    btrfs                 linux/amd64    ok
io.containerd.snapshotter.v1    aufs                  linux/amd64    error
io.containerd.snapshotter.v1    native                linux/amd64    ok
io.containerd.snapshotter.v1    overlayfs             linux/amd64    ok
io.containerd.snapshotter.v1    zfs                   linux/amd64    error
io.containerd.metadata.v1       bolt                  -              ok
io.containerd.differ.v1         walking               linux/amd64    ok
io.containerd.gc.v1             scheduler             -              ok
io.containerd.service.v1        containers-service    -              ok
io.containerd.service.v1        content-service       -              ok
io.containerd.service.v1        diff-service          -              ok
io.containerd.service.v1        images-service        -              ok
io.containerd.service.v1        leases-service        -              ok
io.containerd.service.v1        namespaces-service    -              ok
io.containerd.service.v1        snapshots-service     -              ok
io.containerd.runtime.v1        linux                 linux/amd64    ok
io.containerd.runtime.v2        task                  linux/amd64    ok
io.containerd.monitor.v1        cgroups               linux/amd64    ok
io.containerd.service.v1        tasks-service         -              ok
io.containerd.internal.v1       restart               -              ok
io.containerd.grpc.v1           containers            -              ok
io.containerd.grpc.v1           content               -              ok
io.containerd.grpc.v1           diff                  -              ok
io.containerd.grpc.v1           events                -              ok
io.containerd.grpc.v1           healthcheck           -              ok
io.containerd.grpc.v1           images                -              ok
io.containerd.grpc.v1           leases                -              ok
io.containerd.grpc.v1           namespaces            -              ok
io.containerd.grpc.v1           snapshots             -              ok
io.containerd.grpc.v1           tasks                 -              ok
io.containerd.grpc.v1           version               -              ok
io.containerd.grpc.v1           cri                   linux/amd64    ok
```

从输出中可以看到全部 plugin，也包括那些没有成功加载的 plugin。在这个例子中，`aufs` 和 `zfs`
本来就预期无法加载，因为这台机器不支持它们。日志会说明失败原因，你也可以使用 `-d` 选项
获取更多细节。

```
$ ctr plugins ls -d id==aufs id==zfs
Type:          io.containerd.snapshotter.v1
ID:            aufs
Platforms:     linux/amd64
Exports:
               root      /var/lib/containerd/io.containerd.snapshotter.v1.aufs
Error:
               Code:        Unknown
               Message:     modprobe aufs failed: "modprobe: FATAL: Module aufs not found in directory /lib/modules/4.17.2-1-ARCH\n": exit status 1

Type:          io.containerd.snapshotter.v1
ID:            zfs
Platforms:     linux/amd64
Exports:
               root      /var/lib/containerd/io.containerd.snapshotter.v1.zfs
Error:
               Code:        Unknown
               Message:     path /var/lib/containerd/io.containerd.snapshotter.v1.zfs must be a zfs filesystem to be used with the zfs snapshotter
```

plugin 返回的错误信息解释了它为什么无法加载。

#### 配置 {#configuration-1}

plugin 通过 containerd 配置的 `[plugins]` 段进行配置。
每个 plugin 都可以按 `[plugins."<plugin type>.<plugin id>"]` 的模式拥有自己的段。

配置示例
```toml
version = 2

[plugins]
  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false
```

要查看完整的配置示例，运行 `containerd config default`。
如果你想获得与自己配置合并后的结果，运行 `containerd config dump`。

##### 版本头 {#version-header}

containerd 有多个配置版本：
- 版本 3（推荐用于 containerd 2.x）：在 containerd 2.0 中引入。
  该版本中若干 plugin ID 有所变更。
- 版本 2（推荐用于 containerd 1.x）：在 containerd 1.3 中引入。
  在 containerd v2.x 中仍然支持。
  plugin ID 改为带有 "io.containerd." 之类的前缀。
- 版本 1：在 containerd 1.0 中引入。在 containerd 2.0 中移除。

版本 2 或 3 的配置必须在头部指定版本 `version = 2` 或 `version = 3`，并且 `[plugins]` 段中
必须使用完全限定的 plugin ID：
```toml
version = 3

[plugins]
  [plugins.'io.containerd.monitor.task.v1.cgroups']
    no_prometheus = false
```

```toml
version = 2

[plugins]
  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false
```

版本 1 的配置可以不带 `version` 头，也不需要完全限定的 plugin ID。
```toml
[plugins]
  [plugins.cgroups]
    no_prometheus = false
```
