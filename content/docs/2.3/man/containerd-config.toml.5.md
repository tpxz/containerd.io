# /etc/containerd/config.toml 5 04/05/2022

## 名称 {#name}

containerd-config.toml - containerd 的配置文件

## 概要 {#synopsis}

**config.toml** 文件是 containerd daemon 的配置文件。该文件必须放置在
**/etc/containerd/config.toml**，或者通过 **containerd** 的 **--config** 选项指定，
daemon 才会使用它。如果该文件不在相应位置，也没有通过 **--config** 选项提供，
containerd 会使用其默认配置，默认配置可以用 **containerd config(1)** 命令显示出来。

## 描述 {#description}

用于配置 containerd daemon 的 TOML 文件包含一小组全局设置，随后是若干针对 daemon
各个配置领域的小节。此外还有一个 **plugins** 小节，让每个 containerd plugin 都拥有
一块用于 plugin 专属配置与设置的区域。

## 格式 {#format}

**version**
: 配置文件中的 version 字段指定配置的版本。如果配置文件中未指定版本号，则视为
version 1 配置并按此解析。version 4 是最新的配置版本。较旧的配置会在启动时自动迁移。

**root**
: containerd 元数据的根目录。（默认值："/var/lib/containerd"）

**state**
: containerd 的 state 目录（默认值："/run/containerd"）

**plugin_dir**
: 存放动态 plugin 的目录

**[grpc]** *（version 4 起已弃用）*
: gRPC socket 监听器设置所在的小节。在 version 4 中，请改用 server plugin
**io.containerd.server.v1.grpc** 和 **io.containerd.server.v1.grpc-tcp**。
已有配置会自动迁移。包含以下属性：

- **address**（默认值："/run/containerd/containerd.sock"）
- **tcp_address**
- **tcp_tls_cert**
- **tcp_tls_key**
- **uid**（默认值：0）
- **gid**（默认值：0）
- **max_recv_message_size**
- **max_send_message_size**

**[ttrpc]** *（version 4 起已弃用）*
: TTRPC 设置所在的小节。在 version 4 中，请改用 server plugin
**io.containerd.server.v1.ttrpc**。在更早的版本中，当 TTRPC 地址未显式设置时，
它会从 GRPC 地址推导而来（grpcAddress + ".ttrpc"），并沿用 GRPC 的 UID/GID。
在 version 4 中，每个 server plugin 都独立配置；当省略其配置块时，TTRPC plugin
会使用自己的默认值。包含以下属性：

- **address**（默认值：""）
- **uid**（默认值：0）
- **gid**（默认值：0）

**[debug]** *（version 4 起已弃用）*
: 用于启用和配置 debug socket 监听器的小节。在 version 4 中，请改用 server plugin
**io.containerd.server.v1.debug**。包含以下属性：

- **address**（默认值："/run/containerd/debug.sock"）
- **uid**（默认值：0）
- **gid**（默认值：0）
- **level**（默认值："info"）设置 debug 日志级别。支持的级别有：
  "trace"、"debug"、"info"、"warn"、"error"、"fatal"、"panic"
- **format**（默认值："text"）设置日志格式。支持的格式为 "text" 和 "json"

**[metrics]** *（version 4 起已弃用）*
: 用于启用和配置 metrics 监听器的小节。在 version 4 中，请改用 server plugin
**io.containerd.server.v1.metrics**。包含以下属性：

- **address**（默认值：""）metrics 端点默认不监听
- **grpc_histogram**（默认值：false）开启或关闭 gRPC 直方图指标

**disabled_plugins**
: disabled plugins 是要禁用的 plugin 的 ID 列表。被禁用的 plugin 不会被初始化和启动。

**required_plugins**
: required plugins 是必需 plugin 的 ID 列表。如果任何一个必需 plugin 不存在，或者
初始化、启动失败，containerd 会退出。

**[plugins]**
: plugins 小节包含由已安装 plugin 暴露出来的配置项。
以下 plugin 默认启用，其设置如下所示。
默认不启用的 plugin 会自行提供其配置项的文档。

- **[plugins."io.containerd.server.v1.grpc"]** 配置主 gRPC server 监听器（version 4）：
  - **address**（默认值："/run/containerd/containerd.sock"）
  - **uid**（默认值：有效 UID）
  - **gid**（默认值：有效 GID）
  - **max_recv_message_size**（默认值：16777216）
  - **max_send_message_size**（默认值：16777216）
- **[plugins."io.containerd.server.v1.grpc-tcp"]** 配置 TCP gRPC server 监听器（version 4）。
  地址为空时跳过：
  - **address**（默认值：""）
  - **tls_cert**、**tls_key**、**tls_ca**、**tls_common_name**
  - **max_recv_message_size**（默认值：16777216）
  - **max_send_message_size**（默认值：16777216）
- **[plugins."io.containerd.server.v1.ttrpc"]** 配置 TTRPC server 监听器（version 4）。
  在 version 4 中，该 plugin 独立于 gRPC plugin 进行配置。
  如果省略该 plugin 配置块，TTRPC server 会绑定到自己的默认地址，
  而不是从 gRPC 地址推导：
  - **address**（默认值："/run/containerd/containerd.sock.ttrpc"）
  - **uid**（默认值：有效 UID）
  - **gid**（默认值：有效 GID）
- **[plugins."io.containerd.server.v1.debug"]** 配置 debug server 监听器（version 4）。
  地址为空时跳过：
  - **address**（默认值：""）
  - **uid**（默认值：0）
  - **gid**（默认值：0）
- **[plugins."io.containerd.server.v1.metrics"]** 配置 metrics HTTP 监听器（version 4）。
  地址为空时跳过：
  - **address**（默认值：""）
- **[plugins."io.containerd.monitor.v1.cgroups"]** 只有一个选项 __no_prometheus__（默认值：**false**）
- **[plugins."io.containerd.service.v1.diff-service"]** 只有一个选项 __default__，是一个列表，默认设为 **["walking"]**
- **[plugins."io.containerd.gc.v1.scheduler"]** 有多个选项，用于对调度器做高级调优：
  - **pause_threshold** 是 GC 最多可被调度占用的时间比例（默认值：**0.02**），
  - **deletion_threshold** 保证在发生 n 次删除后调度 GC（默认值：**0** [不触发]），
  - **mutation_threshold** 保证在发生 n 次数据库变更后调度 GC（默认值：**100**），
  - **schedule_delay** 定义触发事件之后、调度 GC 之前的延迟（默认值 **"0ms"** [立即]），
  - **startup_delay** 定义启动之后、调度 GC 之前的延迟（默认值 **"100ms"**）
- **[plugins."io.containerd.runtime.v2.task"]** 指定用于配置 runtime shim 的选项：
  - **platforms** 指定支持的平台列表
  - **sched_core** 核心调度（core scheduling）特性只允许受信任的任务并发运行在
    共享计算资源的 cpu 上（例如同一个核心上的超线程）。（默认值：**false**）
- **[plugins."io.containerd.service.v1.tasks-service"]** 有一些性能相关选项：
  - **blockio_config_file**（仅 Linux）指定 blockio class 定义文件的路径
    （默认值：**""**）。控制 I/O 调度器优先级和带宽限流。
    文件格式详见 [blockio 配置](https://github.com/intel/goresctrl/blob/main/doc/blockio.md#configuration)。
  - **rdt_config_file**（仅 Linux）指定用于配置 RDT 的配置文件路径
    （默认值：**""**）。启用对 Intel RDT 的支持，这是一项用于缓存和内存带宽管理的技术。
    文件格式详见 [RDT 配置](https://github.com/intel/goresctrl/blob/main/doc/rdt.md#configuration)。
- **[plugins."io.containerd.grpc.v1.cri".containerd]** 包含 CRI plugin 的选项，以及 CRI 选项的子节点：
  - **default_runtime_name**（默认值：**"runc"**）指定默认的 runtime 名称
- **[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]** 一个或多个容器运行时，每个都有唯一的名称
- **[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.<runtime>]** 名为 `<runtime>` 的运行时
- **[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.<runtime>.options]** 名为 `<runtime>` 的运行时的选项，其中最重要的是：
  -  **BinaryName** 指定 shim 实际调用的运行时的路径，例如 `"/usr/bin/runc"`




**oom_score**
: 应用到 containerd daemon 进程上的内存不足（OOM）分值（默认值：0）

**[cgroup]**
: Linux cgroup 相关设置所在的小节

- **path**（默认值：""）为创建的容器指定自定义的 cgroup 路径

**[proxy_plugins]**
: proxy plugins 配置那些通过 gRPC 通信的 plugin

- **type**（默认值：""）
- **address**（默认值：""）

**timeouts**
: 以时长形式指定的超时设置

<!-- [timeouts]
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "2s" -->

**imports**
: imports 是要包含进来的额外配置文件列表。
它可以把主配置文件拆分开，把某些小节单独保存
（例如厂商可以把自定义的运行时配置放在单独的文件中，而不必修改主
`config.toml`）。
被导入的文件会覆盖 `int`、`string` 这类简单字段（在其非空时），
并会追加 `array` 和 `map` 字段。
被导入的文件同样带有版本，且其版本不能高于主配置的版本。

**stream_processors**

- **accepts**（默认值："[]"）接受特定的 media-type
- **returns**（默认值：""）返回的 media-type
- **path**（默认值：""）二进制程序的路径或名称
- **args**（默认值："[]"）传给该二进制程序的参数

## 示例 {#examples}

### version 4 配置 {#version-4-configuration}

以下是一个使用 version 4 的 **config.toml** 示例，其中 server 设置以 plugin 形式配置：

```toml
version = 4

root = "/var/lib/containerd"
state = "/run/containerd"
oom_score = 0
imports = ["/etc/containerd/runtime_*.toml", "./debug.toml"]

[plugins."io.containerd.server.v1.grpc"]
  address = "/run/containerd/containerd.sock"

[plugins."io.containerd.server.v1.ttrpc"]
  address = "/run/containerd/containerd.sock.ttrpc"

[plugins."io.containerd.server.v1.debug"]
  address = "/run/containerd/debug.sock"
  level = "info"

[cgroup]
  path = ""

[plugins]
  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false
  [plugins."io.containerd.service.v1.diff-service"]
    default = ["walking"]
  [plugins."io.containerd.gc.v1.scheduler"]
    pause_threshold = 0.02
    deletion_threshold = 0
    mutation_threshold = 100
    schedule_delay = 0
    startup_delay = "100ms"
  [plugins."io.containerd.runtime.v2.task"]
    platforms = ["linux/amd64"]
    sched_core = true
  [plugins."io.containerd.service.v1.tasks-service"]
    blockio_config_file = ""
    rdt_config_file = ""
```

### 多个运行时 {#multiple-runtimes}

以下是一个包含两个运行时的部分配置示例：

```toml
[plugins]

  [plugins."io.containerd.grpc.v1.cri"]

    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          privileged_without_host_devices = false
          runtime_type = "io.containerd.runc.v2"

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            BinaryName = "/usr/bin/runc"

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.other]
          privileged_without_host_devices = false
          runtime_type = "io.containerd.runc.v2"

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.other.options]
            BinaryName = "/usr/bin/path-to-runtime"
```

上面的配置创建了两份具名的运行时配置——分别名为 `runc` 和 `other`——并把默认运行时设为 `runc`。
上述配置<em>仅</em>用于通过 CRI 调用的运行时。要在本例中使用非默认的 "other" 运行时，
spec 中需要包含名为 "other" 的 runtime handler，以表明希望使用该具名运行时配置。

CRI 规范中包含一个 [`runtime_handler` 字段](https://github.com/kubernetes/cri-api/blob/de5f1318aede866435308f39cb432618a15f104e/pkg/apis/runtime/v1/api.proto#L476)，它会引用这个具名运行时。

需要注意其命名约定。运行时位于 `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]` 之下，
每个运行时都有唯一的名称，例如 `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]`。
此外，每个运行时都可以在 `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.<runtime>.options]` 下设置 shim 专属选项，
例如 `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]`。

`io.containerd.runc.v2` 运行时用于在 Linux 上运行兼容 OCI 的运行时，例如 runc。在上面的示例中，`runtime_type`
字段指定要使用的 shim（`io.containerd.runc.v2`），而 `BinaryName` 字段是一个 shim 专属选项，指定 OCI 运行时的路径。

对于名为 "runc" 的示例配置，shim 会启动 `/usr/bin/runc` 作为 OCI 运行时。对于名为
"other" 的示例配置，shim 则会启动 `/usr/bin/path-to-runtime`。

## 缺陷 {#bugs}

如果遇到具体问题，请提交到
https://github.com/containerd/containerd。

## 作者 {#author}

Phil Estes <estesp@gmail.com>

## 参见 {#see-also}

ctr(8), containerd-config(8), containerd(8)
