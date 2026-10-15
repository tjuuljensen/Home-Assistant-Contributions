# Zone Registration Package

Active

Path references in this document:

| Context | Package path |
| --- | --- |
| Home Assistant runtime | `/config/packages/zone_registration.yaml` |
| Helper script | `/config/packages/zone_registration.sh` (moved at startup to `/config/www/csv/zone_registration.sh`) |
| Statistics helper | `/config/utils/zone-registration-statistics.py` (read-only) |

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

1. Ensure package and registration script are present under `/config/packages/`, and the statistics helper is present under `/config/utils/`.
2. Restart Home Assistant so startup automation creates `/config/www/csv` and moves the script.
3. Select `input_select.zones`, `input_select.person_entities`, and a label in `input_text.zone_registration_config_label`.
4. Run `script.zone_registration_save_config`.
5. Use:
   - `script.zone_registration_update_csv_from_lovelace` for one day
   - `script.zone_registration_update_csv_range_from_lovelace_gui` for a date range
   - `script.zone_registration_update_csv` for direct service-driven updates (supports explicit `filename`)

## Statistics Contract And Activation

The statistics sensor calls `python3 /config/utils/zone-registration-statistics.py`
with the filename derived from the selected config label. It polls every 3600
seconds; config selection and automatic registration also request an update.
The helper only reads the selected CSV and emits `monthly` and `yearly` arrays,
sorted by month and year. Monthly entries contain `month`, `date` (the first of
the month), `days`, and `year`; yearly entries contain `year` and `days`.
The sensor state remains the final sorted year's count, or zero for no data.

To preserve the previous jq behavior, counting skips the header and the final
newline-split item. An unterminated final row is therefore omitted. Duplicate,
blank, and malformed rows are counted without date validation; semicolon fields
after the first field do not affect statistics. An unreadable or missing file
returns `{"monthly":[],"yearly":[]}` with exit status zero and no error output.
The existing sensor availability rules and fallback filename remain unchanged.

For local verification, run
`python utils/zone-registration-statistics.py --file <fixture.csv>` and
`python -m unittest discover -s utils/tests -p test_zone_registration_statistics.py`.
The helper also supports `--help` and `--version`.

Deploy the YAML and statistics helper together through the repository deployment
workflow when authorized. Validate the deployed config, then reload Command line
configuration or restart Home Assistant. Verify the selected filename, sensor
state, both attributes, and repair status after an update. Runtime behavior and
repair clearance cannot verify statically. Rollback restores the prior YAML
command; registration CSV files and saved helper state need no migration or reset.
The existing publication manifest includes the statistics helper whenever
`package.zone-registration` is selected; public copies are updated only through
that workflow.

## Known Constraints

- Config is stored in `input_text.zone_registration_config` (`max: 255`), so practical config count is limited.
- Registration still depends on its Bash/GNU utilities; statistics require only the Python standard library.
- CSV and statistics behavior depends on runtime file contents and cannot verify statically.
