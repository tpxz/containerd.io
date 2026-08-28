## Devmapper snapshotter {#devmapper-snapshotter}

Devmapper 是一个 `containerd` snapshotter plugin，它把 snapshot 以文件系统镜像的形式存放在
Device-mapper thin-pool 中。devmapper plugin 利用了 Device-mapper 的特性，例如
[设备 snapshot 支持](https://www.kernel.org/doc/Documentation/device-mapper/snapshot.txt)。

## 配置 {#setup}

要使用 devmapper snapshotter plugin，需要事先准备好一个 Device-mapper `thin-pool`，并更新 containerd 的配置文件。
该文件通常位于 `/etc/containerd/config.toml`。

下面是可以写入配置文件的一个最小示例条目：

```toml
version = 2

[plugins]
  ...
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    root_path = "/var/lib/containerd/devmapper"
    pool_name = "containerd-pool"
    base_image_size = "8192MB"
  ...
```

支持以下配置标志：
* `root_path` - 存放元数据的目录（如果为空，将使用 `containerd` plugin 的
  默认位置）
* `pool_name` - Device-mapper thin-pool 使用的名称。pool 名称
  应与 `/dev/mapper/` 目录中的名称一致
* `base_image_size` - 定义从基础（pool）设备创建 thin 设备 snapshot 时分配多少空间
* `async_remove` - 是否使用 snapshot GC 的清理回调来异步移除设备（默认：`false`）
* `discard_blocks` - 移除设备时是否 discard block。在使用 loopback 设备时，这对把磁盘空间归还给文件系统特别有用。（默认：`false`）
* `fs_type` - 定义 snapshot 设备 mount 时使用的文件系统。有效值为 `ext4` 和 `xfs`（默认：`"ext4"`）
* `fs_options` - 可选地定义文件系统选项。目前仅适用于 `ext4` 文件系统。（默认：`""`）

`root_path`、`pool_name` 和 `base_image_size` 是必需的 snapshotter 参数。

## 运行 {#run}
用下面的命令试一下：

```bash
ctr images pull --snapshotter devmapper docker.io/library/hello-world:latest
ctr run --snapshotter devmapper docker.io/library/hello-world:latest test
```

## 前置要求 {#requirements}

devicemapper snapshotter 要求机器上安装并可用 `dmsetup`（>= 1.02.110）命令行工具。
在 Ubuntu 上可以用 `apt-get install dmsetup` 命令安装。

### 如何配置 Device-Mapper thin-pool {#how-to-setup-device-mapper-thin-pool}

配置 Device-mapper thin-pool 的方式有很多，取决于你的需求、磁盘配置和环境。
下面给出两种常见配置，一种面向开发环境，一种面向生产环境。

#### 1. Loopback 设备 {#1-loopback-devices}

在本地开发环境中可以使用 loopback 设备。这类配置很简单，很适合开发和测试
（*请注意这种配置速度慢，不推荐用于生产环境*）。
运行下面的脚本来创建一个 thin-pool 设备以及配套的元数据和数据设备文件：

```bash
#!/bin/bash
set -ex

DATA_DIR=/var/lib/containerd/devmapper
POOL_NAME=devpool

sudo mkdir -p ${DATA_DIR}

# Create data file
sudo touch "${DATA_DIR}/data"
sudo truncate -s 100G "${DATA_DIR}/data"

# Create metadata file
sudo touch "${DATA_DIR}/meta"
sudo truncate -s 10G "${DATA_DIR}/meta"

# Allocate loop devices
DATA_DEV=$(sudo losetup --find --show "${DATA_DIR}/data")
META_DEV=$(sudo losetup --find --show "${DATA_DIR}/meta")

# Define thin-pool parameters.
# See https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt for details.
SECTOR_SIZE=512
DATA_SIZE="$(sudo blockdev --getsize64 -q ${DATA_DEV})"
LENGTH_IN_SECTORS=$(bc <<< "${DATA_SIZE}/${SECTOR_SIZE}")
DATA_BLOCK_SIZE=128
LOW_WATER_MARK=32768

# Create a thin-pool device
sudo dmsetup create "${POOL_NAME}" \
    --table "0 ${LENGTH_IN_SECTORS} thin-pool ${META_DEV} ${DATA_DEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK}"

cat << EOF
#
# Add this to your config.toml configuration file and restart the containerd daemon
#
[plugins]
  [plugins."io.containerd.snapshotter.v1.devmapper"]
    pool_name = "${POOL_NAME}"
    root_path = "${DATA_DIR}"
    base_image_size = "10GB"
    discard_blocks = true
EOF
```

使用 `dmsetup` 验证 thin-pool 已成功创建：
```bash
sudo dmsetup ls
devpool	(253:0)
```

配置好并重启 `containerd` 之后，你会看到如下输出：
```
INFO[2020-03-17T20:24:45.532604888Z] loading plugin "io.containerd.snapshotter.v1.devmapper"...  type=io.containerd.snapshotter.v1
INFO[2020-03-17T20:24:45.532672738Z] initializing pool device "devpool"
```

#### 2. direct-lvm thin-pool {#2-direct-lvm-thin-pool}

另一种配置 thin-pool 的方式是使用 [container-storage-setup](https://github.com/projectatomic/container-storage-setup)
工具（早先叫做 `docker-storage-setup`）。它是一个用于配置 devicemapper 这类 CoW 文件系统的脚本：

```bash
#!/bin/bash
set -ex

# Block device to use for devmapper thin-pool
BLOCK_DEV=/dev/sdf
POOL_NAME=devpool
VG_NAME=containerd

# Install container-storage-setup tool
git clone https://github.com/projectatomic/container-storage-setup.git
cd container-storage-setup/
sudo make install-core
echo "Using version $(container-storage-setup -v)"

# Create configuration file
# Refer to `man container-storage-setup` to see available options
sudo tee /etc/sysconfig/docker-storage-setup <<EOF
DEVS=${BLOCK_DEV}
VG=${VG_NAME}
CONTAINER_THINPOOL=${POOL_NAME}
EOF

# Run the script
sudo container-storage-setup

cat << EOF
#
# Add this to your config.toml configuration file and restart containerd daemon
#
[plugins]
  [plugins.devmapper]
    root_path = "/var/lib/containerd/devmapper"
    pool_name = "${VG_NAME}-${POOL_NAME}"
    base_image_size = "10GB"
EOF
```

如果成功，`container-storage-setup` 会输出：
```
+ echo VG=containerd
+ sudo container-storage-setup
INFO: Volume group backing root filesystem could not be determined
INFO: Writing zeros to first 4MB of device /dev/xvdf
4+0 records in
4+0 records out
4194304 bytes (4.2 MB) copied, 0.0162906 s, 257 MB/s
INFO: Device node /dev/xvdf1 exists.
  Physical volume "/dev/xvdf1" successfully created.
  Volume group "containerd" successfully created
  Rounding up size to full physical extent 12.00 MiB
  Thin pool volume with chunk size 512.00 KiB can address at most 126.50 TiB of data.
  Logical volume "devpool" created.
  Logical volume containerd/devpool changed.
...
```

而 `dmsetup` 会产生下面的输出：
```bash
sudo dmsetup ls
containerd-devpool          (253:2)
containerd-devpool_tdata    (253:1)
containerd-devpool_tmeta    (253:0)
```

关于生产环境 devmapper 配置的更多信息，另见 [Configure direct-lvm mode for production](https://docs.docker.com/storage/storagedriver/device-mapper-driver/#configure-direct-lvm-mode-for-production)。

## 更多资源 {#additional-resources}

关于 Device-mapper、精简配置（thin provisioning）等内容的更多信息，可以参考以下资源：

* https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/logical_volume_manager_administration/device_mapper
* https://en.wikipedia.org/wiki/Device_mapper
* https://docs.docker.com/storage/storagedriver/device-mapper-driver/
* https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt
* https://www.kernel.org/doc/Documentation/device-mapper/snapshot.txt
