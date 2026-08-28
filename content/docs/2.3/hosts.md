
# Registry 配置 - 简介 {#registry-configuration---introduction}

containerd v1.5 为 `ctr` 客户端（面向管理员/开发者的 containerd 工具）、containerd 镜像服务客户端，以及
`kubectl`、`crictl` 等 CRI 客户端实现了全新的、额外的 registry host 配置支持。

对于这些客户端，配置 registry 的方式是在一个配置目录中为每个目标 registry host（可选地）指定一个 `hosts.toml` 文件。

> **注意**：该目录下的更新不需要重启 containerd daemon。

## Registry API 支持 {#registry-api-support}

所有配置的 registry host 都应当符合 [OCI Distribution 规范](https://github.com/opencontainers/distribution-spec)。
不符合规范或实现了非标准行为的 registry 不保证受支持，并且可能在不同版本之间意外失效。

当前支持的 OCI Distribution 版本：**[v1.0.0](https://github.com/opencontainers/distribution-spec/tree/v1.0.0)**

## 指定配置目录 {#specifying-the-configuration-directory}

### 在 CTR 中使用 host namespace 配置 {#using-host-namespace-configs-with-ctr}

通过 `ctr` 拉取容器镜像时，使用 `--hosts-dir` 选项告知 `ctr`
在指定路径下查找并使用 host 配置文件：
```
ctr images pull --hosts-dir "/etc/containerd/certs.d" myregistry.io:5000/image_name:tag
```

### CRI {#cri}

_用于指定 registry.mirrors 和 registry.configs 的旧版 CRI 配置方式已 **弃用**。_ 现在应当把 registry 的
`config_path` 指向存放 `hosts.toml` 文件的路径。

按如下方式修改 `config.toml`（默认位置：`/etc/containerd/config.toml`）：
+ 在 containerd 2.x 中
```toml
version = 3

[plugins."io.containerd.cri.v1.images".registry]
   config_path = "/etc/containerd/certs.d"
```
+ 在 containerd 1.x 中
```toml
version = 2

[plugins."io.containerd.grpc.v1.cri".registry]
   config_path = "/etc/containerd/certs.d"
```

## 对 Docker 证书文件模式的支持 {#support-for-dockers-certificate-file-pattern}

如果 host 目录中不存在 hosts.toml 配置，则会回退到按
[Docker 的证书文件模式](https://docs.docker.com/engine/reference/commandline/dockerd/#insecure-registries)
检查证书文件（".crt" 文件为 CA 证书，".cert"/".key" 文件为客户端证书）。

## Registry host namespace {#registry-host-namespace}

registry host 是容器镜像和制品的来源位置。这些 registry host 可以是本地的，也可以是远程的，通常通过
http/https 按照 [OCI distribution 规范](https://github.com/opencontainers/distribution-spec/blob/main/spec.md)
访问。registry mirror 不是 registry host，但这些 mirror 同样可以用于拉取内容。
registry host 通常以其互联网域名（即 registry host name）来指代。例如 docker.io、quay.io、gcr.io
和 ghcr.io。

就 containerd 的 registry 配置而言，registry host namespace 是由 registry host name（或 IP 地址）
以及可选的端口标识符所指定的、指向 `hosts.toml` 文件的路径。发起镜像拉取请求时，其格式
通常如下：
```
pull [registry_host_name|IP address][:port][/v2][/org_path]<image_name>[:tag|@DIGEST]
```

其中 registry host namespace 部分是 `[registry_host_name|IP address][:port]`。docker.io 的目录树
示例：

```shell
$ tree /etc/containerd/certs.d
/etc/containerd/certs.d
└── docker.io
    └── hosts.toml
```

可选地，当没有其他 namespace 匹配时，可以使用 `_default` registry host namespace 作为回退。

上面拉取请求格式中的 `/v2` 部分指的是 distribution api 的版本。如果拉取请求中未包含该部分，
则所有符合上述 distribution 规范的客户端都会默认添加 `/v2`。

如果配置的 host 与 registry host namespace 不同（例如某个 mirror），那么
containerd 会把 registry host namespace 作为名为 `ns` 的查询参数追加到请求中。

例如，从名为 `myregistry.io`、端口为 5000 的私有 registry 拉取 `image_name:tag_name` 时：
```
pull myregistry.io:5000/image_name:tag_name
```
该拉取会解析到 `https://myregistry.io:5000/v2/image_name/manifests/tag_name`。

同样的拉取在配置了 `mymirror.io` 这个 host 后，会解析到
`https://mymirror.io/v2/image_name/manifests/tag_name?ns=myregistry.io:5000`。

### Registry host 中的端口处理 {#port-handling-in-registry-host}

如果 registry host 包含端口（例如 `myregistry.io:5000`），containerd 会在 hosts 配置目录下
按以下顺序的 registry host namespace 中查找 `hosts.toml` 文件：

+ 在 Unix 上：

```
myregistry.io_5000_
myregistry.io:5000
_default
```

+ 在 Windows 上（其目录/文件名不支持 `:`）：

```
myregistry.io_5000_
myregistry.io5000
_default
```

## 指定 registry 凭据 {#specifying-registry-credentials}

### CTR {#ctr}

通过 `ctr` 执行镜像操作时，使用 --help 选项可以列出用于指定凭据的可用选项：
```
ctr i pull --help
...
OPTIONS:
   --skip-verify, -k                 skip SSL certificate validation
   --plain-http                      allow connections using plain HTTP
   --user value, -u value            user[:password] Registry user and password
   --refresh value                   refresh token for authorization server
   --hosts-dir value                 Custom hosts configuration directory
   --tlscacert value                 path to TLS root CA
   --tlscert value                   path to TLS client certificate
   --tlskey value                    path to TLS client key
   --http-dump                       dump all HTTP request/responses when interacting with container registry
   --http-trace                      enable HTTP tracing for registry interactions
   --snapshotter value               snapshotter name. Empty value stands for the default value. [$CONTAINERD_SNAPSHOTTER]
   --label value                     labels to attach to the image
   --platform value                  Pull content from a specific platform
   --all-platforms                   pull content and metadata from all platforms
   --all-metadata                    Pull metadata for all platforms
   --print-chainid                   Print the resulting image's chain ID
   --max-concurrent-downloads value  Set the max concurrent downloads for each pull (default: 0)
```

### CRI {#cri-1}

尽管用于指定 registry.mirrors 和 registry.configs 的旧版 CRI 配置方式已经弃用，仍然可以通过
[CRI 配置](https://github.com/containerd/containerd/blob/main/docs/cri/registry.md#configure-registry-credentials)
指定凭据。

此外，containerd CRI plugin 实现/支持通过 CRI 拉取镜像服务请求传入的认证参数。
例如，当 containerd 作为 `Kubernetes` 的容器运行时实现时，containerd CRI plugin 会接收
kubelet 从
[Kubernetes Image Pull Secrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
中取得并传来的认证凭据。

# Registry 配置 - 示例 {#registry-configuration---examples}

## Docker 的简单（默认）host 配置 {#simple-default-host-config-for-docker}

下面是一个默认 registry hosts 配置的简单示例。在 containerd 的 config.toml 中设置
`config_path = "/etc/containerd/certs.d"`。
在该配置路径下创建一棵目录树，其中包含名为 `docker.io` 的目录，代表要配置的 host namespace。
然后在 `docker.io` 中添加一个 `hosts.toml` 文件来配置该 host namespace。它看起来应该是这样：

```shell
$ tree /etc/containerd/certs.d
/etc/containerd/certs.d
└── docker.io
    └── hosts.toml

$ cat /etc/containerd/certs.d/docker.io/hosts.toml
server = "https://docker.io"

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
```

## 为 Docker 设置本地 mirror {#setup-a-local-mirror-for-docker}

```shell
server = "https://registry-1.docker.io"    # Exclude this to not use upstream

[host."https://public-mirror.example.com"]
  capabilities = ["pull"]                  # Requires less trust, won't resolve tag to digest from this host
[host."https://docker-mirror.internal"]
  capabilities = ["pull", "resolve"]
  ca = "docker-mirror.crt"                 # Or absolute path /etc/containerd/certs.d/docker.io/docker-mirror.crt
```

## 为所有 registry 设置默认 mirror {#setup-default-mirror-for-all-registries}

这是一个不论目标 registry 是哪个都使用 mirror 的示例。
在所有已定义的 host 都尝试过之后，会自动使用上游 registry。

```shell
$ tree /etc/containerd/certs.d
/etc/containerd/certs.d
└── _default
    └── hosts.toml

$ cat /etc/containerd/certs.d/_default/hosts.toml
[host."https://registry.example.com"]
  capabilities = ["pull", "resolve"]
```

如果希望确保*只*使用 mirror、不去访问上游，请把该 mirror 设置为 `server` 而不是 host。
如果想先使用其他 mirror，仍然可以额外指定 host。

```shell
$ cat /etc/containerd/certs.d/_default/hosts.toml
server = "https://registry.example.com"
```

## 跳过 TLS 校验示例 {#bypass-tls-verification-example}

要跳过对位于 `192.168.31.250:5000` 的私有 registry 的 TLS 校验：

在路径 "/etc/containerd/certs.d/docker.io/hosts.toml" 创建目录和 `hosts.toml` 文本，内容如下或类似：

```toml
server = "https://registry-1.docker.io"

[host."http://192.168.31.250:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
```

# hosts.toml 内容说明 - 详解 {#hoststoml-content-description---detail}

对于 registry `config_path` 下的每个 registry host namespace 目录，都可以包含一个
`hosts.toml` 配置文件。以下根级 toml 字段适用于该 registry host namespace：

**注意**：`hosts.toml` 文件中指定的所有路径既可以是绝对路径，也可以是相对于
`hosts.toml` 文件的相对路径。

## server 字段 {#server-field}

`server` 指定该 registry host namespace 的默认服务器。

当指定了 `host` 时，会按列出的顺序优先尝试这些 host。
如果所有 `host` 都尝试过了，则使用 `server` 作为回退。

如果没有指定 `server`，则会自动使用镜像的 registry host namespace。

```toml
server = "https://docker.io"
```

## capabilities 字段 {#capabilities-field}

`capabilities` 是一个可选设置，用于指定某个 host 能够执行哪些操作。只需包含适用的取值。
```toml
capabilities =  ["pull", "resolve", "push"]
```

capabilities（即 Host capabilities）表示该 registry host 的能力。
它同时也表示可以信任该 registry host 执行的操作集合。

例如，push 是一种只应在上游源上执行的能力，而不应在 mirror 上执行。

Resolve（把名称转换为 digest 的过程）
必须被视为受信任的操作，只能由受信任的 host 执行
（更理想的做法是由能够证明该映射来源的安全流程来执行）。

绝不应信任公共 mirror 执行 resolve 操作。

| Registry 类型    | Pull | Resolve | Push |
|------------------|------|---------|------|
| 公共 Registry    | 是   | 是      | 是   |
| 私有 Registry    | 是   | 是      | 是   |
| 公共 Mirror      | 是   | 否      | 否   |
| 私有 Mirror      | 是   | 是      | 否   |

## ca 字段 {#ca-field}

`ca`（Certificate Authority Certification）可以设置为一个路径或一个路径数组，
每个路径都指向一个用于在该 registry namespace 中进行认证的 ca 文件。
```toml
ca = "/etc/certs/mirror.pem"
```
或
```toml
ca = ["/etc/certs/test-1-ca.pem", "/etc/certs/special.pem"]
```

## client 字段 {#client-field}

`client` 证书按如下方式配置

一个路径：
```toml
client = "/etc/certs/client.pem"
```

一个路径数组：
```toml
client = ["/etc/certs/client-1.pem", "/etc/certs/client-2.pem"]
```

一个路径对数组：
```toml
client = [["/etc/certs/client.cert", "/etc/certs/client.key"],["/etc/certs/client.pem", ""]]
```

## skip_verify 字段 {#skip_verify-field}

`skip_verify` 设置为 `true` 时会跳过对 registry 证书链和主机名的校验。
这只应用于测试，或与其他验证连接的方式配合使用。（默认为 `false`）

```toml
skip_verify = false
```

## header 字段（toml 表格式）{#header-fields-in-the-toml-table-format}

`[header]` 包含若干个键，每个键的值是一个字符串或

一个字符串数组，如下所示：
```toml
[header]
  x-custom-1 = "custom header"
```

或
```toml
[header]
  x-custom-1 = ["custom header part a","part b"]
```

或
```toml
[header]
  x-custom-1 = "custom header"
  x-custom-1-2 = "another custom header"
```

## override_path 字段 {#override_path-field}

`override_path` 用于表明该 host 的 API 根端点是由 URL 路径定义的，
而不是由 API 规范定义的。它可用于缺少 `/v2` 前缀的、不符合规范的 OCI registry。
（默认为 `false`）

```toml
override_path = true
```

## dial_timeout 字段 {#dial_timeout-field}

`dial_timeout` 指定一次连接尝试允许完成的最长时间。
较短的超时有助于在 mirror 不可达时减少回退到原始 registry 的延迟。
（默认为 `30s`）

```
dial_timeout = "1s"
```

## host 字段（toml 表格式）{#host-fields-in-the-toml-table-format}

`hosts.toml` 配置中的 `[host]."https://namespace"` 和 `[host]."http://namespace"` 条目是
用来代替默认 registry host namespace 的 registry namespace。这些 host 有时被称为 mirror，
因为它们可能包含你试图从默认 registry 获取的容器镜像和制品的副本。每个
`host`/`mirror` namespace 的配置方式与默认 registry namespace 大致相同。值得注意的是，
`host` 描述中不指定 `server`，因为它已经在 namespace 中指定了。下面是为该 registry host
namespace 配置 host mirror namespace 的几个粗略示例：

```toml
[host."https://mirror.registry"]
  capabilities = ["pull"]
  ca = "/etc/certs/mirror.pem"
  skip_verify = false
  [host."https://mirror.registry".header]
    x-custom-2 = ["value1", "value2"]

[host."https://mirror-bak.registry/us"]
  capabilities = ["pull"]
  skip_verify = true

[host."http://mirror.registry"]
  capabilities = ["pull"]

[host."https://test-1.registry"]
  capabilities = ["pull", "resolve", "push"]
  ca = ["/etc/certs/test-1-ca.pem", "/etc/certs/special.pem"]
  client = [["/etc/certs/client.cert", "/etc/certs/client.key"],["/etc/certs/client.pem", ""]]

[host."https://test-2.registry"]
  client = "/etc/certs/client.pem"

[host."https://test-3.registry"]
  client = ["/etc/certs/client-1.pem", "/etc/certs/client-2.pem"]

[host."https://non-compliant-mirror.registry/v2/upstream"]
  capabilities = ["pull"]
  override_path = true
```

**注意**：hosts.toml 文件中的 host mirror namespace 不支持递归定义。
因此下面的写法是不允许/不支持的：

```toml
[host."http://mirror.registry"]
  capabilities = ["pull"]
  [host."http://double-mirror.registry"]
    capabilities = ["pull"]
```
