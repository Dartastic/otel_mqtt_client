// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:otel_mqtt_client/otel_mqtt_client.dart';
import 'package:test/test.dart';
import 'package:typed_data/typed_data.dart' as typed;

class _MemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> s) async {
    if (_shutdown) return;
    spans.addAll(s);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

Map<String, Object> _attrs(Span span) =>
    {for (final a in span.attributes.toList()) a.key: a.value};

void main() {
  group('mqtt OTel helpers', () {
    late _MemorySpanExporter exporter;

    setUp(() async {
      await OTel.reset();
      exporter = _MemorySpanExporter();
      await OTel.initialize(
        serviceName: 'mqtt-otel-test',
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(exporter),
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('tracedMqttCallAsync emits CLIENT span with messaging.* attrs',
        () async {
      await tracedMqttCallAsync<void>(
        operation: 'connect',
        invoke: () async {},
      );
      final span = exporter.spans.single;
      expect(span.kind, equals(SpanKind.client));
      expect(span.name, equals('mqtt connect'));
      final attrs = _attrs(span);
      expect(attrs[Messaging.messagingSystem.key], equals('mqtt'));
      expect(attrs[Messaging.messagingOperationName.key], equals('connect'));
      // Registry key sanity: the wire keys are the current
      // (non-deprecated) semconv names.
      expect(attrs.containsKey('messaging.operation'), isFalse);
      expect(attrs.containsKey('messaging.operation.name'), isTrue);
    });

    test('tracedMqttCall (sync) records destination.name', () {
      tracedMqttCall<int>(
        operation: 'publish',
        topic: 'sensors/temp',
        invoke: () => 42,
      );
      final span = exporter.spans.single;
      expect(span.name, equals('mqtt publish sensors/temp'));
      final attrs = _attrs(span);
      expect(attrs[Messaging.messagingOperationName.key], equals('publish'));
      expect(
        attrs[Messaging.messagingDestinationName.key],
        equals('sensors/temp'),
      );
    });

    test('exception flips span to Error', () {
      expect(
        () => tracedMqttCall<void>(
          operation: 'publish',
          topic: 't',
          invoke: () => throw StateError('disconnected'),
        ),
        throwsStateError,
      );
      expect(exporter.spans.single.status, equals(SpanStatusCode.Error));
    });

    test('runWithoutMqttInstrumentationAsync bypasses spans', () async {
      await runWithoutMqttInstrumentationAsync(() async {
        await tracedMqttCallAsync<void>(
          operation: 'connect',
          invoke: () async {},
        );
      });
      expect(exporter.spans, isEmpty);
    });

    test(
        'tracedPublishMessage on an unconnected client emits an Error '
        'span with send operation type', () {
      final client = MqttServerClient('localhost', 'otel-mqtt-test');
      final payload = typed.Uint8Buffer()..addAll([1, 2, 3]);
      expect(
        () => client.tracedPublishMessage(
          'sensors/temp',
          MqttQos.atMostOnce,
          payload,
        ),
        throwsA(isA<ConnectionException>()),
      );
      final span = exporter.spans.single;
      expect(span.kind, equals(SpanKind.client));
      expect(span.name, equals('mqtt publish sensors/temp'));
      expect(span.status, equals(SpanStatusCode.Error));
      final attrs = _attrs(span);
      expect(attrs[Messaging.messagingSystem.key], equals('mqtt'));
      expect(attrs[Messaging.messagingOperationName.key], equals('publish'));
      expect(
        attrs[Messaging.messagingOperationType.key],
        equals(MessagingOperationType.send.value),
      );
      expect(
        attrs[Messaging.messagingDestinationName.key],
        equals('sensors/temp'),
      );
      expect(
        attrs[ErrorAttributes.errorType.key],
        equals('ConnectionException'),
      );
    });

    test('tracedConnect delegates through the async helper', () async {
      // No broker: connect() fails fast on an unresolvable host lookup
      // or refused connection — either way the span must flip to
      // Error and still carry the messaging attrs. No network is
      // required for the assertion.
      final client = MqttServerClient('localhost', 'otel-mqtt-test')
        ..port = 1; // nothing listens on port 1
      try {
        await client.tracedConnect();
      } on Exception {
        // expected: no broker
      }
      client.disconnect();
      expect(exporter.spans, isNotEmpty);
      final span = exporter.spans.first;
      expect(span.name, equals('mqtt connect'));
      final attrs = _attrs(span);
      expect(attrs[Messaging.messagingSystem.key], equals('mqtt'));
      expect(attrs[Messaging.messagingOperationName.key], equals('connect'));
    });
  });
}
