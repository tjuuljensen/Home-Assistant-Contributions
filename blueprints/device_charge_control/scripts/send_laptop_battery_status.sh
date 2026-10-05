#!/usr/bin/env bash
#
# Name: send_laptop_battery_status.sh
# Description: Send Linux laptop battery status to Home Assistant through MQTT or REST.
#
# Functionality:
# - Reads battery data from UPower.
# - Optionally restricts execution to a trusted Wi-Fi SSID.
# - Publishes retained MQTT telemetry or sends a Home Assistant /api/states payload.
# - Supports additional sensor attributes as either a JSON object or a JSON array of objects.
# - Handles charging, discharging, fully charged, unknown, and missing discharge runtime data.
#
# Usage:
#   ./send_laptop_battery_status.sh \
#     [--MqttHost <host> --MqttTopic <topic>] \
#     [--HomeAssistantURL <url> --HomeAssistantSensor <sensor> --HomeAssistantToken <token>] \
#     [--NetworkSSID <SSID>] \
#     [--SensorAttributes <json>]
#
# Options:
#   --HomeAssistantURL       Base URL of Home Assistant, for example http://homeassistant.local:8123
#   --HomeAssistantSensor    Entity ID or name. The sensor. prefix is added if omitted.
#   --HomeAssistantToken     Home Assistant long-lived access token.
#   --MqttHost               MQTT broker hostname or IP address.
#   --MqttPort               MQTT broker port. Defaults to 1883.
#   --MqttTopic              MQTT state topic, for example home/laptops/analyzer/battery/state.
#   --MqttUsername           Optional MQTT username.
#   --MqttPassword           Optional MQTT password.
#   --MqttPublisher          MQTT publisher command. Defaults to mosquitto_pub.
#   --NoMqttRetain           Publish MQTT telemetry without retain. Retain is recommended.
#   --NetworkSSID            Optional Wi-Fi SSID guard. Requires nmcli only when used.
#   --SensorAttributes       Optional JSON object or array of objects merged into attributes.
#
# Examples:
#   ./send_laptop_battery_status.sh \
#     --MqttHost "homeassistant.local" \
#     --MqttTopic "home/laptops/analyzer/battery/state"
#
#   ./send_laptop_battery_status.sh \
#     --HomeAssistantURL "http://homeassistant.local:8123" \
#     --HomeAssistantSensor "laptop_battery" \
#     --HomeAssistantToken "TOKEN" \
#     --NetworkSSID "Trusted WiFi" \
#     --SensorAttributes '{"state_class":"measurement","battery_alert_disabled":true}'
#
# Home Assistant payload contract:
#   state: battery percentage
#   attributes:
#     status: normalized battery status text
#     battery_state: normalized battery status text
#     battery_state_raw: raw UPower state
#     battery_percent: battery percentage
#     time_remaining: minutes until empty while discharging, or null
#     time_remaining_minutes: minutes until empty while discharging, or null
#     time_remaining_text: original UPower runtime text, or null
#     power_source: battery, ac, or unknown
#     source: upower
#     battery_device: selected UPower battery device path
#     device_class: battery
#     state_class: measurement
#     unit_of_measurement: "%"
#
# Author: Torsten Juul-Jensen
# Created: February 2025
# Version: 1.6.0
# GPT iteration: 2026-05-31
# Version comment: Add direct retained MQTT publishing while keeping REST publishing
#                  as an optional fallback.

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
HomeAssistantURL=""
HomeAssistantSensor=""
HomeAssistantToken=""
MqttHost=""
MqttPort="1883"
MqttTopic=""
MqttUsername=""
MqttPassword=""
MqttPublisher="mosquitto_pub"
NoMqttRetain=0
NetworkSSID=""
SensorAttributes=""

usage() {
    cat <<USAGE
Usage: $SCRIPT_NAME [--MqttHost <host> --MqttTopic <topic>] [--HomeAssistantURL <url> --HomeAssistantSensor <sensor> --HomeAssistantToken <token>] [--NetworkSSID <SSID>] [--SensorAttributes <json>]
USAGE
    exit 1
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID:-unknown}"
    elif command_exists lsb_release; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

print_install_hint() {
    local distro="$1"
    shift
    local missing=("$@")

    case "$distro" in
        ubuntu|debian)
            echo "Install them using: sudo apt install ${missing[*]}" >&2
            ;;
        fedora|rhel|centos)
            echo "Install them using: sudo dnf install ${missing[*]}" >&2
            ;;
        arch)
            echo "Install them using: sudo pacman -S ${missing[*]}" >&2
            ;;
        opensuse*)
            echo "Install them using: sudo zypper install ${missing[*]}" >&2
            ;;
        *)
            echo "Unknown Linux distro. Please install ${missing[*]} manually." >&2
            ;;
    esac
}

check_dependencies() {
    local missing_tools=()
    local required_tools=(upower jq)

    if [[ -n "$HomeAssistantURL" || -n "$HomeAssistantSensor" || -n "$HomeAssistantToken" ]]; then
        required_tools+=(curl)
    fi

    if [[ -n "$MqttHost" || -n "$MqttTopic" ]]; then
        required_tools+=("$MqttPublisher")
    fi

    if [[ -n "$NetworkSSID" ]]; then
        required_tools+=(nmcli)
    fi

    local tool
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies: ${missing_tools[*]}" >&2
        print_install_hint "$(detect_distro)" "${missing_tools[@]}"
        exit 1
    fi
}

require_value() {
    local option="$1"
    local value="${2-}"

    if [[ -z "$value" || "$value" == --* ]]; then
        fail "Missing value for $option"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --HomeAssistantURL)
            require_value "$1" "${2-}"
            HomeAssistantURL="$2"
            shift 2
            ;;
        --HomeAssistantSensor)
            require_value "$1" "${2-}"
            HomeAssistantSensor="$2"
            shift 2
            ;;
        --HomeAssistantToken)
            require_value "$1" "${2-}"
            HomeAssistantToken="$2"
            shift 2
            ;;
        --MqttHost)
            require_value "$1" "${2-}"
            MqttHost="$2"
            shift 2
            ;;
        --MqttPort)
            require_value "$1" "${2-}"
            MqttPort="$2"
            shift 2
            ;;
        --MqttTopic)
            require_value "$1" "${2-}"
            MqttTopic="$2"
            shift 2
            ;;
        --MqttUsername)
            require_value "$1" "${2-}"
            MqttUsername="$2"
            shift 2
            ;;
        --MqttPassword)
            require_value "$1" "${2-}"
            MqttPassword="$2"
            shift 2
            ;;
        --MqttPublisher)
            require_value "$1" "${2-}"
            MqttPublisher="$2"
            shift 2
            ;;
        --NoMqttRetain)
            NoMqttRetain=1
            shift
            ;;
        --NetworkSSID)
            require_value "$1" "${2-}"
            NetworkSSID="$2"
            shift 2
            ;;
        --SensorAttributes)
            require_value "$1" "${2-}"
            SensorAttributes="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter: $1" >&2
            usage
            ;;
    esac
done

UseRest=0
UseMqtt=0

if [[ -n "$HomeAssistantURL" || -n "$HomeAssistantSensor" || -n "$HomeAssistantToken" ]]; then
    UseRest=1
    if [[ -z "$HomeAssistantURL" || -z "$HomeAssistantSensor" || -z "$HomeAssistantToken" ]]; then
        fail "REST publishing requires --HomeAssistantURL, --HomeAssistantSensor, and --HomeAssistantToken"
    fi
fi

if [[ -n "$MqttHost" || -n "$MqttTopic" ]]; then
    UseMqtt=1
    if [[ -z "$MqttHost" || -z "$MqttTopic" ]]; then
        fail "MQTT publishing requires --MqttHost and --MqttTopic"
    fi
fi

if [[ "$UseRest" -eq 0 && "$UseMqtt" -eq 0 ]]; then
    fail "Configure either MQTT or REST publishing"
fi

check_dependencies

if [[ "$UseRest" -eq 1 && "$HomeAssistantSensor" != sensor.* ]]; then
    HomeAssistantSensor="sensor.$HomeAssistantSensor"
fi

if [[ "$UseRest" -eq 1 ]]; then
    HomeAssistantURL="${HomeAssistantURL%/}"
    HomeAssistantAPIURL="$HomeAssistantURL/api/states/$HomeAssistantSensor"
fi

if [[ -n "$NetworkSSID" ]]; then
    CURRENT_SSID="$(nmcli -t --escape no -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1 == "yes" { sub(/^yes:/, ""); print; exit }')"
    if [[ "$CURRENT_SSID" != "$NetworkSSID" ]]; then
        echo "Not connected to SSID '$NetworkSSID'. Exiting."
        exit 0
    fi
fi

get_selected_battery_device() {
    local display_device="/org/freedesktop/UPower/devices/DisplayDevice"
    local info=""

    if upower -e 2>/dev/null | grep -qx "$display_device"; then
        info="$(upower -i "$display_device" 2>/dev/null || true)"
        if echo "$info" | grep -qE '^[[:space:]]*percentage:'; then
            echo "$display_device"
            return 0
        fi
    fi

    upower -e 2>/dev/null | grep -E '/battery_[^/]+$' | head -n 1
}

normalize_battery_state() {
    local raw_state="$1"

    case "$raw_state" in
        discharging)
            echo "discharging"
            ;;
        charging|pending-charge)
            echo "charging"
            ;;
        fully-charged)
            echo "full"
            ;;
        empty)
            echo "empty"
            ;;
        pending-discharge)
            echo "plugged_in"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

get_power_source() {
    local normalized_state="$1"

    case "$normalized_state" in
        discharging|empty)
            echo "battery"
            ;;
        charging|full|plugged_in)
            echo "ac"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

time_text_to_minutes() {
    local time_text="$1"

    if [[ -z "$time_text" ]]; then
        return 0
    fi

    awk '
        NF >= 2 {
            value = $1 + 0
            unit = tolower($2)
            if (unit ~ /^hour/) {
                printf "%.0f", value * 60
            } else if (unit ~ /^minute/) {
                printf "%.0f", value
            } else if (unit ~ /^second/) {
                printf "%.0f", value / 60
            }
        }
    ' <<< "$time_text"
}

BATTERY_DEVICE="$(get_selected_battery_device)"
if [[ -z "$BATTERY_DEVICE" ]]; then
    echo "Battery information is not available."
    exit 0
fi

BATTERY_INFO="$(upower -i "$BATTERY_DEVICE" 2>/dev/null || true)"
if [[ -z "$BATTERY_INFO" ]]; then
    echo "Battery information is not available."
    exit 0
fi

BATTERY_PERCENT="$(awk -F': *' '/^[[:space:]]*percentage:/ { gsub(/%/, "", $2); print $2; exit }' <<< "$BATTERY_INFO")"
BATTERY_STATE_RAW="$(awk -F': *' '/^[[:space:]]*state:/ { print $2; exit }' <<< "$BATTERY_INFO")"
TIME_TO_EMPTY_TEXT="$(awk -F': *' '/^[[:space:]]*time to empty:/ { print $2; exit }' <<< "$BATTERY_INFO")"

if [[ -z "$BATTERY_PERCENT" ]]; then
    echo "Battery percentage is not available."
    exit 0
fi

if ! [[ "$BATTERY_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    fail "Battery percentage has unexpected value: $BATTERY_PERCENT"
fi

BATTERY_STATE="$(normalize_battery_state "$BATTERY_STATE_RAW")"
POWER_SOURCE="$(get_power_source "$BATTERY_STATE")"

TIME_REMAINING_TEXT=""
case "$BATTERY_STATE" in
    discharging|empty)
        TIME_REMAINING_TEXT="$TIME_TO_EMPTY_TEXT"
        ;;
    *)
        # UPower commonly does not expose a reliable "time to full" field.
        # Keep runtime null unless an actual discharge estimate is available.
        TIME_REMAINING_TEXT=""
        ;;
esac

TIME_REMAINING_MINUTES="$(time_text_to_minutes "$TIME_REMAINING_TEXT")"
TIME_REMAINING_JSON="null"
if [[ -n "$TIME_REMAINING_MINUTES" && "$TIME_REMAINING_MINUTES" =~ ^[0-9]+$ ]]; then
    TIME_REMAINING_JSON="$TIME_REMAINING_MINUTES"
fi

EXTRA_ATTRIBUTES="{}"
if [[ -n "$SensorAttributes" ]]; then
    if ! printf '%s' "$SensorAttributes" | jq empty >/dev/null 2>&1; then
        fail "Invalid JSON format for --SensorAttributes"
    fi

    EXTRA_ATTRIBUTES="$(printf '%s' "$SensorAttributes" | jq -c '
        if type == "array" then
            reduce .[] as $item ({}; if ($item | type) == "object" then . * $item else error("all array entries must be objects") end)
        elif type == "object" then
            .
        else
            error("SensorAttributes must be a JSON object or an array of objects")
        end
    ')" || fail "Invalid --SensorAttributes structure. Use a JSON object or an array of objects."
fi

PAYLOAD="$(jq -n -c \
    --arg state "$BATTERY_PERCENT" \
    --arg status "$BATTERY_STATE" \
    --arg battery_state "$BATTERY_STATE" \
    --arg battery_state_raw "$BATTERY_STATE_RAW" \
    --arg battery_device "$BATTERY_DEVICE" \
    --arg power_source "$POWER_SOURCE" \
    --arg source "upower" \
    --arg time_remaining_text "$TIME_REMAINING_TEXT" \
    --argjson time_remaining "$TIME_REMAINING_JSON" \
    --argjson extra "$EXTRA_ATTRIBUTES" \
    '{
        state: ($state | tonumber),
        attributes: ({
            status: $status,
            battery_state: $battery_state,
            battery_state_raw: $battery_state_raw,
            battery_percent: ($state | tonumber),
            time_remaining: $time_remaining,
            time_remaining_minutes: $time_remaining,
            time_remaining_text: (if $time_remaining_text == "" then null else $time_remaining_text end),
            power_source: $power_source,
            source: $source,
            battery_device: $battery_device,
            device_class: "battery",
            state_class: "measurement",
            unit_of_measurement: "%"
        } + $extra)
    }'
)" || fail "Failed to build Home Assistant payload"

if [[ "$UseMqtt" -eq 1 ]]; then
    MQTT_PAYLOAD="$(jq -c '.attributes + {state: .state}' <<< "$PAYLOAD")" || fail "Failed to build MQTT payload"
    MQTT_ARGS=(-h "$MqttHost" -p "$MqttPort" -t "$MqttTopic" -m "$MQTT_PAYLOAD")

    if [[ "$NoMqttRetain" -eq 0 ]]; then
        MQTT_ARGS+=(-r)
    fi

    if [[ -n "$MqttUsername" ]]; then
        MQTT_ARGS+=(-u "$MqttUsername")
    fi

    if [[ -n "$MqttPassword" ]]; then
        MQTT_ARGS+=(-P "$MqttPassword")
    fi

    "$MqttPublisher" "${MQTT_ARGS[@]}" || fail "Failed to publish data to MQTT"
    echo "Battery data published to MQTT successfully."
fi

if [[ "$UseRest" -eq 1 ]]; then
    RESPONSE_BODY_FILE="$(mktemp)"
    HTTP_CODE="$(curl -sS -o "$RESPONSE_BODY_FILE" -w "%{http_code}" \
        --connect-timeout 10 \
        --max-time 30 \
        -X POST "$HomeAssistantAPIURL" \
        -H "Authorization: Bearer $HomeAssistantToken" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")"
    CURL_EXIT=$?
    RESPONSE_BODY="$(cat "$RESPONSE_BODY_FILE" 2>/dev/null || true)"
    rm -f "$RESPONSE_BODY_FILE"

    if [[ $CURL_EXIT -ne 0 ]]; then
        fail "Failed to send data to Home Assistant. curl exit code: $CURL_EXIT"
    fi

    case "$HTTP_CODE" in
        200|201)
            echo "Battery data sent to Home Assistant successfully."
            ;;
        *)
            echo "Failed to send data to Home Assistant. HTTP Response: $HTTP_CODE" >&2
            if [[ -n "$RESPONSE_BODY" ]]; then
                echo "$RESPONSE_BODY" >&2
            fi
            exit 1
            ;;
    esac
fi
