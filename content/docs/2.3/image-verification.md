# Image 校验 {#image-verification}

下面介绍默认的 “bindir” `ImageVerifier` plugin 实现。

要启用 image 校验，在 containerd 配置中添加类似下面的配置段：

```yaml
[plugins]
  [plugins."io.containerd.image-verifier.v1.bindir"]
    bin_dir = "/opt/containerd/image-verifier/bin"
    max_verifiers = 10
    per_verifier_timeout = "10s"
```

如果 `bin_dir` 存在，其中的所有文件都必须是符合下述 API 的校验器可执行文件。

## Image 校验器二进制 API {#image-verifier-binary-api}

### CLI 参数 {#cli-arguments}

- `-name`：可能被拉取的 image 的给定引用。
- `-digest`：可能被拉取的 image 解析出的 digest。
- `-stdin-media-type`：传给标准输入的 JSON 数据的 media type。

### 标准输入 {#standard-input}

一段 JSON 编码的载荷会传给校验器二进制的标准输入。该载荷的 media type 由
`-stdin-media-type` CLI 参数指定，并且可能在 containerd 的未来版本中变化。目前该
载荷的 media type 为 `application/vnd.oci.descriptor.v1+json`，表示可能被拉取的
image 的 OCI Content Descriptor。更多细节参见
[OCI 规范](https://github.com/opencontainers/image-spec/blob/main/descriptor.md)。

### Image 拉取裁决 {#image-pull-judgement}

把 image 拉取裁决的理由打印到标准输出。

返回退出码 0 表示允许拉取该 image，返回任何其他退出码则阻止拉取该 image。

## Image 校验器调用方约定 {#image-verifier-caller-contract}

- 如果 `bin_dir` 不存在或其中没有文件，image 校验器不会阻止 image 拉取。
- 只有当被调用的所有校验器都返回 “ok” 裁决（以状态码 0 退出）时，image 才会被拉取。换句话说，image 拉取裁决是用 `AND` 运算符组合的。
- 如果任何校验器超过 `per_verifier_timeout` 或执行失败，校验会以错误告终，并返回 `nil` 裁决。
- 如果 `max_verifiers < 0`，则对被调用的 image 校验器数量不作限制。
- 如果 `max_verifiers >= 0`，则对被调用的 image 校验器数量施加限制。`bin_dir` 中的条目按名称做字典序排序，前 `n = max_verifiers` 个校验器会被调用，其余的会被跳过。
- 校验器二进制的执行顺序没有保证。
- 校验器二进制的标准错误输出由 containerd 以 debug 级别记录日志，并可能被截断。
- 校验器二进制的标准输出（裁决的 “理由”）可能被截断。
- 校验器二进制使用的系统资源目前计入 containerd 自身的 cgroup 并受其约束，但这一点未来可能改变。
