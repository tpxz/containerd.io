# Snapshotters {#snapshotters}

Snapshotter 负责管理容器文件系统的 snapshot。

可以运行 `ctr plugins ls` 或 `nerdctl info` 查看可用的 snapshotter。

## 核心 snapshotter plugin {#core-snapshotter-plugins}

通用：
- `overlayfs`（默认）：OverlayFS。这个驱动类似于 Docker/Moby 的 “overlay2” 存储驱动，但 containerd 的实现并不叫 “overlay2”。
- `native`：原生文件复制驱动。类似于 Docker/Moby 的 “vfs” 驱动。

基于块设备：
- [`blockfile`](./blockfile.md)：为每个 snapshot 使用裸块文件的驱动。块文件从父块文件或空白基础块文件复制而来。挂载时需要虚拟机或对 loopback mount 的支持。
- `devmapper`：ext4/xfs device mapper。参见 [`devmapper.md`](./devmapper.md)。

文件系统专用：
- `btrfs`：btrfs。需要把 plugin root（`/var/lib/containerd/io.containerd.snapshotter.v1.btrfs`）挂载为 btrfs。
- `zfs`：ZFS。需要把 plugin root（`/var/lib/containerd/io.containerd.snapshotter.v1.zfs`）挂载为 ZFS。另见 https://github.com/containerd/zfs 。
- `erofs`：EROFS。活动 snapshot 需要启用 `OverlayFS` 内核模块。另见 [`erofs.md`](./erofs.md)。

[已弃用](https://github.com/containerd/containerd/blob/main/RELEASES.md#deprecated-features)：
- `aufs`：AUFS。自 containerd 1.5 起已弃用。在 containerd 2.0 中已移除。另见 https://github.com/containerd/aufs 。

## 非核心 snapshotter plugin {#non-core-snapshotter-plugins}

- `fuse-overlayfs`：[FUSE-OverlayFS Snapshotter](https://github.com/containerd/fuse-overlayfs-snapshotter)
- `nydus`：[Nydus Snapshotter](https://github.com/containerd/nydus-snapshotter)
- `overlaybd`：[OverlayBD Snapshotter](https://github.com/containerd/accelerated-container-image)
- `stargz`：[Stargz Snapshotter](https://github.com/containerd/stargz-snapshotter)

## Mount target {#mount-target}

mount 可以选择性地指定一个 target，用于描述容器 rootfs 中的子挂载点。例如，如果
snapshotter 希望在一个 overlayfs mount 之上 bind mount 到某个子目录，可以返回
下面这组 mount：

```json
[
    {
        "type": "overlay",
        "source": "overlay",
        "options": [
            "workdir=...",
            "upperdir=...",
            "lowerdir=..."
        ]
    },
    {
        "type": "bind",
        "source": "/path/on/host",
        "target": "/path/inside/container",
        "options": [
            "ro",
            "rbind"
        ]
    }
]
```

不过，bind mount 要求挂载点 `/path/inside/container` 必须存在，因此前面某个 mount
必须负责在 rootfs 中提供该目录。在这个例子中，overlay 的某个 lower dir 里有这个
目录，从而使 bind mount 得以进行。
