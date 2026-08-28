CRI 插件测试指南 {#cri-plugin-testing-guide}
========================
本文假设你已经搭建好开发环境（go、git、`github.com/containerd/containerd` 仓库等）。

在提交 pull request 之前，至少应确保你的改动通过了代码校验、单元测试、集成测试和 CRI 验证测试。

## 构建 {#build}
按照 [building](../../BUILDING.md) 说明操作。

## CRI 集成测试 {#cri-integration-test}
* 运行全部 CRI 集成测试：
```bash
make cri-integration
```
* 运行指定的 CRI 集成测试：用 `FOCUS` 参数指定测试用例。
```bash
# run CRI integration tests that match the test string <TEST_NAME>
FOCUS=<TEST_NAME> make cri-integration
```
示例：
```bash
FOCUS=TestContainerListStats make cri-integration
```
## CRI 验证测试 {#cri-validation-test}
[CRI 验证测试](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/validation.md)是一个测试框架，用于验证某个容器运行时接口（CRI）实现（例如带 `cri` 插件的 containerd）是否满足管理 pod sandbox、容器、image 等所需的全部要求。

借助 CRI 验证测试，无需搭建 Kubernetes 组件或运行 Kubernetes 端到端测试，就可以验证 `containerd` 的 CRI 一致性。
* [安装依赖](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/validation.md#install)。
* 运行前面构建好的、内置 `cri` 插件的 containerd：
```bash
containerd -l debug
```
* 运行 CRI [验证](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/validation.md#run)测试。

关于 CRI 验证测试的[更多信息](https://github.com/kubernetes-sigs/cri-tools)。
## 节点 E2E 测试 {#node-e2e-test}
[节点 e2e 测试](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-node/e2e-node-tests.md)是一个测试框架，用于测试 Kubernetes 节点级别的功能，例如管理 pod、挂载卷等。它会启动一个包含 Kubelet 和少量其他最小依赖的本地集群，并针对该本地集群运行节点功能测试。

目前 e2e-node 测试通过 GitHub 上的 Pull Request 评论触发。
在 pull request 中评论 "/test all"，可以列出通过 prow bot 与托管在 GCE 上的 Kubernetes 测试服务集成的所有测试选项。
输入 `/test pull-containerd-node-e2e` 会针对你的 pull request 提交发起一次节点 e2e 测试。

关于 Kubernetes 节点 e2e 测试的[更多信息](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-node/e2e-node-tests.md)。
