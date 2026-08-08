// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'mqtt_suppression.dart';

const _tracerName = 'otel_mqtt_client';
const _messagingSystem = 'mqtt';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

Attributes _spanAttributes(
  String operation,
  String? topic,
  MessagingOperationType? operationType,
) =>
    OTel.attributesFromMap(<String, Object>{
      Messaging.messagingSystem.key: _messagingSystem,
      Messaging.messagingOperationName.key: operation,
      if (operationType != null)
        Messaging.messagingOperationType.key: operationType.value,
      if (topic != null) Messaging.messagingDestinationName.key: topic,
    });

void _recordError(Span span, Object e, StackTrace st) {
  span.addAttributes(OTel.attributes([
    OTel.attributeString(
      ErrorAttributes.errorType.key,
      e.runtimeType.toString(),
    ),
  ]));
  span.recordException(e, stackTrace: st);
  span.setStatus(SpanStatusCode.Error, e.toString());
}

/// Generic async helper. Opens a CLIENT span around an MQTT
/// operation.
///
/// Pass [operationType] when the operation maps onto a registry
/// `messaging.operation.type` value (e.g. publish ->
/// [MessagingOperationType.send]); connection-level operations
/// (connect / disconnect / subscribe) have no registry type and
/// emit only `messaging.operation.name`.
Future<R> tracedMqttCallAsync<R>({
  required String operation,
  String? topic,
  MessagingOperationType? operationType,
  required Future<R> Function() invoke,
}) async {
  if (mqttInstrumentationSuppressed()) return invoke();
  final span = _tracer().startSpan(
    topic == null ? 'mqtt $operation' : 'mqtt $operation $topic',
    kind: SpanKind.client,
    attributes: _spanAttributes(operation, topic, operationType),
  );
  try {
    return await invoke();
  } catch (e, st) {
    _recordError(span, e, st);
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
  MessagingOperationType? operationType,
  required R Function() invoke,
}) {
  if (mqttInstrumentationSuppressed()) return invoke();
  final span = _tracer().startSpan(
    topic == null ? 'mqtt $operation' : 'mqtt $operation $topic',
    kind: SpanKind.client,
    attributes: _spanAttributes(operation, topic, operationType),
  );
  try {
    return invoke();
  } catch (e, st) {
    _recordError(span, e, st);
    rethrow;
  } finally {
    span.end();
  }
}
