# How to ensure the right triggers on Linux

For send_laptop_battery_status.sh to work seamlessly on a Linux computer, you want it to trigger in these situations:

- Every n'th minute (5 minutes recommended)
- When plugging in power to update the battery_state (charging, discharging)
- When unplugging power to update the battery_state (charging, discharging)
- When resuming from sleep (not described here)

Follow this guide to set up time based and trigger based events where the script will fire.

It is STRONGLY recommended to use the --NetworkSSID option to ensure that the script only try to send data when on your own network.

Please be aware that there may be distro variations where the following does not apply and where you have to find your own way.

## Timed events: Add a cron job

Edit your crontab

```
sudo crontab -e
```

Add a line at the end of your crontab. The example will fire every 5 minutes forever. Edit path and parameters from the example:

```
*/5 * * * * /some/path/send_laptop_battery_status.sh <ADD_YOUR_PARAMETERS_AND_INFO_HERE>
```


## Power events: Create udev rules

Use usev to identify your systems udev info. One of the following may work on your system. 
```
sudo udevadm info --path=/sys/class/power_supply/AC
sudo udevadm info --path=/sys/class/power_supply/ac
sudo udevadm info --path=/sys/class/power_supply/battery
```

Make sure the following matches YOUR Linux variant. Adjust according to udev output above.

### Switch to battery

```
# udev rule -Switching to battery mode
# /etc/udev/rules.d/90-onbattery.rules
#
# View udev info: sudo udevadm info --path=/sys/class/power_supply/AC
# 
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/bin/systemctl start batterydata_to_homeassistant.service"
```

### Switch to AC power

```
# udev rule - Switching to ac power mode
# /etc/udev/rules.d/91-onacpower.rules
#
# View udev info: sudo udevadm info --path=/sys/class/power_supply/AC
# 
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/bin/systemctl start batterydata_to_homeassistant.service"
```

### Create a service file 

Create a service file - make sure to alter the location and name of the script. In the example it is assumes that send_to_my_homeassistant.sh is a script with the full command line including /some/path/send_laptop_battery_status.sh <ALL_COMMAND_LINE_OPTIONS>.


```
# Service File to send battery data to home assistant
# /etc/systemd/system/batterydata_to_homeassistant.service                                                                                                                                                                         
[Unit]
Description=Send battery information to Home Assistant

[Service]
User=root
Type=simple
GuessMainPID=false
ExecStart=/bin/bash /some/path/send_to_my_homeassistant.sh
```

### Reload udevadm & systemctl 

Reload udevadm to load the new udev rules and reload systemctl to read new service file.

```
udevadm control --reload-rules && udevadm trigger
sudo systemctl daemon-reload
```

Test if Home Assistant receives data by running this command.
```
sudo systemctl start batterydata_to_homeassistant
```