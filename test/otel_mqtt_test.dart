// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_mqtt_client/otel_mqtt_client.dart';
import 'package:test/test.dart';

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
      expect(attrs['messaging.system'], equals('mqtt'));
      expect(attrs['messaging.operation'], equals('connect'));
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
      expect(attrs['messaging.operation'], equals('publish'));
      expect(attrs['messaging.destination.name'], equals('sensors/temp'));
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
  });
}
