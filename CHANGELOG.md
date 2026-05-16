# Changelog

## [0.1.0-beta.1-wip]

### Added

- `tracedMqttCallAsync<R>({operation, topic, invoke})` — generic
  async helper around connect/disconnect (which are async).
- `tracedMqttCall<R>` — sync helper around publishMessage /
  subscribe / unsubscribe (which are sync in `mqtt_client`).
- Both emit a CLIENT span named `mqtt <operation> [<topic>]`
  with `messaging.system=mqtt`, `messaging.operation`,
  `messaging.destination.name`.
- Zone-scoped suppression
  (`runWithoutMqttInstrumentation` / async variant).
- 4 tests.
