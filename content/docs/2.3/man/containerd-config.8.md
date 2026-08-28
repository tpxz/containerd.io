# containerd-config 8 01/30/2018 {#containerd-config-8-01302018}

## 名称 {#name}

containerd-config - 关于 containerd 配置的信息

## 用法概要 {#synopsis}

containerd config [command]

## 描述 {#description}

*containerd config* 命令有一个名为 *default* 的子命令，它会在标准输出上打印当前
版本 containerd daemon 的默认配置。

该输出可以通过管道写入 __containerd-config.toml(5)__ 文件并放置在
**/etc/containerd** 中，作为 containerd daemon 启动时使用的配置。该配置也可以放在
文件系统的任意位置，并通过 containerd daemon 的 **--config** 选项来使用。

关于 containerd 配置选项的更多信息，参见 __containerd-config.toml(5)__。

## 选项 {#options}

**default**
: 该子命令会把 TOML 格式的 containerd 配置输出到标准输出

## Bug {#bugs}

如果遇到具体问题，请在 https://github.com/containerd/containerd
提交 issue。

## 作者 {#author}

Phil Estes <estesp@gmail.com>

## 参见 {#see-also}

ctr(8), containerd(8), containerd-config.toml(5)
