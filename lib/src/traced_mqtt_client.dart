// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:typed_data/typed_data.dart' as typed;

import 'otel_mqtt.dart';

/// Traced wrappers over the real [MqttClient] surface.
///
/// Each method delegates to the corresponding [MqttClient] member
/// inside a CLIENT span with registry `messaging.*` attributes.
/// Signatures mirror `mqtt_client` exactly, so call sites swap
/// `connect` -> `tracedConnect` etc. with no other change.
///
/// Note: `package:mqtt_client` speaks MQTT 3.1/3.1.1, which has no
/// message properties, so there is no W3C trace-context propagation
/// surface — spans carry attributes only and context does not cross
/// the broker.
extension TracedMqttClient on MqttClient {
  /// [MqttClient.connect] wrapped in a `mqtt connect` span.
  Future<MqttClientConnectionStatus?> tracedConnect([
    String? username,
    String? password,
  ]) =>
      tracedMqttCallAsync(
        operation: 'connect',
        invoke: () => connect(username, password),
      );

  /// [MqttClient.disconnect] wrapped in a `mqtt disconnect` span.
  void tracedDisconnect() =>
      tracedMqttCall(operation: 'disconnect', invoke: disconnect);

  /// [MqttClient.publishMessage] wrapped in a `mqtt publish <topic>`
  /// span with `messaging.operation.type=send`.
  int tracedPublishMessage(
    String topic,
    MqttQos qualityOfService,
    typed.Uint8Buffer data, {
    bool retain = false,
  }) =>
      tracedMqttCall(
        operation: 'publish',
        topic: topic,
        operationType: MessagingOperationType.send,
        invoke: () => publishMessage(
          topic,
          qualityOfService,
          data,
          retain: retain,
        ),
      );

  /// [MqttClient.subscribe] wrapped in a `mqtt subscribe <topic>`
  /// span.
  Subscription? tracedSubscribe(String topic, MqttQos qosLevel) =>
      tracedMqttCall(
        operation: 'subscribe',
        topic: topic,
        invoke: () => subscribe(topic, qosLevel),
      );

  /// [MqttClient.unsubscribe] wrapped in a `mqtt unsubscribe <topic>`
  /// span.
  void tracedUnsubscribe(String topic, {bool expectAcknowledge = false}) =>
      tracedMqttCall(
        operation: 'unsubscribe',
        topic: topic,
        invoke: () => unsubscribe(topic, expectAcknowledge: expectAcknowledge),
      );
}
