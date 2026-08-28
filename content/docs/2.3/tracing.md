# 链路追踪 {#tracing}

containerd 从 v1.6.0 起支持 OpenTelemetry 链路追踪。
目前追踪只覆盖 gRPC 调用。

## 从 containerd daemon 发送 trace {#sending-traces-from-containerd-daemon}

在 containerd daemon 的进程空间内配置
[OpenTelemetry exporter 环境变量](https://opentelemetry.io/docs/specs/otel/protocol/exporter/)，
即可让 daemon 把 trace 发送到采集端点。

支持以下选项。

- `endpoint`：接收 [OpenTelemetry Protocol](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.8.0/specification/protocol/otlp.md) 的服务器地址。
- `protocol`：OpenTelemetry 支持多种协议。
  默认值为 "http/protobuf"，同时也支持 "grpc"。
- `insecure`：当协议为 "grpc" 时禁用传输层安全。默认为 false。
  "http/protobuf" 始终使用 endpoint 提供的 schema，此设置的取值会被忽略。

trace 的采样率和服务名可以通过设置
[OpenTelemetry 环境变量](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)来配置。

例如，如果以 systemd 服务方式运行 containerd，把环境变量添加到该服务中：

```text
[Service]
Environment="OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318"
Environment="OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf"
Environment="OTEL_SERVICE_NAME=containerd"
Environment="OTEL_TRACES_SAMPLER=traceidratio"
Environment="OTEL_TRACES_SAMPLER_ARG=1.0"
```

或者如果从命令行运行 containerd，在启动 daemon 之前设置环境变量：

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_SERVICE_NAME="containerd"
export OTEL_TRACES_SAMPLER="traceidratio"
export OTEL_TRACES_SAMPLER_ARG=1.0
```

## 从 containerd 客户端发送 trace {#sending-traces-from-containerd-client}

通过配置底层的 gRPC 客户端，containerd 的 Go 客户端可以把 trace 发送到
OpenTelemetry 端点。

注意，Go 客户端的方法与 gRPC 调用并非一一对应。单次方法调用可能会发出多个
gRPC 调用。

```go
func clientWithTrace() error {
	exp, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint("localhost:4318"),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return err
	}

	res, err := resource.New(ctx, resource.WithAttributes(
		semconv.ServiceNameKey.String("CLIENT NAME"),
	))
	if err != nil {
		return err
	}

	provider := trace.NewTracerProvider(
		trace.WithSampler(trace.AlwaysSample()),
		trace.WithSpanProcessor(trace.NewSimpleSpanProcessor(exp)),
		trace.WithResource(res),
	)
	otel.SetTracerProvider(provider)
	otel.SetTextMapPropagator(propagation.TraceContext{})

    ...

    dialOpts := []grpc.DialOption{
        grpc.WithTransportCredentials(insecure.NewCredentials()),
        grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
    }
    client, ctx, cancel, err := commands.NewClient(context, containerd.WithDialOpts(dialOpts))
    if err != nil {
        return err
    }
    defer cancel()

    ctx, span := tracing.StartSpan(ctx, "OPERATION NAME")
    defer span.End()
    ...
}
```
## 手动埋点 {#manual-instrumentation}

OpenTelemetry 提供了各语言专用的 [API](https://pkg.go.dev/go.opentelemetry.io/otel) 库，用于为自动埋点未覆盖到的应用部分添加埋点。

在 Containerd 中，`tracing/tracing.go` 里定义了一个薄封装库，它提供了额外的功能，让手动埋点时使用 OpenTelemetry API 更加方便。

### 创建一个新的 span {#creating-a-new-span}

要创建新的 span，使用 `tracing.StartSpan()` 方法。你应当已经通过配置 `io.containerd.tracing.processor.v1.otlp` plugin 设置了全局的 TracerProvider，否则这里只会创建一个 NoopSpan{} 实例。

```go
func CreateContainer(ctx context.Context, r *runtime.CreateContainerRequest) error {
    ctx, span := tracing.StartSpan(ctx,
        tracing.Name(criSpanPrefix, "CreateContainer") // name of the span
        tracing.WithAttribute("sandbox.id",r.GetPodSandboxId(), //attributes to be added to the span
        )
	defer span.End() // end the span once the function returns
    ...
}
```
在工作流结束时调用 `Span.End()` 将该 span 标记为完成。上面的例子中，我们使用 'defer' 来确保 span 被正确关闭并记录其持续时间。

### 为 span 添加属性 {#adding-attributes-to-a-span}

你可以使用 `Span.SetAttributes()` 为 span 添加额外的属性。属性既可以在创建 span 时添加（把 `tracing.WithAttribute()` 传给 tracing.StartSpan()），也可以在 span 生命周期内、完成之前的任意时刻添加。

```go
func CreateContainer(ctx context.Context, r *runtime.CreateContainerRequest) error {
    ctx, span := tracing.StartSpan(ctx,
        tracing.Name(criSpanPrefix, "CreateContainer")
        tracing.WithAttribute("sandbox.id",r.GetPodSandboxId(),
        )
	defer span.End()
    ...
    containerId := util.GenerateID()
    containerName := makeContainerName(metadata, sandboxConfig.GetMetadata())

    //Add new attributes to the existing span
    span.SetAttributes(
		tracing.Attribute("container.id", containerId),
		tracing.Attribute("container.name", containerName),
	)
    ...
}
```
### 为 span 添加事件 {#adding-an-event-to-a-span}
使用 `Span.AddEvent()` 为已有的 span 添加事件。[span 事件](https://opentelemetry.io/docs/instrumentation/go/manual/#events)是 span 内部的某个具体发生的事情，比如一个操作的完成或者一个错误的出现。span 事件可以用来为该 span 所代表的操作提供额外信息，并可用于调试或性能分析。

下面的例子展示了如何为 span 添加事件来标记一次 NRI hook 的执行。
```go
func CreateContainer(ctx context.Context, r *runtime.CreateContainerRequest) error {
    span := tracing.SpanFromContext(ctx) // get the current span from context
    ...
    ...
    if c.nri.isEnabled() {
        // Add an event to mark start of an NRI api call
        span.AddEvent("start NRI postCreateContainer request")

        err = c.nri.postCreateContainer(ctx, &sandbox, &container)
        if err != nil {
			log.G(ctx).WithError(err).Errorf("NRI post-create notification failed")
		}

        // Add an event to mark completion of the request
        span.AddEvent("finished NRI postCreateContainer request")
	}
    ...
    // You can also add additional attributes to an event
    span.AddEvent("container created",
		tracing.Attribute("container.create.duration", time.Since(start).String()),
	)

	return &runtime.CreateContainerResponse{ContainerId: id}, nil
}
```

### 在 span 中记录错误 {#recording-errors-in-a-span}
你可以使用 `Span.RecordError()` 把一个错误记录为该 span 的异常事件。`RecordError` 函数不会自动把 span 的状态设置为 Error，因此如果你希望这个 span 被视为追踪了一次失败的操作，应当使用 `Span.SetStatus(err error)` 来记录错误并同时把 span 状态设置为 Error。

记录一个错误：
```go
span := tracing.SpanFromContext(ctx)
defer span.End()
...
err = c.nri.postCreateContainer(ctx, &sandbox, &container)
if err != nil {
    span.RecordError(err) //record error
	log.G(ctx).WithError(err).Errorf("NRI post-create notification failed")
}
```

记录错误并同时设置 span 状态：
```go
span := tracing.SpanFromContext(ctx)
defer span.End()
...
err = c.nri.postCreateContainer(ctx, &sandbox, &container)
if err != nil {
    span.SetStatus(err) //record error and set status
	log.G(ctx).WithError(err).Errorf("NRI post-create notification failed")
}
```

## 命名约定 {#naming-convention}

OpenTelemetry 为 trace、metric 等不同类型的遥测数据维护了一套推荐的[语义约定](https://opentelemetry.io/docs/reference/specification/overview/#semantic-conventions)，帮助 OpenTelemetry 库和工具的使用者以一致且可互操作的方式采集和使用遥测数据。

Containerd 中手动埋点的 span 遵循为 [Span](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/) 和[属性](https://opentelemetry.io/docs/reference/specification/common/attribute-naming/)定义的约定

### Span 名称 {#span-names}
* 使用点号分隔的写法。
* Span 名称可以包含包的相对路径。
* Span 名称应当包含一个能代表执行该操作的具体组件或服务的名字。
* 例如："pkg.cri.sbserver.CreateContainer"
   * "pkg.cri.sbserver" - 包的相对路径
   * "CreateContainer" - 描述被追踪的操作

### 属性名称 {#attribute-names}
* 小写。
* 使用点号分隔的写法。
* 采用基于命名空间的表示方式。
* 例如："http.method.get" , http.method.post"。
   * "http" - 表示该属性的大类。
   * "method" - 该属性的具体方面或性质。
   * "get" - 额外的细节或上下文。
