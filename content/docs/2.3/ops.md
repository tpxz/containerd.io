# 面向运维和管理员的 containerd {#containerd-for-ops-and-admins}

containerd 的设计目标是成为一个可以运行在任何系统上的简单 daemon。
它提供最小化的配置，在必要时可通过这些配置项来调整 daemon 的行为以及所使用的 plugin。

```
NAME:
   containerd -
                    __        _                     __
  _________  ____  / /_____ _(_)___  ___  _________/ /
 / ___/ __ \/ __ \/ __/ __ `/ / __ \/ _ \/ ___/ __  /
/ /__/ /_/ / / / / /_/ /_/ / / / / /  __/ /  / /_/ /
\___/\____/_/ /_/\__/\__,_/_/_/ /_/\___/_/   \__,_/

high performance container runtime


USAGE:
   containerd [global options] command [command options] [arguments...]

VERSION:
   v2.0.0-beta.0

DESCRIPTION:

containerd is a high performance container runtime whose daemon can be started
by using this command. If none of the *config*, *publish*, *oci-hook*, or *help* commands
are specified, the default action of the **containerd** command is to start the
containerd daemon in the foreground.


A default configuration is used if no TOML configuration is specified or located
at the default file location. The *containerd config* command can be used to
generate the default configuration for containerd. The output of that command
can be used and modified as necessary as a custom configuration.

COMMANDS:
   config    Information on the containerd config
   publish   Binary to publish events to containerd
   oci-hook  Provides a base for OCI runtime hooks to allow arguments to be injected.
   help, h   Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --config value, -c value     Path to the configuration file (default: "/etc/containerd/config.toml")
   --log-level value, -l value  Set the logging level [trace, debug, info, warn, error, fatal, panic]
   --address value, -a value    Address for containerd's GRPC server
   --root value                 containerd root directory
   --state value                containerd state directory
   --help, -h                   Show help
   --version, -v                Print the version

```

虽然少数 daemon 级别的选项可以通过 CLI 标志设置，但 containerd 的大部分配置都保存在配置文件中。
配置文件的默认路径是 `/etc/containerd/config.toml`。
你可以在启动 daemon 时通过 `--config,-c` 标志修改该路径。

## systemd {#systemd}

如果你使用 systemd 作为 init 系统（大多数现代 Linux 操作系统都是如此），则 service 文件需要做一些修改。

```systemd
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
```

`Delegate=yes` 和 `KillMode=process` 是 `[Service]` 段中最重要的两处改动。

`Delegate` 允许 containerd 及其 runtime 管理自己创建的容器的 cgroup。
如果不设置该选项，systemd 会尝试把这些进程移动到它自己的 cgroup 中，导致 containerd 及其 runtime 无法正确统计容器的资源使用情况。

`KillMode` 用于处理 containerd 关闭时的行为。
默认情况下，systemd 会查看该服务对应的命名 cgroup，并杀掉它所知道的每一个进程。
这并不是我们想要的结果。
从运维角度看，我们希望能够升级 containerd 的同时让已有容器不中断地继续运行。
把 `KillMode` 设置为 `process` 可以确保 systemd 只杀掉 containerd daemon，而不会杀掉 shim 和容器等子进程。

下面的 `systemd-run` 命令以类似的方式启动 containerd：
```
sudo systemd-run -p Delegate=yes -p KillMode=process /usr/local/bin/containerd
```

## 基础配置 {#base-configuration}

在 containerd 配置文件中，你可以找到持久化存储和运行时存储位置的设置，以及各类 API 的 grpc、debug 和 metrics 地址。

其中有几项设置对运维很重要。
第一项是 `oom_score`。因为 containerd 要管理多个容器，我们需要确保在 containerd daemon 进入内存不足状态之前，先杀掉容器。
我们也不希望让 containerd 完全无法被杀掉，而是希望把它的分值降低到与其他系统 daemon 相当的水平。

containerd 还会在 `/v1/metrics` 下以 Prometheus metrics 格式导出自身的指标以及容器级别的指标。
目前 Prometheus 只支持 TCP 端点，因此 metrics 地址应当是一个你的 Prometheus 基础设施能够抓取指标的 TCP 地址。

containerd 在主机系统上有两个不同的存储位置。
一个用于持久化数据，另一个用于运行时状态。

`root` 用于存储 containerd 的各类持久化数据。
snapshot、content、容器和 image 的元数据，以及任何 plugin 数据都保存在这个位置。
root 目录也会按 containerd 加载的 plugin 进行命名空间划分。
每个 plugin 都有自己的目录用于存放数据。
containerd 自身其实没有需要存储的持久化数据，它的功能全部来自所加载的 plugin。


```
/var/lib/containerd/
├── io.containerd.content.v1.content
│   ├── blobs
│   └── ingest
├── io.containerd.metadata.v1.bolt
│   └── meta.db
├── io.containerd.runtime.v2.task
│   ├── default
│   └── example
├── io.containerd.snapshotter.v1.btrfs
└── io.containerd.snapshotter.v1.overlayfs
    ├── metadata.db
    └── snapshots
```

`state` 用于存储各类临时数据。
socket、pid、运行时状态、mount point，以及其他不能在重启之间保留的 plugin 数据都存放在这个位置。

```
/run/containerd
├── containerd.sock
├── debug.sock
├── io.containerd.runtime.v2.task
│   └── default
│       └── redis
│           ├── config.json
│           ├── init.pid
│           ├── log.json
│           └── rootfs
│               ├── bin
│               ├── data
│               ├── dev
│               ├── etc
│               ├── home
│               ├── lib
│               ├── media
│               ├── mnt
│               ├── proc
│               ├── root
│               ├── run
│               ├── sbin
│               ├── srv
│               ├── sys
│               ├── tmp
│               ├── usr
│               └── var
└── runc
    └── default
        └── redis
            └── state.json
```

`root` 和 `state` 两个目录都会按 plugin 进行命名空间划分。
这两个目录都属于 containerd 及其 plugin 的实现细节。
不应当去改动它们，否则可能出现（并且一定会出现）数据损坏和缺陷。
已知外部应用读取或监听这些目录中的变化，会在 containerd 和/或其 plugin 尝试清理资源时导致 `EBUSY` 和陈旧的文件句柄。

```toml
version = 2

# persistent data location
root = "/var/lib/containerd"
# runtime state information
state = "/run/containerd"
# set containerd's OOM score
oom_score = -999

# grpc configuration
[grpc]
  address = "/run/containerd/containerd.sock"
  # socket uid
  uid = 0
  # socket gid
  gid = 0

# debug configuration
[debug]
  address = "/run/containerd/debug.sock"
  # socket uid
  uid = 0
  # socket gid
  gid = 0
  # debug level
  level = "info"

# metrics configuration
[metrics]
  # tcp address!
  address = "127.0.0.1:1234"
```

## Plugin 配置 {#plugin-configuration}

说到底，containerd 的内核非常小。
真正的功能来自 plugin。
从 snapshotter、runtime 到 content，全部都是在运行时注册的 plugin。
由于这些 plugin 差异极大，我们需要一种方式为它们提供类型安全的配置。
唯一可行的方式是通过配置文件，而不是 CLI 标志。

在配置文件中，你可以通过 `[plugins.<name>]` 段为所使用的一组 plugin 指定 plugin 级别的选项。
你需要阅读对应 plugin 的文档，以了解该 plugin 接受哪些选项。

参见 [containerd 的 Plugin 文档](./PLUGINS.md)

### Bolt 元数据 Plugin {#bolt-metadata-plugin}

bolt 元数据 plugin 允许配置 namespace 之间的内容共享策略。

默认模式 "shared" 会让 blob 一旦被拉取到任意 namespace，就在所有 namespace 中可用。
如果打开一个 writer 时给出的 "Expected" digest 在后端已经存在，该 blob 就会被引入到当前 namespace。

另一种模式 "isolated" 要求客户端证明自己确实有权访问这些内容，即必须把全部内容提交到 ingest，blob 才会被加入该 namespace。

两种模式共享底层数据，"shared" 可以减少跨 namespace 的总带宽消耗，代价是只要知道 digest 就能访问任意 blob。

默认值是 "shared"。虽然这在绝大多数场景下都是最理想的策略，但也可以通过下面的配置切换到 "isolated" 模式：

```toml
version = 2

[plugins."io.containerd.metadata.v1.bolt"]
	content_sharing_policy = "isolated"
```

在 "isolated" 模式下，还可以通过给某个 namespace 添加标签 `containerd.io/namespace.shareable=true`，只共享该 namespace 的内容。
这样即使内容共享策略设置为 "isolated"，该 namespace 的 blob 也会在所有其他 namespace 中可用。
如果该标签的值不是 `true`，则该 namespace 的内容不会被共享。
