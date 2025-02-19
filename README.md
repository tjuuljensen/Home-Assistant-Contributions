
# Home Assistant Contributions

A collection of my  [Home Assistant](https://www.home-assistant.io/) packages and blueprints. These resources aim to simplify tasks and to enable functions not otherwise available in a Home Asistant setup.

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
    - [Package: Garmin Livetrack](#package-garmin-livetrack)
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


### Package: Garmin Livetrack

> **INPORTANT**: A major 2025 rewrite is in progress. I am testing continouosly and expected release is the end of February.

> **What it’s for**: Integrates Garmin LiveTrack data into Home Assistant by monitoring LiveTrack emails, extracting session and trackpoint data, and updating sensors with real-time activity details.

- **Example Use Case**: Ideal for fitness enthusiasts who want to track their runs, rides, or other activities directly in Home Assistant, visualize live session progress, and receive notifications when a session starts or ends.
- **Installation**: Download the package [here](https://github.com/tjuuljensen/Home-Assistant-Contributions/raw/refs/heads/main/packages/garmin_livetrack/garmin_livetrack.yaml)

---

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