containerd 的托管 opt 目录为用户提供了一种方式，可以利用已有的分发基础设施来安装 containerd 的依赖。

随着 runtime v2 的出现以及新 shim 的不断构建，把各种 shim 或 runtime 依赖下载到机器上成为一项挑战。

containerd 的托管 `/opt` 目录允许用户创建提供这些依赖的 image，并通过 containerd 客户端 API 把它们安装到系统上。

配置：

*默认值：* `/opt/containerd`

*containerd 配置：*
```toml
version = 2

[plugins."io.containerd.internal.v1.opt"]
	path = "/opt/mypath"

```

用法：

*代码：*

```go
image, err := client.Pull(ctx, "docker.io/crosbymichael/runc:latest")
client.Install(ctx, image)
```

选项：

```go
// WithInstallLibs installs libs from the image
func WithInstallLibs(c *InstallConfig) {
}

// WithInstallReplace will replace existing files
func WithInstallReplace(c *InstallConfig) {
}
```

*ctr：*

```bash
ctr content fetch docker.io/crosbymichael/runc:latest
ctr install docker.io/crosbymichael/runc:latest
```

你可以通过标准的 image 命令来管理版本并查看正在运行的内容。

Image：

这些 image 必须尽量小，并且只包含二进制文件，必要时才包含库文件。

```Dockerfile
FROM scratch
Add runc /bin/runc
```

默认情况下，containerd 只会提取 image 中 `/bin` 下的文件，可以通过 Opts 来替换文件或安装 `libs/`。
不过我们推荐这些二进制文件采用静态链接，以减少链接依赖。

这段代码添加了一个服务来管理 `/opt/containerd` 目录，并通过 introspection 服务把该路径提供给调用方。

如何测试：

从你的系统中删除 runc。

```bash
> sudo ctr run --rm  docker.io/library/redis:alpine redis
ctr: OCI runtime create failed: unable to retrieve OCI runtime error (open /run/containerd/io.containerd.runtime.v1.linux/default/redis/log.json: no such file or directory): exec: "runc": executable file not found in $PATH: unknown

> sudo ctr content fetch docker.io/crosbymichael/runc:latest
> sudo ctr  install docker.io/crosbymichael/runc:latest

> sudo ctr run --rm  docker.io/library/redis:alpine redis
1:C 01 Aug 15:59:52.864 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
1:C 01 Aug 15:59:52.864 # Redis version=4.0.10, bits=64, commit=00000000, modified=0, pid=1, just started
1:C 01 Aug 15:59:52.864 # Warning: no config file specified, using the default config. In order to specify a config file use redis-server /path/to/redis.conf
1:M 01 Aug 15:59:52.866 # You requested maxclients of 10000 requiring at least 10032 max file descriptors.
1:M 01 Aug 15:59:52.866 # Server can't set maximum open files to 10032 because of OS error: Operation not permitted.
1:M 01 Aug 15:59:52.866 # Current maximum open files is 1024. maxclients has been reduced to 992 to compensate for low ulimit. If you need higher maxclients increase 'ulimit -n'.
1:M 01 Aug 15:59:52.870 * Running mode=standalone, port=6379.
1:M 01 Aug 15:59:52.870 # WARNING: The TCP backlog setting of 511 cannot be enforced because /proc/sys/net/core/somaxconn is set to the lower value of 128.
1:M 01 Aug 15:59:52.870 # Server initialized
1:M 01 Aug 15:59:52.870 # WARNING overcommit_memory is set to 0! Background save may fail under low memory condition. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.
1:M 01 Aug 15:59:52.870 # WARNING you have Transparent Huge Pages (THP) support enabled in your kernel. This will create latency and memory usage issues with Redis. To fix this issue run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as root, and add it to your /etc/rc.local in order to retain the setting after a reboot. Redis must be restarted after THP is disabled.
1:M 01 Aug 15:59:52.870 * Ready to accept connections
^C1:signal-handler (1533139193) Received SIGINT scheduling shutdown...
1:M 01 Aug 15:59:53.472 # User requested shutdown...
1:M 01 Aug 15:59:53.472 * Saving the final RDB snapshot before exiting.
1:M 01 Aug 15:59:53.484 * DB saved on disk
1:M 01 Aug 15:59:53.484 # Redis is now ready to exit, bye bye...
```
Windows 环境：

```Dockerfile
FROM mcr.microsoft.com/windows/nanoserver:1809
ADD runhcs.exe /bin/runhcs.exe
```

```powershell
> ctr content fetch docker.io/ameyagawde/runhcs:1809 #An example image, not supported by containerd
> ctr install docker.io/ameyagawde/runhcs:1809
```
`/opt/containerd` 在 Windows 上的等价路径是 `$env:ProgramData\containerd\root\opt`
