# otel_mqtt_client

OpenTelemetry instrumentation for
[`package:mqtt_client`](https://pub.dev/packages/mqtt_client).

```dart
import 'package:otel_mqtt_client/otel_mqtt_client.dart';

await tracedMqttCallAsync<void>(
  operation: 'connect',
  invoke: () => client.connect(),
);

tracedMqttCall<int>(
  operation: 'publish',
  topic: 'sensors/temp',
  invoke: () =>
      client.publishMessage('sensors/temp', MqttQos.atMostOnce, payload),
);
```

Each call emits a CLIENT span with:
- `messaging.system = mqtt`
- `messaging.operation = connect` / `publish` / `subscribe` / …
- `messaging.destination.name = <topic>` (when applicable)

`mqtt_client` has a mix of async (`connect`, `disconnect`) and
sync (`publishMessage`, `subscribe`) APIs — use
`tracedMqttCallAsync` for the former and `tracedMqttCall` for the
latter.

Suppression: `runWithoutMqttInstrumentationAsync`.

## License

Apache 2.0
