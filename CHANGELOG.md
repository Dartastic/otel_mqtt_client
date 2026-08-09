# Changelog

## [0.3.0-wip]

## [0.2.0] - 2026-08-10

### Changed

- Semantic conventions updated to the current OTel registry: deprecated
  attribute keys are no longer emitted (`db.system` -> `db.system.name`,
  `db.operation` -> `db.operation.name`, `rpc.system` -> `rpc.system.name`,
  with `rpc.service` folded into a fully-qualified `rpc.method`).
- Dependency floors raised to `dartastic_opentelemetry ^1.1.0-beta.12` and
  `dartastic_opentelemetry_api ^1.0.0-rc.1`. The previous floors declared
  compatibility with API versions that predate the semconv enums this
  package uses and could not actually resolve-and-compile.
- `repository` URL corrected to the canonical `Dartastic` org casing so
  pub.dev repository verification succeeds.

- Attribute keys now come from the API's registry enums
  (`Messaging.*`, `ErrorAttributes.*`) instead of string literals,
  and the deprecated `messaging.operation` key was replaced by
  `messaging.operation.name` (plus `messaging.operation.type` where
  a registry value applies, e.g. `send` for publish).

### Added

- `TracedMqttClient` extension on `MqttClient` — `tracedConnect`,
  `tracedDisconnect`, `tracedPublishMessage`, `tracedSubscribe`,
  `tracedUnsubscribe` mirror the `mqtt_client` signatures exactly
  and wrap each call in the CLIENT span described below.
- `tracedMqttCallAsync<R>({operation, topic, operationType, invoke})`
  — generic async helper around connect/disconnect (which are
  async).
- `tracedMqttCall<R>` — sync helper around publishMessage /
  subscribe / unsubscribe (which are sync in `mqtt_client`).
- Both emit a CLIENT span named `mqtt <operation> [<topic>]`
  with `messaging.system=mqtt`, `messaging.operation.name`,
  `messaging.operation.type` (when applicable) and
  `messaging.destination.name`.
- Zone-scoped suppression
  (`runWithoutMqttInstrumentation` / async variant).
- Example (`example/example.md`).
- 6 tests.

### Note

- `package:mqtt_client` speaks MQTT 3.1/3.1.1, which has no message
  properties, so there is no W3C trace-context propagation surface;
  spans carry attributes only and context does not cross the broker.
