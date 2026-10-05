# Zone Registration Package

Active

Path references in this document:

| Context | Package path |
| --- | --- |
| Home Assistant runtime | `/config/packages/zone_registration.yaml` |
| Helper script | `/config/packages/zone_registration.sh` (moved at startup to `/config/www/csv/zone_registration.sh`) |

## What This Package Does

`zone_registration.yaml` tracks days and time spent in selected zones and writes entries to CSV files under `/config/www/csv/`.

The package supports both:

- manual updates from Lovelace helper controls
- automatic updates from zone state change events based on saved person+zone config

## Main Entities

Helpers:

- `input_select.zone_registration_config`
- `input_select.zones`
- `input_select.person_entities`
- `input_datetime.zone_registration_date_start`
- `input_datetime.zone_registration_date_end`
- `input_boolean.zone_registration_enter`
- `input_boolean.zone_registration_leave`
- `input_boolean.zone_registration_review`
- `input_text.zone_registration_comment`
- `input_text.zone_registration_config_label`
- `input_text.zone_registration_config`

Template entities:

- `sensor.zone_registration_filename` (`unique_id: zone_registration_filename`)
- `binary_sensor.zone_registration_config_valid` (`unique_id: zone_registration_config_valid`)

Command line sensor:

- `sensor.zone_registration_statistics`

Scripts:

- `script.zone_registration_save_config`
- `script.zone_registration_update_csv`
- `script.zone_registration_update_csv_from_lovelace`
- `script.zone_registration_update_csv_range_from_lovelace_gui`
- `script.zone_registration_remove_date_csv_from_lovelace`

Automations:

- `automation.zone_registration_initialize_start_values`
- `automation.zone_registration_fill_input_select_with_data`
- `automation.zone_registration_auto_update_input_select_when_config_changes`
- `automation.zone_registration_register_configured_zone_events`

## Core Flow

1. Ensure package and script are present under `/config/packages/`.
2. Restart Home Assistant so startup automation creates `/config/www/csv` and moves the script.
3. Select `input_select.zones`, `input_select.person_entities`, and a label in `input_text.zone_registration_config_label`.
4. Run `script.zone_registration_save_config`.
5. Use:
   - `script.zone_registration_update_csv_from_lovelace` for one day
   - `script.zone_registration_update_csv_range_from_lovelace_gui` for a date range
   - `script.zone_registration_update_csv` for direct service-driven updates (supports explicit `filename`)

## Known Constraints

- Config is stored in `input_text.zone_registration_config` (`max: 255`), so practical config count is limited.
- The package depends on runtime tools used by shell/command-line integrations (`bash`, `awk`, `jq`).
- CSV and statistics behavior depends on runtime file contents and cannot verify statically.
