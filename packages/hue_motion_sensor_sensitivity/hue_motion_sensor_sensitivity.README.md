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
- Python 3 and the local Supervisor Core API Unix socket are required for the
  command-line reader. `curl` is still required by the unchanged write and
  registration shell commands.

## Hub Data Reader

Deploy `/config/utils/hue-motion-sensor-hub-data.py` with the package. The
standard-library reader replaces only the templated `curl | jq` sensor command,
so it does not depend on shell parsing or bypass Command line's secure argument
execution. The non-secret device name uses
[`base64_encode`](https://www.home-assistant.io/template-functions/base64_encode/) to preserve quotes,
Unicode, and shell metacharacters as literal data. The template also lets Core
clear this sensor's repair on the next update.

The reader gets the current `input_text.hue_hub_ip` and
`input_text.hue_hub_username` through the Unix socket specified by Core's
`SUPERVISOR_CORE_API_SOCKET` environment variable. It uses two read-only
`GET /api/states/<entity_id>` requests. The protected socket already provides
authentication; no new token, credential file, helper, or restore-state snapshot
is needed. Credentials stay out of command arguments and diagnostics.
This requires a Supervisor-managed Core runtime with its API socket. We cannot
verify statically whether the socket is available on this installation. The
mechanism is present in
[Core 2026.10 socket setup](https://github.com/home-assistant/core/blob/2026.10.0/homeassistant/components/http/__init__.py)
and [socket authentication](https://github.com/home-assistant/core/blob/2026.10.0/homeassistant/components/http/auth.py).

The bridge request remains `GET https://<bridge>/api/<username>/sensors/` with
the existing self-signed certificate compatibility of `curl --insecure`.
Redirects are not followed, matching the previous curl command. Only this bridge
connection disables certificate verification. Full device data is merged with
`device_id`, `sensitivity`, `sensitivitymax`, and `on`; absent config fields remain
JSON null. The sensor's existing state template and attribute list are unchanged.

| Input or trigger | Preserved behavior |
| --- | --- |
| Exact device-name match | Compact JSON, including nested config/state and existing attributes |
| No match, Hue API error list, empty response, bridge transport failure | Empty stdout, exit zero, matching the former pipeline without pipefail |
| Invalid JSON or malformed sensor data | Nonzero exit without a successful payload; sanitized diagnostic |
| Duplicate device names | Multiple JSON lines, retaining the previous ambiguous output rather than choosing a device |
| Startup, selection, hub discovery, sensitivity write | Existing refresh actions and helper behavior |
| Availability and scheduled polling | Existing availability template and 30-day scan interval |

Local helper/API failures exit nonzero without exposing response bodies. Each
local read has a 2-second timeout and the bridge has a 10-second timeout. The
unchanged 15-second Command line timeout still bounds the entire process.
Home Assistant remains responsible
for its sensor state and attribute handling on empty/failed output.

Windows validation uses mocked transports:

```powershell
python -m unittest discover -s utils/tests -p test_hue_motion_sensor_hub_data.py
python utils/hue-motion-sensor-hub-data.py --help
python utils/hue-motion-sensor-hub-data.py --version
```

After an authorized deployment, reload Command line or restart Core, then refresh
`sensor.hue_motion_sensor_hub_data`. Verify the live socket is available in the
Core container, the selected device ID and attributes are correct, both hub
selections still work, and the repair clears after the update. Do not infer
current repair status from saved repair records. We cannot verify statically
the live network/API behavior. Rollback restores the previous package command; it
requires `curl` and `jq` and restores the pending 2027.4 incompatibility.

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
