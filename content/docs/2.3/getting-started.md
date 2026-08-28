# containerd 快速上手 {#getting-started-with-containerd}

## 安装 containerd {#installing-containerd}

### 方式一：使用官方二进制包 {#option-1-from-the-official-binaries}

containerd 的官方二进制发布版本提供 `amd64`（也称 `x86_64`）和 `arm64`（也称 `aarch64`）两种架构。

通常还需要从各自的官方站点安装 [runc](https://github.com/opencontainers/runc/releases) 和 [CNI plugins](https://github.com/containernetworking/plugins/releases)。

#### 步骤 1：安装 containerd {#step-1-installing-containerd}

从 https://github.com/containerd/containerd/releases 下载 `containerd-<VERSION>-<OS>-<ARCH>.tar.gz` 压缩包，
校验其 sha256sum，然后解压到 `/usr/local` 下：

```console
$ tar Cxzvf /usr/local containerd-1.6.2-linux-amd64.tar.gz
bin/
bin/containerd-shim-runc-v2
bin/containerd-shim
bin/ctr
bin/containerd-shim-runc-v1
bin/containerd
bin/containerd-stress
```

`containerd` 二进制是针对 Ubuntu、Rocky Linux 等基于 glibc 的 Linux 发行版动态构建的。
该二进制可能无法在 Alpine Linux 这类基于 musl 的发行版上运行。
这类发行版的用户可能需要从源码安装 containerd，或使用第三方包。

> **FAQ**：使用 Kubernetes 时，我还需要下载 `cri-containerd-(cni-)<VERSION>-<OS-<ARCH>.tar.gz` 吗？
>
> **回答**：不需要。
>
> Kubernetes CRI 特性已经包含在 `containerd-<VERSION>-<OS>-<ARCH>.tar.gz` 中，
> 使用 CRI 无需下载 `cri-containerd-....` 压缩包。
>
> `cri-containerd-...` 压缩包已[弃用](https://github.com/containerd/containerd/blob/main/RELEASES.md#deprecated-features)，
> 在旧版 Linux 发行版上无法工作，并将在 containerd 2.0 中移除。


##### systemd {#systemd}
如果打算通过 systemd 启动 containerd，还需要从
https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 下载 `containerd.service` unit 文件到 `/usr/local/lib/systemd/system/containerd.service`，
并执行以下命令：

```bash
systemctl daemon-reload
systemctl enable --now containerd
```

#### 步骤 2：安装 runc {#step-2-installing-runc}

从 https://github.com/opencontainers/runc/releases 下载 `runc.<ARCH>` 二进制，
校验其 sha256sum，并安装为 `/usr/local/sbin/runc`。

```console
$ install -m 755 runc.amd64 /usr/local/sbin/runc
```

该二进制为静态构建，可在任意 Linux 发行版上运行。

#### 步骤 3：安装 CNI plugins {#step-3-installing-cni-plugins}

从 https://github.com/containernetworking/plugins/releases 下载 `cni-plugins-<OS>-<ARCH>-<VERSION>.tgz` 压缩包，
校验其 sha256sum，然后解压到 `/opt/cni/bin` 下：

```console
$ mkdir -p /opt/cni/bin
$ tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz
./
./macvlan
./static
./vlan
./portmap
./host-local
./vrf
./bridge
./tuning
./firewall
./host-device
./sbr
./loopback
./dhcp
./ptp
./ipvlan
./bandwidth
```

这些二进制为静态构建，可在任意 Linux 发行版上运行。

### 方式二：使用 `apt-get` 或 `dnf` {#option-2-from-apt-get-or-dnf}

DEB 和 RPM 格式的 `containerd.io` 包由 Docker 分发（而非 containerd 项目）。
参见 Docker 文档了解如何配置 `apt-get` 或 `dnf` 来安装 `containerd.io` 包：
- [CentOS](https://docs.docker.com/engine/install/centos/)
- [Debian](https://docs.docker.com/engine/install/debian/)
- [Fedora](https://docs.docker.com/engine/install/fedora/)
- [Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

`containerd.io` 包中也包含 runc，但不包含 CNI plugins。

### 方式三：从源码安装 {#option-3-from-source}

要从源码安装 containerd 及其依赖，参见 [`BUILDING.md`](/BUILDING.md)。

## 在 Windows 上安装 containerd {#installing-containerd-on-windows}

在提升权限的 PowerShell 会话中（_以管理员身份运行_）执行以下命令：

```PowerShell
# If containerd previously installed run:
Stop-Service containerd

# Download and extract desired containerd Windows binaries
$Version="1.7.13"	# update to your preferred version
$Arch = "amd64"	# arm64 also available
curl.exe -LO https://github.com/containerd/containerd/releases/download/v$Version/containerd-$Version-windows-$Arch.tar.gz
tar.exe xvf .\containerd-$Version-windows-$Arch.tar.gz

# Copy
Copy-Item -Path .\bin -Destination $Env:ProgramFiles\containerd -Recurse -Force

# add the binaries (containerd.exe, ctr.exe) in $env:Path
$Path = [Environment]::GetEnvironmentVariable("PATH", "Machine") + [IO.Path]::PathSeparator + "$Env:ProgramFiles\containerd"
[Environment]::SetEnvironmentVariable( "Path", $Path, "Machine")
# reload path, so you don't have to open a new PS terminal later if needed
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# configure
containerd.exe config default | Out-File $Env:ProgramFiles\containerd\config.toml -Encoding ascii
# Review the configuration. Depending on setup you may want to adjust:
# - the sandbox_image (Kubernetes pause image)
# - cni bin_dir and conf_dir locations
Get-Content $Env:ProgramFiles\containerd\config.toml

# Register and start service
containerd.exe --register-service
Start-Service containerd
```

> **在 Windows 上运行 `containerd` 服务的提示：**
>
> 通过 Windows 服务管理器以服务方式启动 `containerd` 时，日志不会被持久化。
可以用 [`nssm`](https://nssm.cc) 把日志配置写入一个循环缓冲区：
> ```powershell
> nssm.exe install containerd
> nssm.exe set containerd AppStdout "\containerd.log"
> nssm.exe set containerd AppStderr "\containerd.err.log"
> nssm.exe start containerd
> # to stop:
> nssm.exe stop containerd
> ```

## 通过 CLI 与 containerd 交互 {#interacting-with-containerd-via-cli}

有多个命令行界面（CLI）项目可用于与 containerd 交互：

名称      | 社区                  | API    | 用途               | 网站                                        |
----------|-----------------------|------- | -------------------|---------------------------------------------|
`ctr`     | containerd            | Native | 仅用于调试         | （无，运行 `ctr --help` 了解用法）          |
`nerdctl` | containerd（非核心）  | Native | 通用               | https://github.com/containerd/nerdctl       |
`crictl`  | Kubernetes SIG-node   | CRI    | 仅用于调试         | https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md |

`ctr` 工具虽然随 containerd 一起分发，但需要注意 `ctr` 仅用于调试 containerd。
[`nerdctl`](https://github.com/containerd/nerdctl) 工具提供稳定且对人友好的使用体验。

示例（`ctr`）：
```bash
ctr images pull docker.io/library/redis:alpine
ctr run docker.io/library/redis:alpine redis
```

示例（`nerdctl`）：
```bash
nerdctl run --name redis redis:alpine
```

## 为 Kubernetes 配置 containerd {#setting-up-containerd-for-kubernetes}

containerd 内置支持 Kubernetes 容器运行时接口（CRI）。

要为托管 Kubernetes 服务配置 containerd 节点，参见各服务提供商的文档：
- [Amazon Elastic Kubernetes Service](https://docs.aws.amazon.com/eks/latest/userguide/dockershim-deprecation.html)
- [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/cluster-configuration)
- [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/docs/concepts/using-containerd)

对于非托管环境，参见以下 Kubernetes 文档：
- [Getting started / Production environment / Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Getting started / Production environment / Installing Kubernetes with deployment tools](https://kubernetes.io/docs/setup/production-environment/tools/)

- - -

# 进阶主题 {#advanced-topics}

## 定制 containerd {#customizing-containerd}

containerd 使用位于 `/etc/containerd/config.toml` 的配置文件来指定 daemon 级别的选项。
示例配置文件见[这里](/docs/man/containerd-config.toml.5.md)。

默认配置可通过 `containerd config default > /etc/containerd/config.toml` 生成。

## 实现你自己的 containerd 客户端 {#implementing-your-own-containerd-client}
使用 containerd 的方式有很多种。
如果你是 containerd 的开发者，可以用 `ctr` 或 `nerdctl` 工具快速测试特性和功能，无需额外写代码。
但如果想把 containerd 集成进自己的项目，我们提供了易用的 client 包，可用于与 containerd 交互。

本指南将使用 client 包，通过 containerd 拉取并运行一个 redis server。
本项目需要较新版本的 Go。
推荐的 Go 版本参见 [`go.mod`](https://github.com/containerd/containerd/blob/main/go.mod) 文件头部。

### 连接到 containerd {#connecting-to-containerd}

先新建一个 `main.go` 文件，并导入 containerd client 包。


```go
package main

import (
	"log"

	containerd "github.com/containerd/containerd/v2/client"
)

func main() {
	if err := redisExample(); err != nil {
		log.Fatal(err)
	}
}

func redisExample() error {
	client, err := containerd.New("/run/containerd/containerd.sock")
	if err != nil {
		return err
	}
	defer client.Close()
	return nil
}
```

这会用默认的 containerd socket 路径创建一个新的 client。
由于是通过 GRPC 与 daemon 交互，我们需要创建一个 `context` 用于调用 client 的方法。
containerd 对 API 调用方也做了 namespace 隔离。
创建 context 之后，还应为本指南设置一个 namespace。

```go
	ctx := namespaces.WithNamespace(context.Background(), "example")
```

为使用场景设置 namespace，可以确保容器、image 及其他资源不会与同一个 daemon 上的其他用户产生冲突。

### 拉取 redis image {#pulling-the-redis-image}

有了 client 之后，接下来需要拉取一个 image。
可以使用 DockerHub 上基于 Alpine Linux 的 redis image。

```go
	image, err := client.Pull(ctx, "docker.io/library/redis:alpine", containerd.WithPullUnpack)
	if err != nil {
		return err
	}
```

containerd client 的许多方法调用都采用 `Opts` 模式。
这里使用 `containerd.WithPullUnpack`，这样不仅会把内容抓取并下载到 containerd 的 content store，还会将其解包到 snapshotter 中，作为根文件系统使用。

下面把代码拼到一起：从 Dockerhub 拉取基于 alpine linux 的 redis image，然后在控制台输出该 image 的名称。

```go
package main

import (
        "context"
        "log"

        containerd "github.com/containerd/containerd/v2/client"
        "github.com/containerd/containerd/v2/pkg/namespaces"
)

func main() {
        if err := redisExample(); err != nil {
                log.Fatal(err)
        }
}

func redisExample() error {
        client, err := containerd.New("/run/containerd/containerd.sock")
        if err != nil {
                return err
        }
        defer client.Close()

        ctx := namespaces.WithNamespace(context.Background(), "example")
        image, err := client.Pull(ctx, "docker.io/library/redis:alpine", containerd.WithPullUnpack)
        if err != nil {
                return err
        }
        log.Printf("Successfully pulled %s image\n", image.Name())

        return nil
}
```

```bash
> go build main.go
> sudo ./main

2017/08/13 17:43:21 Successfully pulled docker.io/library/redis:alpine image
```

### 创建 OCI Spec 和容器 {#creating-an-oci-spec-and-container}

有了作为容器基础的 image 之后，需要生成一份容器所依据的 OCI 运行时规范，并创建新容器。

containerd 为生成 OCI 运行时规范提供了合理的默认值。
还提供了一个 `Opt`，可以基于拉取到的 image 修改默认配置。

容器将基于该 image 创建，过程中我们会：
1. 分配一个新的可读写 snapshot，以便容器保存持久化信息；
2. 为容器创建一份新的 spec。


```go
	container, err := client.NewContainer(
		ctx,
		"redis-server",
		containerd.WithNewSnapshot("redis-server-snapshot", image),
		containerd.WithNewSpec(oci.WithImageConfig(image)),
	)
	if err != nil {
		return err
	}
	defer container.Delete(ctx, containerd.WithSnapshotCleanup)
```

如果已经有现成的 OCI 规范，可以用 `containerd.WithSpec(spec)` 把它设置到容器上。

为容器创建新 snapshot 时，需要提供一个 snapshot ID 以及容器所基于的 Image。
使用与容器 ID 不同的独立 snapshot ID，可以方便地在不同容器之间复用已有的 snapshot。

我们还加了一行代码，在示例结束后连同 snapshot 一起删除容器。

下面的示例代码从 Dockerhub 拉取基于 alpine linux 的 redis image，创建 OCI spec，基于该 spec 创建容器，最后删除容器。
```go
package main

import (
        "context"
        "log"

        containerd "github.com/containerd/containerd/v2/client"
        "github.com/containerd/containerd/v2/pkg/namespaces"
        "github.com/containerd/containerd/v2/pkg/oci"
)

func main() {
        if err := redisExample(); err != nil {
                log.Fatal(err)
        }
}

func redisExample() error {
        client, err := containerd.New("/run/containerd/containerd.sock")
        if err != nil {
                return err
        }
        defer client.Close()

        ctx := namespaces.WithNamespace(context.Background(), "example")
        image, err := client.Pull(ctx, "docker.io/library/redis:alpine", containerd.WithPullUnpack)
        if err != nil {
                return err
        }
        log.Printf("Successfully pulled %s image\n", image.Name())

        container, err := client.NewContainer(
                ctx,
                "redis-server",
                containerd.WithNewSnapshot("redis-server-snapshot", image),
                containerd.WithNewSpec(oci.WithImageConfig(image)),
        )
        if err != nil {
                return err
        }
        defer container.Delete(ctx, containerd.WithSnapshotCleanup)
        log.Printf("Successfully created container with ID %s and snapshot with ID redis-server-snapshot", container.ID())

        return nil
}
```

来看看实际效果。

```bash
> go build main.go
> sudo ./main

2017/08/13 18:01:35 Successfully pulled docker.io/library/redis:alpine image
2017/08/13 18:01:35 Successfully created container with ID redis-server and snapshot with ID redis-server-snapshot
```

### 创建运行中的 Task {#creating-a-running-task}

对 containerd 新用户来说，一开始可能会困惑的一点是 `Container` 与 `Task` 的区别。
容器是一个元数据对象，资源被分配并附加到它上面。
task 则是系统上一个活跃的、正在运行的进程。
每次运行结束后都应删除 task，而容器可以被多次使用、更新和查询。

```go
	task, err := container.NewTask(ctx, cio.NewCreator(cio.WithStdio))
	if err != nil {
		return err
	}
	defer task.Delete(ctx)
```

刚刚创建的这个 task 实际上就是系统上一个正在运行的进程。
这里使用 `cio.WithStdio`，把容器的所有 IO 都发送到我们的 `main.go` 进程。
它是一个 `cio.Opt`，用于配置 `NewCreator` 所使用的 `Streams`，从而为新 task 返回一个 `cio.IO`。

如果你熟悉 OCI 运行时的各类操作，此时 task 处于 "created" 状态。
这意味着 namespace、根文件系统以及各种容器级设置都已初始化，但用户定义的进程（本例中是 "redis-server"）尚未启动。
这给了用户机会去配置网络接口，或挂接不同的工具来监控容器。
containerd 也会借此机会开始监控你的容器。
对容器退出状态、cgroup 指标等的等待与采集就是在这一阶段建立的。

如果你熟悉 prometheus，可以 curl containerd 的 metrics 端点（在我们创建的 `config.toml` 中配置）来查看容器的指标：

```bash
> curl 127.0.0.1:1338/v1/metrics
```

很酷吧？

### Task 的 Wait 与 Start {#task-wait-and-start}

现在 task 处于 created 状态，我们需要确保等待 task 退出。
等待 task 结束是必要的，这样才能结束示例并清理创建的资源。
务必在对 task 调用 `Start` 之前先调用 `Wait`。
这样可以确保在 task 运行的是像 `/bin/true` 这种启动后立即退出的简单程序时，不会出现竞态。

```go
	exitStatusC, err := task.Wait(ctx)
	if err != nil {
		return err
	}

	if err := task.Start(ctx); err != nil {
		return err
	}
```

现在运行 `main.go` 文件时，终端里应该能看到 `redis-server` 的日志。

### 杀掉 task {#killing-the-task}

由于运行的是一个长期运行的 server，需要杀掉 task 才能退出示例。
为此，只需在等待几秒（以便看到 redis-server 日志）之后对 task 调用 `Kill`。

```go
	time.Sleep(3 * time.Second)

	if err := task.Kill(ctx, syscall.SIGTERM); err != nil {
		return err
	}

	status := <-exitStatusC
	code, exitedAt, err := status.Result()
	if err != nil {
		return err
	}
	fmt.Printf("redis-server exited with status: %d\n", code)
```

我们在此前设置的退出状态 channel 上等待，以确保 task 已完全退出并拿到退出状态。
如果需要重新加载容器，或者错过了对 task 的等待，最终删除 task 时 `Delete` 同样会返回退出状态。
这一点已经为你考虑到了。

```go
status, err := task.Delete(ctx)
```

### 完整示例 {#full-example}

下面是我们刚刚拼装出的完整示例。

```go
package main

import (
	"context"
	"fmt"
	"log"
	"syscall"
	"time"

	"github.com/containerd/containerd/v2/pkg/cio"
	containerd "github.com/containerd/containerd/v2/client"
	"github.com/containerd/containerd/v2/pkg/oci"
	"github.com/containerd/containerd/v2/pkg/namespaces"
)

func main() {
	if err := redisExample(); err != nil {
		log.Fatal(err)
	}
}

func redisExample() error {
	// create a new client connected to the default socket path for containerd
	client, err := containerd.New("/run/containerd/containerd.sock")
	if err != nil {
		return err
	}
	defer client.Close()

	// create a new context with an "example" namespace
	ctx := namespaces.WithNamespace(context.Background(), "example")

	// pull the redis image from DockerHub
	image, err := client.Pull(ctx, "docker.io/library/redis:alpine", containerd.WithPullUnpack)
	if err != nil {
		return err
	}

	// create a container
	container, err := client.NewContainer(
		ctx,
		"redis-server",
		containerd.WithImage(image),
		containerd.WithNewSnapshot("redis-server-snapshot", image),
		containerd.WithNewSpec(oci.WithImageConfig(image)),
	)
	if err != nil {
		return err
	}
	defer container.Delete(ctx, containerd.WithSnapshotCleanup)

	// create a task from the container
	task, err := container.NewTask(ctx, cio.NewCreator(cio.WithStdio))
	if err != nil {
		return err
	}
	defer task.Delete(ctx)

	// make sure we wait before calling start
	exitStatusC, err := task.Wait(ctx)
	if err != nil {
		return err
	}

	// call start on the task to execute the redis server
	if err := task.Start(ctx); err != nil {
		return err
	}

	// sleep for a lil bit to see the logs
	time.Sleep(3 * time.Second)

	// kill the process and get the exit status
	if err := task.Kill(ctx, syscall.SIGTERM); err != nil {
		return err
	}

	// wait for the process to fully exit and print out the exit status

	status := <-exitStatusC
	code, _, err := status.Result()
	if err != nil {
		return err
	}
	fmt.Printf("redis-server exited with status: %d\n", code)

	return nil
}
```

可以按如下方式构建并运行这个示例，看看前面所有工作的成果。

```bash
> go build main.go
> sudo ./main

1:C 04 Aug 20:41:37.682 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
1:C 04 Aug 20:41:37.682 # Redis version=4.0.1, bits=64, commit=00000000, modified=0, pid=1, just started
1:C 04 Aug 20:41:37.682 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
1:M 04 Aug 20:41:37.682 # You requested maxclients of 10000 requiring at least 10032 max file descriptors.
1:M 04 Aug 20:41:37.682 # Server can't set maximum open files to 10032 because of OS error: Operation not permitted.
1:M 04 Aug 20:41:37.682 # Current maximum open files is 1024. maxclients has been reduced to 992 to compensate for low ulimit. If you need higher maxclients increase 'ulimit -n'.
1:M 04 Aug 20:41:37.683 * Running mode=standalone, port=6379.
1:M 04 Aug 20:41:37.683 # WARNING: The TCP backlog setting of 511 cannot be enforced because /proc/sys/net/core/somaxconn is set to the lower value of 128.
1:M 04 Aug 20:41:37.684 # Server initialized
1:M 04 Aug 20:41:37.684 # WARNING overcommit_memory is set to 0! Background save may fail under low memory condition. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.
1:M 04 Aug 20:41:37.684 # WARNING you have Transparent Huge Pages (THP) support enabled in your kernel. This will create latency and memory usage issues with Redis. To fix this issue run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as root, and add it to your /etc/rc.local in order to retain the setting after a reboot. Redis must be restarted after THP is disabled.
1:M 04 Aug 20:41:37.684 * Ready to accept connections
1:signal-handler (1501879300) Received SIGTERM scheduling shutdown...
1:M 04 Aug 20:41:40.791 # User requested shutdown...
1:M 04 Aug 20:41:40.791 * Saving the final RDB snapshot before exiting.
1:M 04 Aug 20:41:40.794 * DB saved on disk
1:M 04 Aug 20:41:40.794 # Redis is now ready to exit, bye bye...
redis-server exited with status: 0
```

归根结底，使用 client 包并不需要写太多代码。

- - -
希望本指南帮助你顺利上手并运行 containerd。
如果有任何问题，欢迎加入云原生计算基金会（CNCF）Slack（`cloud-native.slack.com`）中的 `#containerd` 和 `#containerd-dev` 频道；和所有开源项目一样，如果你想为 containerd 或本指南做出贡献，请提交 pull request。[获取 CNCF slack 邀请。](https://slack.cncf.io)
