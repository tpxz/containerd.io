# containerd 的 mount 与 mount 管理 {#containerd-mounts-and-mount-management}

## Mount 类型 {#mount-type}

`Mount` 是 containerd 中一个重要的结构体，用于表示一个文件系统，而无需任何活动状态。
这样就可以把文件系统的挂载推迟到真正需要的时候。它同样支持临时挂载，containerd
通常用临时挂载来检视容器 image 的文件系统，或者在把文件系统交给底层运行时之前做出修改。
它还让底层运行时可以做各种优化，例如对某些 mount 使用 virtio-blk 而非 virtio-fs，
或者在另一个 mount namespace 内执行挂载。

`Mount` 类型被 `Snapshotter` 接口用来返回某个 snapshot 的文件系统。这让 snapshotter
可以专注于 snapshot 的存储生命周期，而不必用复杂的逻辑去处理已挂载文件系统的运行时生命周期。
这是 containerd 解耦架构的一部分：snapshotter 和运行时不需要共享状态，只需要传递这组 mount。

## Mount 管理 {#mount-management}

containerd 2.2 引入了 mount 管理器，用于扩展 mount 的功能，从而支持能力更强的 snapshotter
以及那些难以用原生文件系统 mount 表达的复杂用例。它还为 mount 增加了一层额外的资源追踪，
以更好地防止在宿主机 mount namespace 中泄漏 mount。

### 扩展 mount 类型 {#extending-the-mount-types}

通常 snapshotter 只能使用宿主机内核（或在一些高级用例中是虚拟机 guest 内核）可挂载的 mount 类型。
mount 管理器通过一个可插拔的接口来处理自定义 mount 类型，从而扩展了可用的 mount 类型。

自定义 mount handler 的接口非常简单。

```go
type Handler interface {
	Mount(context.Context, Mount, string, []ActiveMount) (ActiveMount, error)
	Unmount(context.Context, string) error
}
```

#### 内置的 mount handler {#built-in-mount-handlers}

##### Loopback handler {#loopback-handler}

loopback handler（`loop`）允许把文件挂载为 loopback 设备。这在挂载磁盘镜像或文件系统镜像时很有用，
无需事先配置好 loopback 设备。如果其他 mount 类型本身就支持 `loop` 选项，则优先使用该选项，
以便这些 mount 类型能在需要 loopback 时自行优化；当这个 handler 与另一种 mount 类型一起使用时，
可能会在并不必要的情况下强制使用 loopback。

```go
// Example mount using loopback
mount.Mount{
    Type:    "loop",
    Source:  "/path/to/disk.img",
    Options: []string{},
}
```

该 handler 会自动完成：
- 使用第一个可用的 loop 设备来建立 loopback 设备
- 让设备在挂载点上可用
- 在 unmount 时处理清理工作

### Mount transformer {#mount-transformers}

Mount transformer 是一类接口，可以基于之前的 mount 状态修改 mount。transformer 适合在 mount
被激活之前做准备工作，例如创建目录或格式化文件系统。

```go
type Transformer interface {
	Transform(context.Context, Mount, []ActiveMount) (Mount, error)
}
```

transformer 通过 mount 类型中的前缀模式来指定：`<transformer>/<mount-type>`。
多个 transformer 可以串联：`<transformer1>/<transformer2>/<mount-type>`。

#### 内置的 transformer {#built-in-transformers}

##### Format transformer（`format/`） {#format-transformer-format}

为了把多个 mount 串联起来，后续 mount 可能需要用到前一个 mount 的结果。其中一些 mount 参数
在挂载之前是未知的，因此无法用静态的 mount 值来表示。格式化 mount 允许为 mount 参数提供模板值，
在 mount 激活时用前面各个 mount 的结果填充。

格式化 mount 的类型以 `format/` 开头，后面跟着填充完格式化值之后期望的 mount 类型。
它基于 [go templates](https://pkg.go.dev/text/template) 做模板渲染来填充这些值。

值通过前面各个活动 mount 的索引来引用。下表列出了格式化 mount 中支持的取值。

| 取值 | 参数 | 示例 | 说明 |
|-----|------|---------|-------------|
| `source` | <index> | `{{ source 0 }}` | 索引 <index> 处活动 mount 的 source |
| `target` | <index> | `{{ target 0 }}` | 索引 <index> 处活动 mount 的 target |
| `mount` | <index> | `{{ mount 0 }}` | 索引 <index> 处活动 mount 的挂载点 |
| `overlay` | <start> <end> | `{{ overlay 0 2 }}` | 用 <start> 到 <end> 之间各活动挂载点填充 overlayfs 的 lowerdir 参数 |

格式化 mount 的处理方式与其他自定义 mount 不同。如果格式化之后得到的 mount 是系统支持的 mount，
就不需要像自定义 mount 那样由 mount handler 来挂载。

**示例：**
```go
// First mount provides the lower layer
mount.Mount{
    Type:   "bind",
    Source: "/var/lib/containerd/snapshots/1",
    Options: []string{"ro"},
},
// Second mount uses formatting to reference the first mount
mount.Mount{
    Type:   "format/overlay",
    Source: "overlay",
    Options: []string{
        "lowerdir={{ mount 0 }}",
        "upperdir=/upper",
        "workdir=/work",
    },
}
```

##### Mkfs transformer（`mkfs/`） {#mkfs-transformer-mkfs}

mkfs transformer 用于创建并格式化文件系统镜像。它支持在文件中创建 ext2、ext3、ext4 和 xfs
文件系统，这些文件随后可以作为 loopback 设备挂载。

带 `X-containerd.mkfs.` 前缀的 mount 选项会被该 transformer 消费：

| 选项 | 说明 | 示例 |
|--------|-------------|---------|
| `X-containerd.mkfs.size` | 文件系统镜像的大小（支持 MiB、GiB 之类的单位） | `X-containerd.mkfs.size=100MiB` |
| `X-containerd.mkfs.fs` | 文件系统类型（ext2、ext3、ext4、xfs） | `X-containerd.mkfs.fs=ext4` |
| `X-containerd.mkfs.uuid` | 文件系统的 UUID | `X-containerd.mkfs.uuid=550e8400-e29b-41d4-a716-446655440000` |

**示例：**
```go
mount.Mount{
    Type:   "mkfs/loop",
    Source: "/path/to/disk.img",
    Options: []string{
        "X-containerd.mkfs.size=1GiB",
        "X-containerd.mkfs.fs=ext4",
    },
}
```

这会：
1. 在 `/path/to/disk.img` 创建一个 1GiB 的文件
2. 将其格式化为 ext4
3. 为该文件建立一个 loopback 设备
4. 返回 loop 设备供后续挂载使用

##### Mkdir transformer（`mkdir/`） {#mkdir-transformer-mkdir}

mkdir transformer 在挂载前创建目录。这有助于确保 overlay 的 upperdir 和 workdir 目录存在，
或者用来创建挂载点。

带 `X-containerd.mkdir.` 前缀的 mount 选项会被该 transformer 消费：

| 选项格式 | 说明 |
|--------------|-------------|
| `X-containerd.mkdir.path=<dir>` | 以默认权限（0700）创建目录 |
| `X-containerd.mkdir.path=<dir>:<mode>` | 以指定的八进制模式创建目录 |
| `X-containerd.mkdir.path=<dir>:<mode>:<uid>:<gid>` | 以指定的模式和属主创建目录 |

**示例：**
```go
mount.Mount{
    Type:   "format/mkdir/overlay",
    Source: "overlay",
    Options: []string{
        "X-containerd.mkdir.path={{ mount 0 }}/upper:0755",
        "X-containerd.mkdir.path={{ mount 0 }}/work:0755",
        "lowerdir={{ mount 1 }}",
        "upperdir={{ mount 0 }}/upper",
        "workdir={{ mount 0 }}/work",
    },
}
```

#### 串联 transformer {#chaining-transformers}

transformer 可以串联起来，按顺序执行多个操作：

```go
mount.Mount{
    Type:   "mkfs/loop",
    Source: "/data/fs.img",
    Options: []string{
        "X-containerd.mkfs.size=500MiB",
        "X-containerd.mkfs.fs=xfs",
    },
},
mount.Mount{
    Type:   "xfs",
    Source: "{{ source 0 }}",  // Loop device from previous mount
    Options: []string{},
},
mount.Mount{
    Type:   "format/mkdir/overlay",
    Source: "overlay",
    Options: []string{
        "X-containerd.mkdir.path={{ mount 1 }}/upper:0755",
        "X-containerd.mkdir.path={{ mount 1 }}/work:0755",
        "lowerdir=/lower",
        "upperdir={{ mount 1 }}/upper",
        "workdir={{ mount 1 }}/work",
    },
}
```

这个示例：
1. 创建并格式化一个 500MiB 的 XFS 镜像
2. 建立 loop 设备并挂载该 XFS 文件系统
3. 在该 XFS 文件系统上创建目录并建立 overlay

### 垃圾回收与反向引用 {#garbage-collection-and-backreferences}

mount 管理器与 containerd 的垃圾回收系统集成，确保 mount 被正确追踪和清理。
mount 可以通过特殊标签引用其他资源：

| 标签 | 说明 |
|-------|-------------|
| `containerd.io/gc.bref.container.*` | 指向某个容器的反向引用 |
| `containerd.io/gc.bref.content.*` | 指向内容存储中某个 content 的反向引用 |
| `containerd.io/gc.bref.image.*` | 指向某个 image 的反向引用 |
| `containerd.io/gc.bref.snapshot.*` | 指向某个 snapshot 的反向引用 |

`.*` 后缀允许使用以 `.` 或 `/` 分隔的具名反向引用。

**示例：**
```go
info, err := mountManager.Activate(ctx, "my-mount", mounts,
    mount.WithLabels(map[string]string{
        "containerd.io/gc.bref.container": "container-id-123",
        "containerd.io/gc.bref.snapshot.overlayfs": "active-snapshot-key",
    }),
)
```

这些标签确保只要被引用的资源还存在，该 mount 就不会被垃圾回收；当这些引用被移除时，
该 mount 会被自动清理。

### 与运行时的关系 {#relationship-with-runtimes}

运行时应当在为容器设置 rootfs 之前，使用 mount 管理器发起 mount 的激活。激活调用中应当带上
运行时名称，以便 mount 管理器可以针对特定运行时的行为进行配置。

`ActivateOptions` 允许运行时表明自己能处理哪些 mount 类型：

```go
// Runtime can handle formatting, so don't let mount manager do it
info, err := mountManager.Activate(ctx, name, mounts,
    mount.WithAllowMountType("format/*"),
)

// Runtime can handle loop devices
info, err := mountManager.Activate(ctx, name, mounts,
    mount.WithAllowMountType("loop"),
)
```

#### 对 containerd shim 的支持 {#support-with-containerd-shims}

默认情况下，containerd 运行时会调用 mount 管理器来激活 mount，由它执行各种 transformation
和自定义 mount。不过，运行时 shim 也可以选择自己处理某些 mount 类型或 transformation，
以便根据运行环境优化性能。例如，基于虚拟机的运行时可以选择自己处理 loopback mount，
直接把磁盘镜像文件传给虚拟机，而不是在宿主机上建立 loop 设备。运行时 shim 可以在其
runtime info 中导出注解 `containerd.io/runtime-allow-mounts`，表明该 shim 能处理哪些 mount 类型。
其取值以逗号分隔，在激活 mount 时通过 `mount.WithAllowMountType` 选项传入。

### Mount 管理器接口 {#mount-manager-interface}

完整的 mount 管理器接口：

```go
type Manager interface {
    Activate(context.Context, string, []Mount, ...ActivateOpt) (ActivationInfo, error)
    Deactivate(context.Context, string) error
    Info(context.Context, string) (ActivationInfo, error)
    Update(context.Context, ActivationInfo, ...string) (ActivationInfo, error)
    List(context.Context, ...string) ([]ActivationInfo, error)
}
```

**方法：**
- `Activate`：以一个唯一名称激活一组 mount
- `Deactivate`：卸载并清理一次激活
- `Info`：获取某个活动 mount 的信息
- `Update`：更新某个活动 mount（尚未实现）
- `List`：列出所有活动 mount，可选择进行过滤

**ActivationInfo** 包含：
- `Name`：本次激活的唯一标识
- `Active`：由 mount 管理器处理的 mount
- `System`：必须由系统/运行时执行的其余 mount
- `Labels`：与本次激活关联的标签

### 存储与持久化 {#storage-and-persistence}

mount 管理器把激活状态存储在 BoltDB 数据库中，并在一个专用目录里维护 mount 目标。
这带来了：

- 崩溃恢复：mount 可以被追踪，并在 daemon 重启后清理
- 垃圾回收：与 containerd 的 GC 系统集成
- 租约支持：mount 可以关联到租约以便管理生命周期

### 用法示例 {#example-usage}

```go
// Initialize mount manager
mm, err := manager.NewManager(
    db,
    targetDir,
    manager.WithMountHandler("loop", mount.LoopbackHandler()),
)

// Create mounts for a writable overlay with custom block device
mounts := []mount.Mount{
    {
        Type:   "mkfs/loop",
        Source: "/data/writable.img",
        Options: []string{
            "X-containerd.mkfs.size=1GiB",
            "X-containerd.mkfs.fs=ext4",
        },
    },
    {
        Type:   "ext4",
        Source: "{{ source 0 }}",
    },
    {
        Type:   "mkdir/format/overlay",
        Source: "overlay",
        Options: []string{
            "X-containerd.mkdir.path={{ mount 1 }}/upper:0755",
            "X-containerd.mkdir.path={{ mount 1 }}/work:0755",
            "lowerdir=/snapshots/base",
            "upperdir={{ mount 1 }}/upper",
            "workdir={{ mount 1 }}/work",
        },
    },
}

// Activate with lease and backreference
info, err := mm.Activate(ctx, "container-123-rootfs", mounts,
    mount.WithLabels(map[string]string{
        "containerd.io/gc.bref.container": "container-123",
    }),
)

// info.Active contains mounts handled by mount manager
// info.System contains remaining mounts to perform in container namespace

// Later, cleanup
err = mm.Deactivate(ctx, "container-123-rootfs")
```
