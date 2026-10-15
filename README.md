
# Home Assistant Contributions

A collection of my [Home Assistant](https://www.home-assistant.io/) packages,
blueprints, and helper scripts. These resources simplify configuration and
maintenance tasks.

## Table of Contents

- [Home Assistant Contributions](#home-assistant-contributions)
  - [Table of Contents](#table-of-contents)
  - [Blueprints](#blueprints)
    - [Blueprint: Device Charge Control (Always-On)](#blueprint-device-charge-control-always-on)
    - [Blueprint: Device Charge Control (Plugged In/Out)](#blueprint-device-charge-control-plugged-inout)
    - [Blueprint: Copy/Move To-Do List](#blueprint-copymove-to-do-list)
  - [Packages](#packages)
    - [Package: Pollen Denmark](#package-pollen-denmark)
    - [Package: Hue Motion Sensor Sensitivity](#package-hue-motion-sensor-sensitivity)
    - [Package: Copy/Move To-Do List](#package-copymove-to-do-list)
    - [Package: Battery Alert](#package-battery-alert)
    - [Package: Zone Registration](#package-zone-registration)
    - [Garmin LiveTrack integration (external, testing)](#garmin-livetrack-integration-external-testing)
  - [Python Helpers](#python-helpers)
  - [Installation \& Usage](#installation--usage)
  - [Contributing](#contributing)
  - [License](#license)

---


## Blueprints

**Blueprints** streamline automation and script creation in Home Assistant, making them easy to reuse and share.

### Blueprint: Device Charge Control (Always-On)

> **Focus**: This blueprint automates battery charging for devices that remain continuously plugged in, helping prevent both overcharging and deep discharge. It’s particularly useful for cameras, tablets, or laptops that never truly unplug from power.

- **Usage**: Set battery level thresholds so charging starts when the battery falls below a minimum level and stops when it reaches a maximum level, prolonging battery life.
- **Helpers**:
  - [Powershell script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) to send power information from your Windows computer to Home Assistant
  - [Bash script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/send_laptop_battery_status.sh) to send power information from your Linux computer to Home Assistant
- **Installation**: Click the button below to import it directly into your Home Assistant.

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint file.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https://github.com/tjuuljensen/Home-Assistant-Contributions/blob/main/blueprints/device_charge_control/device_charger_control_always_on.yaml)

### Blueprint: Device Charge Control (Plugged In/Out)

> **Focus**: This blueprint automates battery charging for devices that regularly get plugged in and unplugged, such as phones or laptops. It helps maintain battery health by starting and stopping the charge based on customizable thresholds.

- **Usage**: Ideal for devices you only connect when needed—automatically toggles power when battery levels fall below or rise above your set limits. It also handles scenarios where the device goes offline or comes back online, ensuring a safer, more efficient charge cycle.
- **Helpers**:
  - [Powershell script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) to send power information from your Windows computer to Home Assistant
  - [Bash script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/send_laptop_battery_status.sh) to send power information from your Linux computer to Home Assistant
- **Installation**: Click the button below to import it directly into your Home Assistant.

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint file.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/device_charger_control_plugged_in_and_out.yaml)


### Blueprint: Copy/Move To-Do List

> **Focus**: Quickly transfer tasks from one Home Assistant to-do list to another with optional filtering and an easy “move” feature that removes items from the source after copying.

- **Usage**: Ideal for tidying up tasks, merging project lists, or splitting large lists into smaller ones. It saves time and helps maintain clean, organized to-do lists without manual copying or deleting.
- **Package version**: This is also available as a package (more flexible when running different actions) [here](#package-copymove-to-do-list).
- **Installation**: Click the button below to import it directly into your Home Assistant.

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint file.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/copy_move_todo_list/copy_move_todo_list.yaml)


---


## Packages

Packages in Home Assistant let you bundle different aspects of your configuration—like automations, scripts, sensors, and more—into a single file. This repository contains the following packages:

### Package: Pollen Denmark

> **What it’s for**: Monitors and forecasts pollen levels in Denmark, helping allergy sufferers stay informed about daily counts for multiple pollen types.

- **Example Use Case**: Get real-time alerts on high pollen days, automate notifications, or tailor ventilation and cleaning routines for allergy relief.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/pollen_denmark/pollen_denmark.yaml)

   
### Package: Hue Motion Sensor Sensitivity 

> **What it’s for**: Easily adjust and fine-tune the sensitivity of your Hue motion sensors directly from Home Assistant without needing third-party tools.

- **Example Use Case**: Ideal for balancing motion detection in busy areas—reduce false triggers by lowering sensitivity or ensure quick responses in high-traffic zones by increasing it.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/hue_motion_sensor_sensitivity/hue_motion_sensor_sensitivity.yaml)


### Package: Copy/Move To-Do List

> **What it’s for**: Streamline task organization by quickly copying or moving items between any two Home Assistant to-do lists, complete with optional filtering and retention choices.

- **Example Use Case**: Effortlessly consolidate overlapping tasks from multiple lists into a single project list, or split one large list into specialized lists for easier prioritization—all without manual entry.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/copy_move_todo_list/copy_move_todo_list_package.yaml)
- **Blueprint version**: This is also available as a blueprint (for more static use) [here](#blueprint-copymove-to-do-list).


### Package: Battery Alert

> **What it’s for**: This package automatically monitors battery levels from your Home Assistant sensors, creates dedicated battery sensors when needed, and sends notifications if levels fall outside your set thresholds.

- **Example Use Case**: Ideal for keeping track of batteries in wireless devices and sensors, ensuring you receive timely alerts (via MQTT, Slack, or persistent notifications) to replace or recharge them, thereby avoiding unexpected outages.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/battery_alert/battery_alert.yaml)


### Package: Zone Registration

> **What it’s for**: Automates the process of logging time spent in designated zones, recording entries to CSV files for tasks like tracking office attendance or travel deductions.

- **Example Use Case**: Easily record the days you spend at the office (or any other defined zone) for tax deductions or personal productivity tracking. The package supports configurations for up to two people and multiple zones.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/zone_registration/zone_registration.yaml) together with the required shell script (yeah - sorry) [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/zone_registration/zone_registration.sh).


### Garmin LiveTrack integration (external, testing)

> **Status**: In testing. It is not currently presented as a production-ready contribution.

The former Garmin LiveTrack package has been removed from this repository. The
current implementation is maintained separately in
[`tjuuljensen/ha-garmin-livetrack`](https://github.com/tjuuljensen/ha-garmin-livetrack).
Follow that repository's documentation for current installation and testing
instructions.

- **Purpose**: Integrates Garmin LiveTrack data into Home Assistant by monitoring
  LiveTrack sessions and exposing activity details.
- **Testing**: Expect incomplete behavior and breaking changes while the external
  repository is being validated.

---

## Python Helpers

| Script | Purpose | Requirements |
| --- | --- | --- |
| [set_state.py](python_scripts/set_state.py) | Update an existing entity's state/attributes or remove one attribute with `delete_attribute` | Home Assistant's `python_script` integration |
| [export-button-card-templates.py](utils/export-button-card-templates.py) | Export templates from Lovelace YAML and dashboard storage, together or in connected groups | Python 3.10+ and PyYAML |
| [hass-backup-unpack.py](utils/hass-backup-unpack.py) | List backup members or explicitly extract selected nested archives | Python 3.10+; `securetar` for extraction |
| [find-unused-sensors.py](utils/find-unused-sensors.py) | Report sensor definitions that lack static references | Python 3.10+ and PyYAML |

For `set_state.py`, copy the file to `/config/python_scripts/set_state.py`,
enable `python_script:` in `configuration.yaml`, and restart Home Assistant
when enabling the integration for the first time. Reload Python scripts when
adding a file to an already enabled integration. Call `python_script.set_state`
with `entity_id` and optional `state`, attribute updates, or
`delete_attribute: <attribute-name>`. Its header contains input examples.
Integration-owned attributes may return on the next integration update.

The utilities run from a terminal on Windows or Linux. Install PyYAML in your
chosen Python environment (`python -m pip install PyYAML`); install `securetar`
only when extracting backups (`python -m pip install securetar`). From this
repository root, start with:

```text
python utils/export-button-card-templates.py --help
python utils/hass-backup-unpack.py --help
python utils/find-unused-sensors.py --help
```

Select your own config root or backup path rather than running against this
contributions checkout. Exports and extracted backups may contain private
configuration or credentials; keep generated output outside this public repo.
Unused-sensor findings require review because dynamic references cannot be
proven by static analysis.

These files are published from HomeAssistantConfig through its allowlisted
publisher. Maintainer changes belong in that source first, then in a new
publication batch. The unused-sensor analyzer retains its original upstream
attribution in the script header.

## Installation & Usage

1. **Import blueprints**:  
   - You can use the direct link (the “Add this to my Home Assistant” button above) to import the blueprint.  
   - Alternatively, navigate to *Settings* → *Automations & Scenes* → *Blueprints* → *Import Blueprint* and paste the raw GitHub URL.

2. **Clone or download this repository** into your preferred GitHub code directory:
   ```bash
   cd config/
   git clone https://github.com/tjuuljensen/Home-Assistant-Contributions.git
   ```
   ...and copy the package or blueprint files from there.
   
   Or you could manually download individual files and place them in the corresponding `packages/` or `blueprints/` folders.

3. **Read the documentation**: Blueprints and packages comes with shorter or larger amount of written documentation in the header. I highly recommend reading it, as there is important information in many of them.  

4. **Enable packages**:  
   Make sure your `configuration.yaml` is set up to load packages. For example:
   ```yaml
   homeassistant:
     packages: !include_dir_named packages
   ```
   
5. **Configure package options and automations** using your newly installed packages or blueprints. Adjust the triggers, conditions, and actions to suit your preferences.


---

## Contributing

If you have suggestions or improvements, please open an issue or submit a pull request. Contributions are welcome, whether it’s bug fixes, additional functionality, or new packages/blueprints altogether.

---

## License

This repository is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute the code as permitted under the license terms.

---

Happy automating! If you find these contributions helpful, consider giving the repository a ⭐ on [GitHub](https://github.com/tjuuljensen/Home-Assistant-Contributions).
