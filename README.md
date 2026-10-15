# Home Assistant Contributions

A collection of my [Home Assistant](https://www.home-assistant.io/) packages,
blueprints, custom Jinja templates, dashboard examples, and scripts. These
resources simplify configuration and maintenance tasks.

## Table of Contents

- [Repository layout](#repository-layout)
- [Blueprints](#blueprints)
- [Packages](#packages)
- [Custom templates and dashboards](#custom-templates-and-dashboards)
- [Home Assistant Python scripts](#home-assistant-python-scripts)
- [Command-line utilities](#command-line-utilities)
- [External integrations](#external-integrations)
- [Installation & Usage](#installation--usage)
- [Contributing](#contributing)
- [License](#license)

## Repository layout

| Location | Components and where they run |
| --- | --- |
| [`blueprints/`](blueprints/) | Importable Home Assistant automation/script blueprints; laptop battery reporters and their Linux trigger guide live beside the charge-control blueprints. |
| [`packages/`](packages/) | Home Assistant YAML packages, each with a companion README; Zone Registration also requires its shell script. Pollen Denmark includes dashboard/configuration images. |
| [`custom_templates/`](custom_templates/) | Reusable Jinja macros loaded by Home Assistant from `/config/custom_templates/`. |
| [`python_scripts/`](python_scripts/) | Scripts executed inside Home Assistant by the `python_script` integration, using its restricted runtime. |
| [`utils/`](utils/) | Standalone maintenance programs run with Python in a terminal on Windows or Linux. |
| [Issue templates](.github/ISSUE_TEMPLATE/) | [Bug reports](.github/ISSUE_TEMPLATE/bug_report.md) and [feature requests](.github/ISSUE_TEMPLATE/feature_request.md). |
| [`.gitignore`](.gitignore), [LICENSE](LICENSE) | File exclusions and MIT license. |

Put a Python file in `python_scripts/` only when it is intended to be called as
`python_script.<name>` inside Home Assistant. Put ordinary Python CLI tools with
imports, filesystem access, or third-party dependencies in `utils/`. Shell and
PowerShell companions needed by a particular component stay beside it.

## Blueprints

**Blueprints** streamline automation and script creation in Home Assistant, making them easy to reuse and share.

### Blueprint: Device Charge Control (Always-On)

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [device_charger_control_always_on.yaml](blueprints/device_charge_control/device_charger_control_always_on.yaml) | `/config/blueprints/automation/tjuuljensen/device_charger_control_always_on.yaml` or import button | Required charging automation blueprint | [Inputs and blueprint YAML](blueprints/device_charge_control/device_charger_control_always_on.yaml); select entities in the blueprint UI |
| [Windows reporter](blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) | A scripts folder on the Windows laptop | Optional laptop battery/power sensor reporter | [Parameters and invocation examples in header](blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) |
| [Linux reporter](blueprints/device_charge_control/scripts/send_laptop_battery_status.sh) | A scripts folder on the Linux laptop | Optional laptop battery/power sensor reporter | [Script header](blueprints/device_charge_control/scripts/send_laptop_battery_status.sh); [cron/udev setup](blueprints/device_charge_control/scripts/linux_trigger_configuration.md) |

> **Focus**: This blueprint automates battery charging for devices that remain continuously plugged in, helping prevent both overcharging and deep discharge. It’s particularly useful for cameras, tablets, or laptops that never truly unplug from power.

- **Usage**: Set battery level thresholds so charging starts when the battery falls below a minimum level and stops when it reaches a maximum level, prolonging battery life.
- **Helpers**:
  - [Powershell script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) to send power information from your Windows computer to Home Assistant
  - [Bash script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/send_laptop_battery_status.sh) to send power information from your Linux computer to Home Assistant
- **Installation**: Click the button below to import it directly into your Home Assistant.

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint file.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https://github.com/tjuuljensen/Home-Assistant-Contributions/blob/main/blueprints/device_charge_control/device_charger_control_always_on.yaml)

For Linux scheduling and power events, see the [trigger setup guide](blueprints/device_charge_control/scripts/linux_trigger_configuration.md).

### Blueprint: Device Charge Control (Plugged In/Out)

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [device_charger_control_plugged_in_and_out.yaml](blueprints/device_charge_control/device_charger_control_plugged_in_and_out.yaml) | `/config/blueprints/automation/tjuuljensen/device_charger_control_plugged_in_and_out.yaml` or import button | Required charging automation blueprint | [Inputs and blueprint YAML](blueprints/device_charge_control/device_charger_control_plugged_in_and_out.yaml); select entities in the blueprint UI |
| [Windows reporter](blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) | A scripts folder on the Windows laptop | Optional laptop battery/power sensor reporter | [Parameters and invocation examples in header](blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) |
| [Linux reporter](blueprints/device_charge_control/scripts/send_laptop_battery_status.sh) | A scripts folder on the Linux laptop | Optional laptop battery/power sensor reporter | [Script header](blueprints/device_charge_control/scripts/send_laptop_battery_status.sh); [cron/udev setup](blueprints/device_charge_control/scripts/linux_trigger_configuration.md) |

> **Focus**: This blueprint automates battery charging for devices that regularly get plugged in and unplugged, such as phones or laptops. It helps maintain battery health by starting and stopping the charge based on customizable thresholds.

- **Usage**: Ideal for devices you only connect when needed—automatically toggles power when battery levels fall below or rise above your set limits. It also handles scenarios where the device goes offline or comes back online, ensuring a safer, more efficient charge cycle.
- **Helpers**:
  - [Powershell script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/Send-LaptopBatteryStatus.ps1) to send power information from your Windows computer to Home Assistant
  - [Bash script](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/scripts/send_laptop_battery_status.sh) to send power information from your Linux computer to Home Assistant
- **Installation**: Click the button below to import it directly into your Home Assistant.

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint file.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/device_charge_control/device_charger_control_plugged_in_and_out.yaml)


### Blueprint: Copy/Move To-Do List

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [copy_move_todo_list.yaml](blueprints/copy_move_todo_list/copy_move_todo_list.yaml) | `/config/blueprints/script/tjuuljensen/copy_move_todo_list.yaml` or import button | Required script blueprint for transferring tasks | [Inputs and blueprint YAML](blueprints/copy_move_todo_list/copy_move_todo_list.yaml); select lists in the blueprint UI |

> **Focus**: Quickly transfer tasks from one Home Assistant to-do list to another with optional filtering and an easy “move” feature that removes items from the source after copying.

- **Usage**: Ideal for tidying up tasks, merging project lists, or splitting large lists into smaller ones. It saves time and helps maintain clean, organized to-do lists without manual copying or deleting.
- **Package version**: This is also available as a package (more flexible when running different actions) [here](#package-copymove-to-do-list).
- **Installation**: Click the button below to import it directly into your Home Assistant.

[![Open your Home Assistant instance and show the blueprint import dialog with a specific blueprint file.](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/blueprints/copy_move_todo_list/copy_move_todo_list.yaml)


---


## Packages

Packages in Home Assistant let you bundle different aspects of your configuration—like automations, scripts, sensors, and more—into a single file. This repository contains the following packages:

### Package: Pollen Denmark

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [pollen_denmark.yaml](packages/pollen_denmark/pollen_denmark.yaml) | `/config/packages/pollen_denmark.yaml` | Required: Pollen sensors and configuration helpers | [YAML header / configuration](packages/pollen_denmark/pollen_denmark.yaml); [setup guide](packages/pollen_denmark/pollen_denmark.README.md) |

Enable packages with the [configuration.yaml example](#installation--usage). Companion READMEs and images are documentation, not runtime files.

[Setup and reference documentation](packages/pollen_denmark/pollen_denmark.README.md)

> **What it’s for**: Monitors and forecasts pollen levels in Denmark, helping allergy sufferers stay informed about daily counts for multiple pollen types.

- **Example Use Case**: Get real-time alerts on high pollen days, automate notifications, or tailor ventilation and cleaning routines for allergy relief.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/pollen_denmark/pollen_denmark.yaml)

   
### Package: Hue Motion Sensor Sensitivity 

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [hue_motion_sensor_sensitivity.yaml](packages/hue_motion_sensor_sensitivity/hue_motion_sensor_sensitivity.yaml) | `/config/packages/hue_motion_sensor_sensitivity.yaml` | Required: Hue sensor sensitivity controls; requires curl and jq | [YAML header / configuration](packages/hue_motion_sensor_sensitivity/hue_motion_sensor_sensitivity.yaml); [setup guide](packages/hue_motion_sensor_sensitivity/hue_motion_sensor_sensitivity.README.md) |

Enable packages with the [configuration.yaml example](#installation--usage). Companion READMEs and images are documentation, not runtime files.

[Setup and reference documentation](packages/hue_motion_sensor_sensitivity/hue_motion_sensor_sensitivity.README.md)

> **What it’s for**: Easily adjust and fine-tune the sensitivity of your Hue motion sensors directly from Home Assistant without needing third-party tools.

- **Example Use Case**: Ideal for balancing motion detection in busy areas—reduce false triggers by lowering sensitivity or ensure quick responses in high-traffic zones by increasing it.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/hue_motion_sensor_sensitivity/hue_motion_sensor_sensitivity.yaml)


### Package: Copy/Move To-Do List

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [copy_move_todo_list_package.yaml](packages/copy_move_todo_list/copy_move_todo_list_package.yaml) | `/config/packages/copy_move_todo_list_package.yaml` | Required: Scripts for copying or moving to-do items | [YAML header / configuration](packages/copy_move_todo_list/copy_move_todo_list_package.yaml); [setup guide](packages/copy_move_todo_list/copy_move_todo_list_package.README.md) |

Enable packages with the [configuration.yaml example](#installation--usage). Companion READMEs and images are documentation, not runtime files.

[Setup and reference documentation](packages/copy_move_todo_list/copy_move_todo_list_package.README.md)

> **What it’s for**: Streamline task organization by quickly copying or moving items between any two Home Assistant to-do lists, complete with optional filtering and retention choices.

- **Example Use Case**: Effortlessly consolidate overlapping tasks from multiple lists into a single project list, or split one large list into specialized lists for easier prioritization—all without manual entry.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/copy_move_todo_list/copy_move_todo_list_package.yaml)
- **Blueprint version**: This is also available as a blueprint (for more static use) [here](#blueprint-copymove-to-do-list).


### Package: Battery Alert

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [battery_alert.yaml](packages/battery_alert/battery_alert.yaml) | `/config/packages/battery_alert.yaml` | Required: Battery monitoring and notification controls | [YAML header / configuration](packages/battery_alert/battery_alert.yaml); [setup guide](packages/battery_alert/battery_alert.README.md) |
| [battery_alert.jinja](custom_templates/battery_alert.jinja) | `/config/custom_templates/battery_alert.jinja` | Required shared template macros | Imported by the package; [macro definitions](custom_templates/battery_alert.jinja) |

Enable packages with the [configuration.yaml example](#installation--usage). Companion READMEs and images are documentation, not runtime files.

[Setup and reference documentation](packages/battery_alert/battery_alert.README.md)

> **What it’s for**: This package automatically monitors battery levels from your Home Assistant sensors, creates dedicated battery sensors when needed, and sends notifications if levels fall outside your set thresholds.

- **Example Use Case**: Ideal for keeping track of batteries in wireless devices and sensors, ensuring you receive timely alerts (through your configured notification service or persistent notifications) to replace or recharge them, thereby avoiding unexpected outages.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/battery_alert/battery_alert.yaml)


### Package: Zone Registration

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [zone_registration.yaml](packages/zone_registration/zone_registration.yaml) | `/config/packages/zone_registration.yaml` | Required: Zone events and CSV statistics; requires jq | [YAML header / configuration](packages/zone_registration/zone_registration.yaml); [setup guide](packages/zone_registration/zone_registration.README.md) |
| [zone_registration.sh](packages/zone_registration/zone_registration.sh) | `/config/packages/zone_registration.sh` initially; package moves it to `/config/www/csv/zone_registration.sh` | Required CSV writer | [Script usage header](packages/zone_registration/zone_registration.sh); invoked by package shell commands |

Enable packages with the [configuration.yaml example](#installation--usage). Companion READMEs and images are documentation, not runtime files.

[Setup and reference documentation](packages/zone_registration/zone_registration.README.md)

> **What it’s for**: Automates the process of logging time spent in designated zones, recording entries to CSV files for tasks like tracking office attendance or travel deductions.

- **Example Use Case**: Easily record the days you spend at the office (or any other defined zone) for tax deductions or personal productivity tracking. The package supports configurations for up to two people and multiple zones.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/zone_registration/zone_registration.yaml) together with the required shell script (yeah - sorry) [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/zone_registration/zone_registration.sh).


### Package: ODIN Feedparser

| Origin in this repo | Destination in your setup | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [odin_feedparser.yaml](packages/odin_feedparser/odin_feedparser.yaml) | `/config/packages/odin_feedparser.yaml` | Required: Feed sensors and polling controls; requires the Feedparser custom integration | [YAML header / configuration](packages/odin_feedparser/odin_feedparser.yaml); [setup guide](packages/odin_feedparser/odin_feedparser.README.md) |
| [odin.jinja](custom_templates/odin.jinja) | `/config/custom_templates/odin.jinja` | Required shared template macros | Imported by the package; [macro definitions](custom_templates/odin.jinja) |
| [Entity reference](packages/odin_feedparser/odin_feedparser.reference.md) | Documentation only; no runtime copy | Package entities and behavior | [Entity reference](packages/odin_feedparser/odin_feedparser.reference.md) |

Enable packages with the [configuration.yaml example](#installation--usage). Companion READMEs and images are documentation, not runtime files.

Consumes Danish emergency-service RSS feeds, provides incident summary sensors,
and supports timed rapid polling. Published locations are replacement examples.

- [Package YAML](packages/odin_feedparser/odin_feedparser.yaml)
- [Installation, dependencies, and example values](packages/odin_feedparser/odin_feedparser.README.md)
- [Required Jinja macros](custom_templates/odin.jinja)

## Custom templates and dashboards

| Origin in this repo | Destination in your config | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [battery_alert.jinja](custom_templates/battery_alert.jinja) | `/config/custom_templates/battery_alert.jinja` | Required Battery Alert calculations/message macros | Imported by [battery_alert.yaml](packages/battery_alert/battery_alert.yaml) |
| [odin.jinja](custom_templates/odin.jinja) | `/config/custom_templates/odin.jinja` | Required ODIN incident macros | Imported by [odin_feedparser.yaml](packages/odin_feedparser/odin_feedparser.yaml); Markdown card example in its header |


[`custom_templates/odin.jinja`](custom_templates/odin.jinja) supplies incident
filtering, counts, icons, elapsed time, and state colors for ODIN. Copy it into
`/config/custom_templates/odin.jinja` and reload custom templates.

The ODIN package YAML header contains the current Markdown card example.
For dashboard examples using `custom:button-card`, install the
[custom-cards/button-card](https://github.com/custom-cards/button-card) frontend
card. The template exporter below works with that card's templates.
Pollen Denmark's YAML header contains setup/card examples; its README links
these reference images:
[configuration](packages/pollen_denmark/images/pollen_config.png),
[button card](packages/pollen_denmark/images/button_card_example.png),
[forecast](packages/pollen_denmark/images/pollen_forecast_card.png), and
[forecast without today's update](packages/pollen_denmark/images/pollen_forecast_card_no_update_today.png).

## Home Assistant Python scripts

| Origin in this repo | Destination in your config | Purpose | Configuration / example |
| --- | --- | --- | --- |
| [set_state.py](python_scripts/set_state.py) | `/config/python_scripts/set_state.py` | Update entity state/attributes or remove an attribute | Enable `python_script:`; call `python_script.set_state` with `entity_id` and optional `state`. [Full examples in header](python_scripts/set_state.py) |

For `set_state.py`, copy the file to `/config/python_scripts/set_state.py`,
enable `python_script:` in `configuration.yaml`, and restart Home Assistant
when enabling the integration for the first time. Reload Python scripts when
adding a file to an already enabled integration. Call `python_script.set_state`
with `entity_id` and optional `state`, attribute updates, or
`delete_attribute: <attribute-name>`. Its header contains input examples.
Integration-owned attributes may return on the next integration update.

## Command-line utilities

These programs belong in `utils/` and run in your own Python environment. They
are not loaded by the Home Assistant `python_script` integration.

| Origin in this repo | Destination in your setup | Purpose and requirements | Configuration / example |
| --- | --- | --- | --- |
| [export-button-card-templates.py](utils/export-button-card-templates.py) | Local checkout or scripts folder | Export [custom:button-card](https://github.com/custom-cards/button-card) templates from dashboard YAML/storage; Python 3.10+ and PyYAML | [CLI examples in header](utils/export-button-card-templates.py); merge exported `button_card_templates` into the dashboard root |
| [hass-backup-unpack.py](utils/hass-backup-unpack.py) | Local checkout or scripts folder | List/extract backup archives; Python 3.10+, `securetar` for extraction | No HA YAML; [CLI examples in header](utils/hass-backup-unpack.py) |
| [find-unused-sensors.py](utils/find-unused-sensors.py) | Local checkout or scripts folder | Find sensor definitions lacking static references; Python 3.10+ and PyYAML | No HA YAML; [CLI options in header](utils/find-unused-sensors.py) |
| [ha-include-check.py](utils/ha-include-check.py) | Local checkout, or `/config/utils/ha-include-check.py` for a HA shell | Detect missing include targets and report unreferenced files; Python 3.6+, standard library | No HA YAML; [examples and limitations below](#check-include-references-before-maintenance) |

The utilities run from a terminal on Windows or Linux. Install PyYAML in your
chosen Python environment (`python -m pip install PyYAML`); install `securetar`
only when extracting backups (`python -m pip install securetar`). From this
repository root, start with:

```text
python utils/export-button-card-templates.py --help
python utils/hass-backup-unpack.py --help
python utils/find-unused-sensors.py --help
python utils/ha-include-check.py --help
```

Select your own config root or backup path rather than running against this
contributions checkout. Exports and extracted backups may contain private
configuration or credentials; keep generated output outside this public repo.
Unused-sensor findings require review because dynamic references cannot be
proven by static analysis.

Examples use `includes/` for include-directory paths. Home Assistant permits
either folder name, as long as the paths match your installation. Run Home
Assistant's configuration check before using edited examples.

### Check include references before maintenance

`ha-include-check.py` is a quick, read-only check for broken include paths after
moving configuration files, splitting packages, or preparing a deployment. It
checks that `!include` files and `!include_dir_merge_list` /
`!include_dir_merge_named` directories exist, resolving relative targets from
the selected configuration file's directory. It needs no Home Assistant runtime,
network connection, or third-party Python packages.

From this repository on Windows, select your own configuration file:

```powershell
python utils/ha-include-check.py -c "C:/path/to/ha/configuration.yaml"
python utils/ha-include-check.py -c "C:/path/to/ha/configuration.yaml" --json
python utils/ha-include-check.py -c "C:/path/to/ha/configuration.yaml" -u includes
```

On a Linux/Home Assistant shell, after installing the script under `/config`:

```bash
python3 /config/utils/ha-include-check.py -c /config/configuration.yaml --json
```

`-u includes` reports files directly inside the `includes/` directory that are not
explicitly referenced; it skips subdirectories and filters certain `customize*`
files referenced from a separate `homeassistant:` include. Review these findings
before deleting anything: directory includes and indirect references can make
apparently unreferenced files necessary. `--json` provides structured results
for other tools; `-q` suppresses normal text output. Exit status is `0` for no
findings, `1` for findings or a configuration read error, and `2` for invalid
arguments. Without `-c`, it checks `configuration.yaml` in the working directory.

The checker scans text rather than parsing YAML. It does not recursively follow
includes, validate Home Assistant configuration semantics, or support
`!include_dir_named` / `!include_dir_list`. Commented directives, quoted paths,
and inline comments can produce misleading results. Run Home Assistant's own
configuration check before reloading or restarting.

## External integrations

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

3. **Read the documentation**: Read each package's companion README and the blueprint headers for dependencies and setup details.

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
