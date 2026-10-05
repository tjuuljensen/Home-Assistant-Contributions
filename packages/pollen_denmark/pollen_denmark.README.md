# Pollen Denmark Package

Active

Path references in this document:

| Context | Package path |
| --- | --- |
| Home Assistant runtime | `/config/packages/pollen_denmark.yaml` |

## What This Package Does

`pollen_denmark.yaml` provides a full pollen monitoring package for Denmark using:

1. REST sensors for East (`48`) and West (`49`) pollen feed data.
2. Template sensors with normalized state and attributes for UI and automations.
3. Helpers and automations to control update timing and region selection behavior.

The package is designed to replace the old `pollen_dk` integration style with package-native entities.

## Main Helpers And Entities

- `input_button.pollen_update_feed`
  - Manual refresh trigger.
- `input_text.pollen_allergies`
  - Free-text allergy terms used by `binary_sensor.pollen_in_the_air` attributes.
- `input_select.pollen_region`
  - Region selector (`Øst` / `Vest`) used by region-aware logic.
- `sensor.pollen_timestamp_start_of_today`
  - Start-of-day timestamp helper.
- `binary_sensor.pollen_updated_today`
  - Indicates whether feed data has been updated today and exposes `in_pollen_season`.
- `binary_sensor.pollen_in_the_air`
  - Region-aware in-season status with allergy reporting attributes.
- `sensor.pollen_update_time`
  - Source feed update time from astma-allergi.dk.
- `sensor.pollen_feed_last_fetched`
  - Last fetch time from Home Assistant.

## Data Flow

1. REST sensors fetch and normalize raw pollen JSON.
2. Template sensors map each pollen type to stable entity states/attributes.
3. Update automation refreshes `sensor.pollen_update_time` using seasonal/time-window logic.
4. Region and allergy helpers drive dashboards and health-related automations.
