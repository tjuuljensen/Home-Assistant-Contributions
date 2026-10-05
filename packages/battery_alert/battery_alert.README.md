# Battery Alert Package

Active - version 3.0.0

Runtime package path: `/config/packages/battery_alert.yaml`

## Purpose

The package discovers battery sensors directly from Home Assistant's entity
model, derives one problem-state binary sensor, and sends a daily warning using
the notification route selected at runtime.

The package intentionally does not use Home Assistant's `alert` integration.
Its daily summary combines multiple entities and supports runtime routing,
whereas `alert` is better suited to repeated acknowledgement-based warnings for
a fixed entity.

## Architecture

- `custom_templates/battery_alert.jinja` owns battery selection, classification,
  sorting, and message formatting.
- `binary_sensor.low_batteries` is the derived status. It is `on` when one or
  more selected batteries need attention.
- `automation.battery_alert_notification` sends or clears notifications.
- Battery entities are selected when they are sensors with
  `device_class: battery`.
- Hidden entities, restored entities, and entities with
  `battery_alert_disabled: true` are excluded.

The package no longer maintains `group.battery_status`, polls every minute, or
mirrors the condition into an input boolean. Changes to battery entities and
configuration helpers cause the template binary sensor to update naturally.

## Helpers

- `input_number.battery_alert_threshold_max`
  - Inclusive numeric threshold. A value at or below it is low.
- `input_boolean.battery_alert_include_unavailable`
  - Adds `unknown` and `unavailable` battery sensors to the warning.
- `input_select.notifier_format`
  - `Notify` sends through a configured `notify.*` action.
  - `Persistent` uses a Home Assistant persistent notification.
- `input_text.notifier_name`
  - Runtime notify action, for example `notify.teejay`.
  - Invalid values that do not start with `notify.` fall back to
    `notify.teejay`.
- `input_datetime.low_battery_notification_check`
  - Time of the daily warning.

## Derived Status

`binary_sensor.low_batteries` exposes these attributes for dashboards and
diagnostics:

- `threshold`
- `include_unavailable`
- `low_battery_entities`
- `unavailable_battery_entities`
- `low_battery_count`
- `unavailable_battery_count`
- `message`

Numeric notification values use
`states(entity_id, rounded=true, with_unit=true)`. This uses Home Assistant's
formatted sensor state, including the precision configured for the entity,
instead of reformatting the raw number in the package.

## Notification Behavior

The daily trigger only sends when `binary_sensor.low_batteries` is `on`.

- `Notify`
  - Sends a tagged notification through `input_text.notifier_name`.
  - A later daily warning replaces the existing tagged notification on clients
    that support tags.
  - The notification is cleared when the battery condition resolves or the
    route changes.
- `Persistent`
  - Creates or updates one persistent notification immediately when the alert
    details change and at the daily check.
  - Dismisses it when the condition resolves or the route changes.

Changing the notification type or notify action at runtime moves an active
warning to the newly selected route.

## Per-Entity Opt-Out

Add this customization to exclude a battery entity:

```yaml
homeassistant:
  customize:
    sensor.some_battery_entity:
      battery_alert_disabled: true
```

## Recommended Dashboard Card

The dynamic example requires
[`custom:auto-entities`](https://github.com/thomasloven/lovelace-auto-entities).
It reads battery entities directly and does not depend on a maintained group.

```yaml
type: vertical-stack
cards:
  - type: entities
    title: Battery Alert
    show_header_toggle: false
    state_color: true
    entities:
      - entity: binary_sensor.low_batteries
      - entity: input_number.battery_alert_threshold_max
      - entity: input_boolean.battery_alert_include_unavailable
      - entity: input_select.notifier_format
      - entity: input_text.notifier_name
      - entity: input_datetime.low_battery_notification_check
      - entity: automation.battery_alert_notification

  - type: custom:auto-entities
    card:
      type: entities
      title: Battery Sensors
      show_header_toggle: false
    filter:
      include:
        - domain: sensor
          attributes:
            device_class: battery
      exclude:
        - attributes:
            battery_alert_disabled: true
        - attributes:
            restored: true
    sort:
      method: state
      numeric: true
```

The built-in dashboard fallback cannot expand a dynamic entity query. Use the
first `entities` card by itself; its binary sensor state, counts, entity lists,
and message still expose the complete alert result.

## Migration From 2.2

Version 3.0 removes these legacy entities and paths:

- `group.battery_status`
- `automation.battery_alert_update_status_group_members`
- `input_boolean.low_batteries`
- `input_number.battery_alert_threshold_min`
- `automation.battery_alert_delete_a_sensor`
- `input_text.delete_battery_sensor`
- the `Slack` notification option
- all package-managed MQTT battery discovery and deletion behavior

Before deploying version 3.0, update dashboards that reference those entities.
The live phone dashboard was found to contain such references and is not stored
in this repository, so it must be migrated separately.

Additional migration notes:

- `binary_sensor.low_batteries` replaces `input_boolean.low_batteries`.
- `Notify` replaces the previous option named `Default`.
- If the old minimum threshold was `-1`, turn on
  `input_boolean.battery_alert_include_unavailable` to retain unavailable-sensor
  warnings.
- Obsolete entity-registry entries may remain visible until removed through the
  Home Assistant UI after the package has been restarted successfully.
- Investigate restored battery sensors at their source before deleting them;
  the package excludes them but does not mutate the entity registry.

## Deployment And Verification

A full Home Assistant restart is recommended after deployment because this
migration both adds and removes package entities and loads a new custom template.
A partial reload cannot reliably prove that every removed legacy entity has been
unloaded.

After restart, verify:

1. `binary_sensor.low_batteries` is available and its entity-list attributes
   match the expected batteries.
2. Adjusting the maximum threshold updates the binary sensor.
3. Toggling unavailable handling updates the result.
4. Both notification routes work, and changing routes clears the old warning.
5. The daily trigger sends only while the binary sensor is `on`.

No ESPHome recompile or reflash is required.

## Change History

- 3.0.0 (2026-08-23)
  - Replaced the dynamic group and minute polling with direct device-class
    selection.
  - Replaced the synchronized input boolean with a template binary sensor.
  - Replaced the minimum-threshold sentinel with an unavailable-sensor toggle.
  - Kept runtime Notify/Persistent selection and removed Slack.
  - Removed legacy MQTT cleanup helpers and automation.
  - Centralized selection and message formatting in a custom template.
- 2.2.0 (2026-08-23)
  - Used Home Assistant sensor formatting for notification values.
  - Removed the legacy MQTT sensor-creation automation.
