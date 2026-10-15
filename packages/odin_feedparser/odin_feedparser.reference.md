# ODIN Feedparser Package

## What This Package Does

`odin_feedparser.yaml` consumes ODIN RSS feed entities from the Feedparser custom integration and exposes normalized incident summary sensors.

The package is primarily used for dashboard badges, Markdown cards, conditional cards, and simple alerting around selected fire station events.

## Main Dependencies

- Feedparser custom integration.
- ODIN feed entities:
  - `sensor.odin_ostjyllands_brandvaesen_feed`
  - `sensor.odin_beredskab_fyn_feed`
- Custom template macros in `/config/custom_templates/odin.jinja`.

## Main Entities

- `sensor.odin_ostjyllands_brandvaesen_feed_summary`
- `sensor.odin_beredskab_fyn_odense_feed_summary`
- `input_number.odin_rapid_poll_duration_minutes` controls the rapid-poll
  window in whole minutes.
- `binary_sensor.odin_ostjylland_aarhus_rapid_polling` is on only while the
  Østjylland/Aarhus rapid-poll window and shared polling script are active.
- `binary_sensor.odin_fyn_odense_rapid_polling` is on only while
  the Fyn/Odense rapid-poll window and shared polling script are
  active.

The two binary sensors can be used as dashboard visibility conditions to hide
their corresponding manual poll controls during an active poll.

The shared polling script runs in parallel mode with a maximum of two active
runs, allowing the Østjylland/Aarhus and Fyn/Odense feeds to poll
at the same time. Each run only starts, checks, and cancels its own feed timer.

## Validation

After editing this package:

```bash
python utils/ha-include-check.py --json
```

Then run a Home Assistant config check in the live runtime.

After editing `/config/custom_templates/odin.jinja`, reload custom templates from Developer Tools or call `homeassistant.reload_custom_templates`.

## Maintenance Notes

- Keep incident parsing logic in `custom_templates/odin.jinja` where possible.
- Keep package sensors focused on normalized state and attributes.
- The YAML header contains a Lovelace example; if it grows, move the card example to `docs/references/lovelace/`.
