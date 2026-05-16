// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'mqtt_suppression.dart';

const _tracerName = 'otel_mqtt_client';
const _messagingSystem = 'mqtt';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Generic async helper. Opens a CLIENT span around an MQTT
/// operation.
Future<R> tracedMqttCallAsync<R>({
  required String operation,
  String? topic,
  required Future<R> Function() invoke,
}) async {
  if (mqttInstrumentationSuppressed()) return invoke();
  final span = _tracer().startSpan(
    topic == null ? 'mqtt $operation' : 'mqtt $operation $topic',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(<String, Object>{
      'messaging.system': _messagingSystem,
      'messaging.operation': operation,
      if (topic != null) 'messaging.destination.name': topic,
    }),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Synchronous variant — opens and ends a CLIENT span around a
/// sync MQTT operation (publishMessage / subscribe return
/// immediately; the wire I/O happens via the inner event loop).
R tracedMqttCall<R>({
  required String operation,
  String? topic,
  required R Function() invoke,
}) {
  if (mqttInstrumentationSuppressed()) return invoke();
  final span = _tracer().startSpan(
    topic == null ? 'mqtt $operation' : 'mqtt $operation $topic',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(<String, Object>{
      'messaging.system': _messagingSystem,
      'messaging.operation': operation,
      if (topic != null) 'messaging.destination.name': topic,
    }),
  );
  try {
    return invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
