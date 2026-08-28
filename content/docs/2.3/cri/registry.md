# 配置镜像 Registry {#configure-image-registry}

本文档描述了如何为 `containerd` 配置镜像 registry，以配合 `cri` plugin 使用。

> **_注意：_** 本文档中此前描述的 registry.mirrors 和 registry.configs
> 已被弃用。如 [cri 配置](./config.md#registry-configuration) 中所述，
> 现在应当使用以下配置
+ 在 containerd 2.x 中
```toml
[plugins."io.containerd.cri.v1.images".registry]
   config_path = "/etc/containerd/certs.d"
```
+ 在 containerd 1.x 中
```toml
[plugins."io.containerd.grpc.v1.cri".registry]
   config_path = "/etc/containerd/certs.d"
```

如果没有设置任何 registry 相关选项，`config_path` 将默认为
`/etc/containerd/certs.d:/etc/docker/certs.d`，这样可以兼容
[docker 添加 registry 配置的方式](https://docs.docker.com/registry/insecure/#use-self-signed-certificates)。

## 配置 Registry 凭据 {#configure-registry-credentials}

> **_注意：_** registry.configs.*.auth 已被弃用，并且不会有在 host 配置文件中
> 存放未加密 secret 的等价方式。不过，在有合适的 secret 管理替代方案以 plugin 形式
> 提供之前，它不会被移除。它在 1.x 发布版本中仍然受支持，包括 1.6 LTS 版本。

要为特定 registry 配置凭据，请按如下方式创建/修改
`/etc/containerd/config.toml`：

+ 在 containerd 2.x 中
```toml
# explicitly use v3 config format
version = 3

# The registry host has to be a domain name or IP. Port number is also
# needed if the default HTTPS or HTTP port is not used.
[plugins."io.containerd.cri.v1.images".registry.configs."gcr.io".auth]
  username = ""
  password = ""
  auth = ""
  identitytoken = ""
```
+ 在 containerd 1.x 中
```toml
# explicitly use v2 config format
version = 2

# The registry host has to be a domain name or IP. Port number is also
# needed if the default HTTPS or HTTP port is not used.
[plugins."io.containerd.grpc.v1.cri".registry.configs."gcr.io".auth]
  username = ""
  password = ""
  auth = ""
  identitytoken = ""
```

每个字段的含义与 `.docker/config.json` 中对应字段相同。

请注意，通过 CRI 传入的 auth 配置优先级高于此配置。
只有当 Kubernetes 没有通过 CRI 指定 auth 配置时，才会使用此配置中的 registry 凭据。

修改此配置后，需要重启 `containerd` 服务。

### 配置 Registry 凭据示例 —— 使用服务账号密钥认证的 GCR {#configure-registry-credentials-example---gcr-with-service-account-key-authentication}

如果你还没有配置好 Google Container Registry (GCR)，需要执行以下步骤：

* 创建 Google Cloud Platform (GCP) 账号和项目（如果尚未创建，参见 [GCP getting started](https://cloud.google.com/gcp/getting-started)）
* 为你的项目启用 GCR（参见 [Quickstart for Container Registry](https://cloud.google.com/container-registry/docs/quickstart)）
* 用于 GCR 认证：创建[服务账号和 JSON 密钥](https://cloud.google.com/container-registry/docs/advanced-authentication#json-key)
* 需要从 GCP 控制台把 JSON 密钥文件下载到你的系统上
* 用于访问 GCR 存储：把服务账号添加到 GCR 存储桶，并授予 storage admin 访问权限（参见 [Granting permissions](https://cloud.google.com/container-registry/docs/access-control#grant-bucket)）

有关上述步骤的详细信息，请参阅 [Pushing and pulling images](https://cloud.google.com/container-registry/docs/pushing-and-pulling)。

> 注意：JSON 密钥文件是多行文件，在文件之外把其内容当作密钥使用会比较麻烦。把该文件生成单行格式的输出会很有帮助。一种做法是使用 `jq` 工具：`jq -c . key.json`

在把 GCR 接入 containerd 之前，最好先确认你可以在终端中通过 GCR 认证并访问其存储。可以通过登录 GCR 并
向其推送一个镜像来验证：

```console
docker login -u _json_key -p "$(cat key.json)" gcr.io

docker pull busybox

docker tag busybox gcr.io/your-gcp-project-id/busybox

docker push gcr.io/your-gcp-project-id/busybox

docker logout gcr.io
```

确认可以从终端访问 GCR 之后，就可以试用 containerd 了。

编辑 containerd 配置（默认位置为 `/etc/containerd/config.toml`），
为 `gcr.io` 域名的镜像拉取请求添加你的 JSON 密钥：
+ 在 containerd 2.x 中
```toml
version = 3

[plugins."io.containerd.cri.v1.images".registry]
  [plugins."io.containerd.cri.v1.images".registry.mirrors]
    [plugins."io.containerd.cri.v1.images".registry.mirrors."docker.io"]
      endpoint = ["https://registry-1.docker.io"]
    [plugins."io.containerd.cri.v1.images".registry.mirrors."gcr.io"]
      endpoint = ["https://gcr.io"]
  [plugins."io.containerd.cri.v1.images".registry.configs]
    [plugins."io.containerd.cri.v1.images".registry.configs."gcr.io".auth]
      username = "_json_key"
      password = 'paste output from jq'
```
+ 在 containerd 1.x 中
```toml
version = 2

[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["https://registry-1.docker.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
      endpoint = ["https://gcr.io"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."gcr.io".auth]
      username = "_json_key"
      password = 'paste output from jq'
```

> 注意：`username` 取值为 `_json_key` 表示将使用 JSON 密钥认证。

重启 containerd：

```console
service containerd restart
```

使用 `crictl` 从你的 GCR 拉取镜像：

```console
$ sudo crictl pull gcr.io/your-gcp-project-id/busybox

DEBU[0000] get image connection
DEBU[0000] connect using endpoint 'unix:///run/containerd/containerd.sock' with '3s' timeout
DEBU[0000] connected successfully using endpoint: unix:///run/containerd/containerd.sock
DEBU[0000] PullImageRequest: &PullImageRequest{Image:&ImageSpec{Image:gcr.io/your-gcr-instance-id/busybox,},Auth:nil,SandboxConfig:nil,}
DEBU[0001] PullImageResponse: &PullImageResponse{ImageRef:sha256:78096d0a54788961ca68393e5f8038704b97d8af374249dc5c8faec1b8045e42,}
Image is up to date for sha256:78096d0a54788961ca68393e5f8038704b97d8af374249dc5c8faec1b8045e42
```

---

注意：本文档中使用的配置语法是 version 2，这是 `containerd` 1.3 起推荐的格式。此前的配置格式可参考 [https://github.com/containerd/cri/blob/release/1.2/docs/registry.md](https://github.com/containerd/cri/blob/release/1.2/docs/registry.md)。
