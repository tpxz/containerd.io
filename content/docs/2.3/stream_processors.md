# 流处理器 {#stream-processors}

## 处理器 API {#processor-api}

处理器是一套基于内容流工作的二进制 API。

传入的内容流通过 `STDIN` 提供给二进制程序，流处理器需要把处理后的流输出到
`STDOUT`。如果遇到错误，错误必须通过 `STDERR` 返回，并以非零退出状态码退出。

可以通过 payload 向流处理器提供额外信息。payload 以 `protobuf.Any` 类型序列化，
可以包装任意类型的序列化数据结构。

在 Unix 系统上，如果存在 payload，会通过进程的 `fd 3` 提供。

在 Windows 系统上，如果存在 payload，会通过一个命名管道提供，管道路径由环境变量
`STREAM_PROCESSOR_PIPE` 的值给出。

## 配置 {#configuration}

要为 containerd 配置流处理器，需要在配置文件中添加相应条目。
`stream_processors` 字段是一个 map，因此用户可以把多个处理器串联起来，对内容流进行变换。

处理器字段：

* Key - 处理器的 ID，用于向该处理器传递特定的 payload。
* `accepts` - 该处理器能够处理的媒体类型。
* `returns` - 该处理器返回的媒体类型。
* `path` - 处理器二进制程序的路径。
* `args` - 传递给处理器二进制程序的参数。

```toml
version = 2

[stream_processors]
  [stream_processors."io.containerd.processor.v1.pigz"]
	accepts = ["application/vnd.docker.image.rootfs.diff.tar.gzip"]
	returns = "application/vnd.oci.image.layer.v1.tar"
	path = "unpigz"
	args = ["-d", "-c"]
```
