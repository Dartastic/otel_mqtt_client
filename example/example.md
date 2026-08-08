# otel_mqtt_client example

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:otel_mqtt_client/otel_mqtt_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

Future<void> main() async {
  // 1. Bring up OTel first so spans have somewhere to go.
  await OTel.initialize(serviceName: 'mqtt-demo');

  final client = MqttServerClient('test.mosquitto.org', 'otel-demo');

  // 2. Swap connect -> tracedConnect etc.; the signatures mirror
  //    mqtt_client exactly, so nothing else changes.

  // Span: `mqtt connect` (messaging.system=mqtt,
  //        messaging.operation.name=connect)
  await client.tracedConnect();

  // Span: `mqtt subscribe sensors/temp`
  client.tracedSubscribe('sensors/temp', MqttQos.atMostOnce);

  // Span: `mqtt publish sensors/temp` with
  //   messaging.operation.type=send and
  //   messaging.destination.name=sensors/temp
  final payload = typed.Uint8Buffer()
    ..addAll('21.5'.codeUnits);
  client.tracedPublishMessage(
    'sensors/temp',
    MqttQos.atMostOnce,
    payload,
  );

  // Span: `mqtt unsubscribe sensors/temp`
  client.tracedUnsubscribe('sensors/temp');

  // Span: `mqtt disconnect`
  client.tracedDisconnect();

  // Need a quiet window (e.g. a bulk backfill publish loop)?
  runWithoutMqttInstrumentation(() {
    // calls in here emit no spans
  });

  await OTel.shutdown();
}
```

## Trace shape

```
mqtt connect
mqtt subscribe sensors/temp
mqtt publish sensors/temp   (messaging.operation.type=send)
mqtt unsubscribe sensors/temp
mqtt disconnect
```

Failures (broker unreachable, publish while disconnected, invalid
topic) flip the span to `Error`, record the exception, and set
`error.type` before rethrowing.

Note: `package:mqtt_client` speaks MQTT 3.1/3.1.1, which has no
message properties, so there is no W3C trace-context propagation
surface; spans carry attributes only and trace context does not
cross the broker.
