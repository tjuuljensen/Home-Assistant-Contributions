#!/bin/bash
# 
# A script to send battery status from a Linux PC to a Home Assistant instance.
#
# Author: Torsten Juul-Jensen (tjuuljensen at gmail.com)
# Created: February 2025
# Version: 1.4.0
#
# Requirements:
# - upower (for battery info)
# - curl (for sending data to Home Assistant)
# - jq (for JSON parsing)
# - nmcli (for network SSID check, optional)
#
# Installation:
# - Create a template sensor in Home Assistant after the following template:
#
#    - sensor:
#      - name: "Laptop Battery"
#        unique_id: "laptop_battery"
#        state: "{{ this.state }}"
#        device_class: battery
#        state_class: measurement 
#        attributes:
#          status: "{{ this.attributes.status }}"
#          battery_state: "{{ this.attributes.battery_state }}"
#          time_remaining: "{{ this.attributes.time_remaining }}"
#     
# - Create a new long lived access token in Home Assistant
# - Run the script in a terminal with the parameters suited for your installation and make sure that Home Assistant receives the data.
# - It is STRONGLY recommended to use the --NetworkSSID restriction, to make sure you only send data on trusted networks.
# - Add the script to your crontab - for example every 5th minute: */5 * * * * send_laptop_battery_status --HomeAssistantURL <url> --HomeAssistantSensor <sensor> --HomeAssistantToken <token> .....
# 
# -------------------------------
# Function to detect Linux distribution
# -------------------------------
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    elif command -v lsb_release &>/dev/null; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# -------------------------------
# Function to check for required dependencies
# -------------------------------
check_dependencies() {
    local missing_tools=()
    for tool in upower curl jq nmcli; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        local distro
        distro=$(detect_distro)
        echo "Error: Missing required dependencies: ${missing_tools[*]}"

        case "$distro" in
            ubuntu|debian)
                echo "Install them using: sudo apt install ${missing_tools[*]}"
                ;;
            fedora|rhel|centos)
                echo "Install them using: sudo dnf install ${missing_tools[*]}"
                ;;
            arch)
                echo "Install them using: sudo pacman -S ${missing_tools[*]}"
                ;;
            opensuse*)
                echo "Install them using: sudo zypper install ${missing_tools[*]}"
                ;;
            *)
                echo "Unknown Linux distro. Please install ${missing_tools[*]} manually."
                ;;
        esac
        exit 1
    fi
}

# -------------------------------
# Function to print usage information
# -------------------------------
usage() {
    echo "Usage: $0 --HomeAssistantURL <url> --HomeAssistantSensor <sensor> --HomeAssistantToken <token> [--NetworkSSID <SSID>] [--SensorAttributes <json>]"
    exit 1
}

# -------------------------------
# Parse command-line arguments
# -------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --HomeAssistantURL) HomeAssistantURL="$2"; shift 2 ;;
        --HomeAssistantSensor) HomeAssistantSensor="$2"; shift 2 ;;
        --HomeAssistantToken) HomeAssistantToken="$2"; shift 2 ;;
        --NetworkSSID) NetworkSSID="$2"; shift 2 ;;
        --SensorAttributes) SensorAttributes="$2"; shift 2 ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
done

# Validate required parameters
if [[ -z "$HomeAssistantURL" || -z "$HomeAssistantSensor" || -z "$HomeAssistantToken" ]]; then
    echo "Error: Missing required parameters."
    usage
fi

# Check for required dependencies
check_dependencies

# Ensure HomeAssistantSensor is prefixed with "sensor."
if [[ "$HomeAssistantSensor" != sensor.* ]]; then
    HomeAssistantSensor="sensor.$HomeAssistantSensor"
fi

# Ensure HomeAssistantURL does not have a trailing slash
HomeAssistantURL="${HomeAssistantURL%/}"

# Construct full API URL
HomeAssistantAPIURL="$HomeAssistantURL/api/states/$HomeAssistantSensor"

# -------------------------------
# Validate network connection (if NetworkSSID is specified)
# -------------------------------
if [[ -n "$NetworkSSID" ]]; then
    CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes" {print $2}')
    if [[ "$CURRENT_SSID" != "$NetworkSSID" ]]; then
        echo "Not connected to SSID '$NetworkSSID'. Exiting."
        exit 0
    fi
fi

# -------------------------------
# Retrieve battery status
# -------------------------------
BATTERY_INFO=$(upower -i $(upower -e | grep 'BAT') 2>/dev/null)
if [[ -z "$BATTERY_INFO" ]]; then
    echo "Battery information is not available."
    exit 0
fi

BATTERY_PERCENT=$(echo "$BATTERY_INFO" | grep "percentage" | awk '{print $2}' | tr -d '%')
BATTERY_STATE=$(echo "$BATTERY_INFO" | grep "state" | awk '{print $2}')
TIME_REMAINING=$(echo "$BATTERY_INFO" | grep "time to empty" | awk '{print $4}')

# Normalize battery state
case "$BATTERY_STATE" in
    "discharging") BATTERY_STATE="discharging" ;;
    "charging") BATTERY_STATE="charging" ;;
    "fully-charged") BATTERY_STATE="full" ;;
    *) BATTERY_STATE="unknown" ;;
esac

# -------------------------------
# Parse additional attributes from JSON (Fix for merging issue)
# -------------------------------
ATTRIBUTES="{\"time_remaining\":\"$TIME_REMAINING\",\"battery_state\":\"$BATTERY_STATE\",\"device_class\":\"battery\",\"unit_of_measurement\":\"%\"}"

if [[ -n "$SensorAttributes" ]]; then
    if ! echo "$SensorAttributes" | jq empty 2>/dev/null; then
        echo "Invalid JSON format for --SensorAttributes"
        exit 1
    fi

    # Convert JSON array to merged object
    EXTRA_ATTR=$(echo "$SensorAttributes" | jq 'reduce .[] as $item ({}; . * $item)')

    # Merge additional attributes into the main attributes object
    ATTRIBUTES=$(echo "$ATTRIBUTES" | jq --argjson extra "$EXTRA_ATTR" '. + $extra')
fi

# -------------------------------
# Send data to Home Assistant
# -------------------------------
PAYLOAD="{\"state\": \"$BATTERY_PERCENT\", \"attributes\": $ATTRIBUTES}"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$HomeAssistantAPIURL" \
    -H "Authorization: Bearer $HomeAssistantToken" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

if [[ "$RESPONSE" == "200" || "$RESPONSE" == "201" ]]; then
    echo "Battery data sent to Home Assistant successfully."
else
    echo "Failed to send data to Home Assistant. HTTP Response: $RESPONSE"
    exit 1
fi
