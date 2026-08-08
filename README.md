# otel_mqtt_client

OpenTelemetry instrumentation for
[`package:mqtt_client`](https://pub.dev/packages/mqtt_client).

```dart
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:otel_mqtt_client/otel_mqtt_client.dart';

final client = MqttServerClient('broker.example.com', 'my-client');

// Swap connect -> tracedConnect etc. — signatures mirror
// mqtt_client exactly.
await client.tracedConnect();
client.tracedSubscribe('sensors/temp', MqttQos.atMostOnce);
client.tracedPublishMessage('sensors/temp', MqttQos.atMostOnce, payload);
client.tracedDisconnect();
```

Each call emits a CLIENT span named `mqtt <operation> [<topic>]` with:
- `messaging.system = mqtt`
- `messaging.operation.name = connect` / `publish` / `subscribe` / …
- `messaging.operation.type = send` (publish; only where a registry
  value applies)
- `messaging.destination.name = <topic>` (when applicable)

Failures record the exception, set `error.type`, and flip the span
to `Error` before rethrowing.

For call sites the extension does not cover, the generic helpers
take any closure: `tracedMqttCallAsync` for async operations
(`connect`, `disconnect`) and `tracedMqttCall` for sync ones
(`publishMessage`, `subscribe`, `unsubscribe`).

Suppression: `runWithoutMqttInstrumentation` /
`runWithoutMqttInstrumentationAsync` silence spans for a scope.

Note: `package:mqtt_client` speaks MQTT 3.1/3.1.1, which has no
message properties, so there is no W3C trace-context propagation
surface; spans carry attributes only and trace context does not
cross the broker.

## License

Apache 2.0
