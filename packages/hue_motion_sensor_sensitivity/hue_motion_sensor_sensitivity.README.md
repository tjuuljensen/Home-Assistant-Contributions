# Hue Motion Sensor Sensitivity Package

Active

Path references in this document:

| Context | Package path |
| --- | --- |
| Home Assistant runtime | `/config/packages/hue_motion_sensor_sensitivity.yaml` |

## What This Package Does

`hue_motion_sensor_sensitivity.yaml` lets Home Assistant read and write Hue motion sensor sensitivity directly via the Hue bridge API.

The package provides:

- helper fields for Hue hub IP, username, and multi-hub JSON config
- sensor selection and sensitivity selection controls
- command-line polling of current sensor config from the selected Hue hub
- scripts to register hub user, populate selectors, sync selected hub credentials, and write sensitivity
- automations to keep selectors and data in sync

## Main Entities

Helpers:

- `input_text.hue_hub_ip`
- `input_text.hue_hub_username`
- `input_text.hue_hubs`
- `input_select.hue_hubs`
- `input_select.motion_sensor_entities`
- `input_select.hue_motion_sensitivity`

Sensors:

- `sensor.hue_motion_sensor_hub_data`
- `sensor.hue_motion_sensor_device_name` (`unique_id: hue_motion_sensor_device_name`)
- `sensor.hue_motion_sensitivity_index` (`unique_id: hue_motion_sensitivity_index`)

Scripts:

- `script.hue_motion_sensor_register_hub_user`
- `script.hue_motion_sensor_set_active_hub_credentials`
- `script.hue_motion_sensors_fill_hue_sensor_input_select`
- `script.hue_motion_sensor_write_config_to_sensor`

Automations:

- `automation.hue_motion_sensor_multihub_fetch_data_when_input_selects_change`
- `automation.hue_motion_sensor_fill_input_selects_with_data`
- `automation.hue_motion_sensor_refresh_data_when_selected_sensor_changes`

## Core Flow

1. Set `input_text.hue_hub_ip`.
2. Press the physical Hue bridge button.
3. Run `script.hue_motion_sensor_register_hub_user`.
4. Run `script.hue_motion_sensors_fill_hue_sensor_input_select`.
5. Select sensor in `input_select.motion_sensor_entities`.
6. Select level in `input_select.hue_motion_sensitivity`.
7. Run `script.hue_motion_sensor_write_config_to_sensor`.

## Known Constraints

- Multi-hub storage is limited by `input_text` size and practical JSON length.
- Selector logic is now restricted to entities from the Hue integration to avoid non-Hue presence sensors.
- `curl` and `jq` must be available in the Home Assistant runtime used by `command_line` and `shell_command`.

## Suggested Lovelace Layout

```yaml
type: vertical-stack
cards:
  - type: entities
    title: Hue Motion - Hub Config
    show_header_toggle: false
    entities:
      - entity: input_select.hue_hubs
      - entity: input_text.hue_hub_ip
      - entity: input_text.hue_hub_username
      - entity: input_text.hue_hubs
      - type: divider
      - entity: script.hue_motion_sensor_register_hub_user
        name: Register Hub User
      - entity: script.hue_motion_sensor_set_active_hub_credentials
        name: Sync Selected Hub Credentials
  - type: entities
    title: Hue Motion - Sensitivity
    show_header_toggle: false
    entities:
      - entity: input_select.motion_sensor_entities
      - entity: input_select.hue_motion_sensitivity
      - entity: sensor.hue_motion_sensor_device_name
        name: Selected Device Name
      - type: custom:multiple-entity-row
        entity: sensor.hue_motion_sensor_hub_data
        name: Configured sensitivity
        show_state: false
        entities:
          - attribute: sensitivity
            name: Sens.
          - attribute: sensitivitymax
            name: S.Max
          - attribute: device_id
            name: ID
      - type: divider
      - entity: script.hue_motion_sensor_write_config_to_sensor
        name: Write Sensitivity To Sensor
  - type: entities
    title: Hue Motion - Script Control
    show_header_toggle: false
    entities:
      - entity: script.hue_motion_sensors_fill_hue_sensor_input_select_2
        name: Refresh Motion Sensor And Hub Lists
      - entity: automation.hue_motion_sensor_fill_input_selects_with_data
        name: Fill input selects with data
      - entity: automation.hue_motion_sensor_refresh_data_when_selected_sensor_changes
        name: Refresh data when selected sensor changes
      - entity: >-
          automation.hue_motion_sensor_multihub_fetch_data_when_input_selects_change
        name: Multihub fetch data when input select changes
```
