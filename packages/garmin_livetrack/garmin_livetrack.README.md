# Garmin LiveTrack Package

## What This Package Does

`garmin_livetrack.yaml` monitors Garmin LiveTrack links received through Home Assistant and exposes active session, trackpoint, and notification state.

It supports single-user and multi-user LiveTrack monitoring, strict user filtering, and notification behavior for LiveTrack start/end events.

## Source References

- Original package source and upstream discussion: https://community.home-assistant.io/t/garmin-livetrack-tracking-package/552793
- Home Assistant package configuration reference: https://www.home-assistant.io/docs/configuration/packages/
- Home Assistant IMAP integration reference: https://www.home-assistant.io/integrations/imap/

Garmin's 2025/2026 LiveTrack web changes retired the GraphQL fields this
package previously used. Current operation uses the repo-local helper
`/config/utils/garmin-livetrack-fetch.py`, which follows Garmin's web app flow:
fetch the LiveTrack page, keep cookies, extract the CSRF token, call the current
session API, and read trackpoints from the page hydration data when Garmin does
not expose them through the session API response.

## Main Inputs

- Garmin LiveTrack email or manually entered LiveTrack URL.
- IMAP integration configured to extract the LiveTrack URL from Garmin notification emails.
- `input_text.livetrack_url` for manual/testing input.
- strict user control helpers when multiple Garmin users are monitored.

## Main Outputs

- `sensor.livetrack_data`, the command-line fetch sensor with Garmin's current
  session and trackpoint payload.
- `sensor.livetrack_session` and `sensor.livetrack_trackpoints`, compatibility
  template sensors that preserve the public entity contract used by existing
  automations, dashboards, and notifications.
- `binary_sensor.livetrack_in_progress`.
- `automation.livetrack_start_livetrack_updates`, which starts polling for new
  LiveTrack links and resumes active sessions after Home Assistant restart.
- `script.livetrack_update_livetrack`, which owns the polling loop and
  start/end notifications.
- optional per-user derived sensors.
- start/end notifications through the configured notify service.

## Package Boundary

Core LiveTrack inputs, helpers, sensors, automations, and scripts live in
`packages/garmin_livetrack.yaml`.

Site-specific consumers can remain outside the package, such as per-person
derived sensors, dashboard controls, and local automations that consume the
package's public entities.

## Data Model

`sensor.livetrack_data` keeps Garmin's current flat trackpoint shape in
`lastTrackPoint` and `trackPoints`.

For migration compatibility, the helper also emits `legacyLastTrackPoint`. The
public `sensor.livetrack_trackpoints` template reads that compatibility object
so existing package templates can continue using the older `fitnessPointData`
attribute shape. New consumers should prefer `sensor.livetrack_data` when they
do not need the legacy shape.

## Runtime Migration Note

If this package was previously loaded with the old REST sensors, Home Assistant
may keep the restored REST entities on these public IDs:

- `sensor.livetrack_session`
- `sensor.livetrack_trackpoints`

After deploying the current package, the new template entities may initially
appear as `sensor.livetrack_session_2` and `sensor.livetrack_trackpoints_2`.
Use the Home Assistant entity registry UI to move the template entities back to
the original public IDs. `binary_sensor.livetrack_in_progress` depends on the
public IDs.

## Migration State

The latest archived package state was validated with:

- `sensor.livetrack_data` fetched a live session through Garmin's current page
  and API flow.
- trackpoints were extracted from Garmin's Next.js hydration data.
- the public compatibility sensors were migrated back to their original entity
  IDs.
- `binary_sensor.livetrack_in_progress` displayed correctly during an active
  LiveTrack.

## Validation

After editing:

```bash
python utils/ha-include-check.py --json
```

Then run a Home Assistant config check in the live runtime:

```bash
ha core check
```

Runtime validation requires an actual or manually supplied LiveTrack session.
Useful runtime checks:

```bash
python3 /config/utils/sensor-info.py sensor.livetrack_data --format json
python3 /config/utils/sensor-info.py sensor.livetrack_session --format json
python3 /config/utils/sensor-info.py sensor.livetrack_trackpoints --format json
python3 /config/utils/sensor-info.py binary_sensor.livetrack_in_progress --format json --allow-non-sensor
```

## Maintenance Notes

- Keep token/session parsing defensive. Garmin payloads and URLs are external inputs.
- Avoid changing entity IDs unless dashboards and per-user derived sensors are migrated together.
- Keep `legacyLastTrackPoint` as a compatibility layer only. Prefer Garmin's
  current `lastTrackPoint` shape for new consumers.
- A stopped and discarded Garmin LiveTrack may keep returning a viewable session
  with a future placeholder end time and no `END` event. The polling script
  treats stale trackpoints as a local end condition after a grace period.
- The package header contains historical changelog detail; keep this README focused on current operation.
