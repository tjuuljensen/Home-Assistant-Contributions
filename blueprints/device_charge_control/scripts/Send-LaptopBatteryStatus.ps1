<#
.SYNOPSIS
    Sends Windows laptop battery status to Home Assistant through MQTT or REST.

.DESCRIPTION
    Reads battery status from Win32_Battery and publishes retained JSON telemetry
    to MQTT, or updates a Home Assistant entity through the /api/states endpoint.

    The payload contract is aligned with send-laptop-battery-status.sh so Windows and
    Linux clients send the same logical attributes:

      state: battery percentage
      attributes:
        status: normalized battery status text
        battery_state: normalized battery status text
        battery_state_raw: raw Win32_Battery BatteryStatus value(s)
        battery_percent: battery percentage
        time_remaining: minutes until empty/full, or null
        time_remaining_minutes: minutes until empty/full, or null
        time_remaining_text: readable runtime text, or null
        power_source: battery, ac, or unknown
        source: win32_battery
        battery_count: number of Win32_Battery records
        device_class: battery
        state_class: measurement
        unit_of_measurement: "%"

    Additional attributes can be supplied as either a JSON object or a JSON array of
    objects. Additional attributes are merged after the default attributes, so they can
    intentionally override defaults.

.PARAMETER HomeAssistantURL
    Base URL of the Home Assistant server.
    Example: "http://homeassistant.local:8123".

.PARAMETER HomeAssistantSensor
    Entity ID or sensor name. If the value does not start with "sensor.", the prefix is added.

.PARAMETER HomeAssistantToken
    Home Assistant long-lived access token.

.PARAMETER MqttHost
    MQTT broker hostname or IP address.

.PARAMETER MqttPort
    MQTT broker port. Defaults to 1883.

.PARAMETER MqttTopic
    MQTT state topic. The package expects home/laptops/p52/battery/state for P52.

.PARAMETER MqttUsername
    Optional MQTT username.

.PARAMETER MqttPassword
    Optional MQTT password.

.PARAMETER MqttPublisherPath
    Path to mosquitto_pub.exe. Defaults to mosquitto_pub.exe from PATH.

.PARAMETER NoMqttRetain
    Publish MQTT telemetry without the retain flag. Retain is recommended.

.PARAMETER NetworkSSID
    Optional network guard. If provided, the script exits without sending data unless
    the active network profile name or active Wi-Fi SSID matches this value.

.PARAMETER SensorAttributes
    Optional JSON object or JSON array of objects merged into the Home Assistant attributes.

.PARAMETER Install
    Installs the script as a scheduled task using PowerShell scheduled task cmdlets.

.PARAMETER EasyInstall
    Installs the script as a scheduled task using XML import. This includes calendar,
    startup, wake-from-sleep, and AC power event triggers.

.EXAMPLE
    .\send-laptop-battery-status.ps1 `
        -MqttHost "homeassistant.local" `
        -MqttTopic "home/laptops/p52/battery/state"

.EXAMPLE
    .\send-laptop-battery-status.ps1 `
        -HomeAssistantURL "http://homeassistant.local:8123" `
        -HomeAssistantSensor "laptop_battery" `
        -HomeAssistantToken "TOKEN" `
        -NetworkSSID "Trusted WiFi" `
        -SensorAttributes '{"state_class":"measurement","battery_alert_disabled":true}'

.EXAMPLE
    .\send-laptop-battery-status.ps1 `
        -Install `
        -MqttHost "homeassistant.local" `
        -MqttTopic "home/laptops/p52/battery/state" `
        -NetworkSSID "Trusted WiFi" `
        -SensorAttributes '{"state_class":"measurement"}'

.REQUIREMENTS
    - Windows PowerShell 5.1 or later
    - mosquitto_pub.exe for MQTT publishing
    - A Home Assistant long-lived access token for REST publishing
    - Administrator privileges for scheduled task installation

.NOTES
    Author: Torsten Juul-Jensen
    Created: January 8, 2025
    Version: 1.7.1
    GPT iteration: 2026-05-31
    Version comment: Publish MQTT JSON from a UTF-8 temp file so PowerShell native
                     argument handling cannot strip JSON quotes.
#>

[CmdletBinding()]
param (
    [string]$HomeAssistantURL,

    [string]$HomeAssistantSensor,

    [string]$HomeAssistantToken,

    [string]$MqttHost,

    [int]$MqttPort = 1883,

    [string]$MqttTopic,

    [string]$MqttUsername,

    [string]$MqttPassword,

    [string]$MqttPublisherPath = 'mosquitto_pub.exe',

    [switch]$NoMqttRetain,

    [string]$NetworkSSID,

    [string]$SensorAttributes,

    [switch]$Install,

    [switch]$EasyInstall
)

function Write-FatalError {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Error $Message
    exit 1
}

function ConvertTo-SingleQuotedPowerShellLiteral {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    return "'" + ($Value -replace "'", "''") + "'"
}

function New-EncodedTaskArguments {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    $scriptLiteral = ConvertTo-SingleQuotedPowerShellLiteral -Value $ScriptPath
    $commandParts = @(
        '&',
        $scriptLiteral
    )

    if (-not [string]::IsNullOrWhiteSpace($HomeAssistantURL)) {
        $commandParts += '-HomeAssistantURL'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $HomeAssistantURL
    }

    if (-not [string]::IsNullOrWhiteSpace($HomeAssistantSensor)) {
        $commandParts += '-HomeAssistantSensor'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $HomeAssistantSensor
    }

    if (-not [string]::IsNullOrWhiteSpace($HomeAssistantToken)) {
        $commandParts += '-HomeAssistantToken'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $HomeAssistantToken
    }

    if (-not [string]::IsNullOrWhiteSpace($MqttHost)) {
        $commandParts += '-MqttHost'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $MqttHost
    }

    if ($MqttPort -ne 1883) {
        $commandParts += '-MqttPort'
        $commandParts += [string]$MqttPort
    }

    if (-not [string]::IsNullOrWhiteSpace($MqttTopic)) {
        $commandParts += '-MqttTopic'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $MqttTopic
    }

    if (-not [string]::IsNullOrWhiteSpace($MqttUsername)) {
        $commandParts += '-MqttUsername'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $MqttUsername
    }

    if (-not [string]::IsNullOrWhiteSpace($MqttPassword)) {
        $commandParts += '-MqttPassword'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $MqttPassword
    }

    if ($MqttPublisherPath -ne 'mosquitto_pub.exe') {
        $commandParts += '-MqttPublisherPath'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $MqttPublisherPath
    }

    if ($NoMqttRetain) {
        $commandParts += '-NoMqttRetain'
    }

    if (-not [string]::IsNullOrWhiteSpace($NetworkSSID)) {
        $commandParts += '-NetworkSSID'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $NetworkSSID
    }

    if (-not [string]::IsNullOrWhiteSpace($SensorAttributes)) {
        $commandParts += '-SensorAttributes'
        $commandParts += ConvertTo-SingleQuotedPowerShellLiteral -Value $SensorAttributes
    }

    $command = $commandParts -join ' '
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

    return "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encodedCommand"
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertFrom-SensorAttributesJson {
    param (
        [string]$Json
    )

    $attributes = [ordered]@{}

    if ([string]::IsNullOrWhiteSpace($Json)) {
        return $attributes
    }

    try {
        $parsed = ConvertFrom-Json -InputObject $Json -ErrorAction Stop
    } catch {
        Write-FatalError "Invalid JSON format for -SensorAttributes: $($_.Exception.Message)"
    }

    $items = @()
    if ($parsed -is [array]) {
        $items = $parsed
    } else {
        $items = @($parsed)
    }

    foreach ($item in $items) {
        if ($null -eq $item -or -not ($item -is [PSCustomObject])) {
            Write-FatalError "-SensorAttributes must be a JSON object or an array of JSON objects."
        }

        foreach ($property in $item.PSObject.Properties) {
            $attributes[$property.Name] = $property.Value
        }
    }

    return $attributes
}

function Get-ActiveWifiSsid {
    try {
        $netshOutput = netsh.exe wlan show interfaces 2>$null
    } catch {
        return $null
    }

    foreach ($line in $netshOutput) {
        if ($line -match '^\s*SSID\s*:\s*(.+?)\s*$' -and $line -notmatch '^\s*BSSID\s*:') {
            return $Matches[1]
        }
    }

    return $null
}

function Test-NetworkMatch {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ExpectedNetworkName
    )

    try {
        $matchingProfile = Get-NetConnectionProfile -ErrorAction Stop | Where-Object {
            $_.IPv4Connectivity -ne 'Disconnected' -and
            -not [string]::IsNullOrWhiteSpace($_.Name) -and
            $_.Name -eq $ExpectedNetworkName
        } | Select-Object -First 1

        if ($matchingProfile) {
            return $true
        }
    } catch {
        Write-Warning "Could not read network profiles: $($_.Exception.Message)"
    }

    $activeSsid = Get-ActiveWifiSsid
    if ($activeSsid -and $activeSsid -eq $ExpectedNetworkName) {
        return $true
    }

    return $false
}

function Convert-BatteryStatusToState {
    param (
        [Parameter(Mandatory = $true)]
        [int[]]$BatteryStatus
    )

    # Win32_Battery BatteryStatus values:
    # 1 = Discharging, 2 = AC/no discharge, 3 = Fully charged,
    # 6/7/8/9 = Charging variants, 11 = Partially charged.
    if ($BatteryStatus | Where-Object { $_ -in @(6, 7, 8, 9) }) {
        return 'charging'
    }

    if ($BatteryStatus | Where-Object { $_ -eq 1 }) {
        return 'discharging'
    }

    if ($BatteryStatus.Count -gt 0 -and -not ($BatteryStatus | Where-Object { $_ -ne 3 })) {
        return 'full'
    }

    if ($BatteryStatus.Count -gt 0 -and -not ($BatteryStatus | Where-Object { $_ -ne 2 })) {
        return 'plugged_in'
    }

    if ($BatteryStatus | Where-Object { $_ -eq 11 }) {
        return 'partially_charged'
    }

    return 'unknown'
}

function Convert-BatteryStateToPowerSource {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BatteryState
    )

    switch ($BatteryState) {
        'discharging' { return 'battery' }
        'charging' { return 'ac' }
        'full' { return 'ac' }
        'plugged_in' { return 'ac' }
        default { return 'unknown' }
    }
}

function Get-ValidRuntimeMinutes {
    param (
        [object[]]$BatteryRecords
    )

    $validRuntimes = @(
        $BatteryRecords |
            Where-Object {
                $null -ne $_.EstimatedRunTime -and
                $_.EstimatedRunTime -ge 0 -and
                $_.EstimatedRunTime -lt 71582788
            } |
            ForEach-Object { [int]$_.EstimatedRunTime }
    )

    if ($validRuntimes.Count -eq 0) {
        return $null
    }

    return ($validRuntimes | Measure-Object -Minimum).Minimum
}

function Get-BatterySnapshot {
    $batteryRecords = @()

    try {
        $batteryRecords = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop)
    } catch {
        try {
            $batteryRecords = @(Get-WmiObject -Class Win32_Battery -ErrorAction Stop)
        } catch {
            Write-FatalError "Battery information is not available: $($_.Exception.Message)"
        }
    }

    if ($batteryRecords.Count -eq 0) {
        return $null
    }

    $validPercentages = @(
        $batteryRecords |
            Where-Object { $null -ne $_.EstimatedChargeRemaining -and $_.EstimatedChargeRemaining -ge 0 } |
            ForEach-Object { [double]$_.EstimatedChargeRemaining }
    )

    if ($validPercentages.Count -eq 0) {
        Write-FatalError "Battery percentage is not available."
    }

    $batteryPercent = [int][Math]::Round(($validPercentages | Measure-Object -Average).Average, 0)
    $statusValues = @($batteryRecords | Where-Object { $null -ne $_.BatteryStatus } | ForEach-Object { [int]$_.BatteryStatus })
    $batteryState = Convert-BatteryStatusToState -BatteryStatus $statusValues
    $powerSource = Convert-BatteryStateToPowerSource -BatteryState $batteryState
    $runtimeMinutes = Get-ValidRuntimeMinutes -BatteryRecords $batteryRecords

    $runtimeText = $null
    if ($null -ne $runtimeMinutes) {
        $runtimeText = "$runtimeMinutes minutes"
    }

    return [ordered]@{
        charge_percent = $batteryPercent
        battery_state = $batteryState
        battery_state_raw = ($statusValues -join ',')
        battery_status_values = $statusValues
        time_remaining = $runtimeMinutes
        time_remaining_text = $runtimeText
        power_source = $powerSource
        battery_count = $batteryRecords.Count
    }
}

function New-BatteryAttributes {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BatteryData,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$AdditionalAttributes
    )

    $attributes = [ordered]@{
        status = $BatteryData.battery_state
        battery_state = $BatteryData.battery_state
        battery_state_raw = $BatteryData.battery_state_raw
        battery_status_values = $BatteryData.battery_status_values
        battery_percent = $BatteryData.charge_percent
        time_remaining = $BatteryData.time_remaining
        time_remaining_minutes = $BatteryData.time_remaining
        time_remaining_text = $BatteryData.time_remaining_text
        power_source = $BatteryData.power_source
        source = 'win32_battery'
        battery_count = $BatteryData.battery_count
        device_class = 'battery'
        state_class = 'measurement'
        unit_of_measurement = '%'
    }

    foreach ($key in $AdditionalAttributes.Keys) {
        $attributes[$key] = $AdditionalAttributes[$key]
    }

    return $attributes
}

function Send-DataToHomeAssistant {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BatteryData,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$AdditionalAttributes
    )

    $headers = @{
        Authorization = "Bearer $HomeAssistantToken"
        'Content-Type' = 'application/json'
    }

    $attributes = New-BatteryAttributes -BatteryData $BatteryData -AdditionalAttributes $AdditionalAttributes

    $body = [ordered]@{
        state = $BatteryData.charge_percent
        attributes = $attributes
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod `
            -Uri $HomeAssistantAPIURL `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 30 `
            -ErrorAction Stop | Out-Null

        Write-Output "Battery data sent to Home Assistant successfully."
    } catch {
        Write-FatalError "Failed to send data to Home Assistant: $($_.Exception.Message)"
    }
}

function Publish-DataToMqtt {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BatteryData,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$AdditionalAttributes
    )

    $payload = New-BatteryAttributes -BatteryData $BatteryData -AdditionalAttributes $AdditionalAttributes
    $payload['state'] = $BatteryData.charge_percent
    $body = $payload | ConvertTo-Json -Depth 10 -Compress
    $payloadPath = [IO.Path]::GetTempFileName()
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($payloadPath, $body, $utf8NoBom)

    $arguments = @(
        '-h', $MqttHost,
        '-p', [string]$MqttPort,
        '-t', $MqttTopic,
        '-f', $payloadPath
    )

    if (-not $NoMqttRetain) {
        $arguments += '-r'
    }

    if (-not [string]::IsNullOrWhiteSpace($MqttUsername)) {
        $arguments += '-u'
        $arguments += $MqttUsername
    }

    if (-not [string]::IsNullOrWhiteSpace($MqttPassword)) {
        $arguments += '-P'
        $arguments += $MqttPassword
    }

    try {
        & $MqttPublisherPath @arguments
        if ($LASTEXITCODE -ne 0) {
            Write-FatalError "mosquitto_pub failed with exit code $LASTEXITCODE."
        }

        Write-Output "Battery data published to MQTT successfully."
    } catch {
        Write-FatalError "Failed to publish data to MQTT: $($_.Exception.Message)"
    } finally {
        Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue
    }
}

function Install-ScheduledTaskClassic {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    if (-not (Test-IsAdministrator)) {
        Write-FatalError "Administrator privileges are required to install the scheduled task."
    }

    Write-Output "Starting scheduled task installation..."
    Write-Output "Configuration:"
    Write-Output "- Script Path: $ScriptPath"
    Write-Output "- Home Assistant URL: $HomeAssistantURL"
    Write-Output "- Sensor: $HomeAssistantSensor"
    Write-Output "- Network SSID guard: $NetworkSSID"
    Write-Output "- Additional Attributes: $SensorAttributes"

    $confirmation = Read-Host "Do you want to proceed with this configuration? (yes/no)"
    if ($confirmation -ne 'yes') {
        Write-Output "Installation cancelled by user."
        return
    }

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable

    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At 00:00
    $repeatTrigger = New-ScheduledTaskTrigger -Once -At 00:00 `
        -RepetitionInterval (New-TimeSpan -Minutes 5) `
        -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 55)

    $dailyTrigger.Repetition = $repeatTrigger.Repetition

    $startupTrigger = New-ScheduledTaskTrigger -AtStartup
    $triggers = @(
        $startupTrigger
        $dailyTrigger
    )

    $arguments = New-EncodedTaskArguments -ScriptPath $ScriptPath
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments

    try {
        Register-ScheduledTask `
            -TaskName 'Send Battery Data to Home Assistant' `
            -Action $action `
            -Trigger $triggers `
            -Settings $settings `
            -Description 'Send battery data to Home Assistant every 5 minutes.' `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Output "Scheduled task created successfully."
    } catch {
        Write-FatalError "Failed to create the scheduled task: $($_.Exception.Message)"
    }
}

function Install-ScheduledTaskEasy {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    if (-not (Test-IsAdministrator)) {
        Write-FatalError "Administrator privileges are required to install the scheduled task."
    }

    Write-Output "Starting scheduled task installation..."

    $taskName = 'Send Battery Data to Home Assistant'
    $taskDescription = 'Send battery data to Home Assistant automatically.'
    $taskArguments = New-EncodedTaskArguments -ScriptPath $ScriptPath
    $startBoundary = Get-Date -Format 'yyyy-MM-ddT00:00:00'

    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$taskDescription</Description>
    <URI>\$taskName</URI>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
        <Duration>P1D</Duration>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[(EventID=105)]] and *[System[Provider[@Name="Microsoft-Windows-Kernel-Power"]]] and *[EventData[Data[@Name="AcOnline"] and (Data='false')]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[(EventID=105)]] and *[System[Provider[@Name="Microsoft-Windows-Kernel-Power"]]] and *[EventData[Data[@Name="AcOnline"] and (Data='true')]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <LogonType>ServiceAccount</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <Priority>7</Priority>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>$taskArguments</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    $taskXmlPath = Join-Path -Path $env:TEMP -ChildPath 'BatteryTask.xml'
    $taskXml | Out-File -FilePath $taskXmlPath -Encoding Unicode

    try {
        & schtasks.exe /Create /TN $taskName /XML $taskXmlPath /F
        if ($LASTEXITCODE -ne 0) {
            Write-FatalError "schtasks.exe failed with exit code $LASTEXITCODE."
        }

        Write-Output "Scheduled task created successfully."
    } catch {
        Write-FatalError "Failed to create the scheduled task: $($_.Exception.Message)"
    } finally {
        Remove-Item -Path $taskXmlPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not [string]::IsNullOrWhiteSpace($HomeAssistantSensor) -and -not $HomeAssistantSensor.StartsWith('sensor.')) {
    $HomeAssistantSensor = "sensor.$HomeAssistantSensor"
}

$useRest = -not [string]::IsNullOrWhiteSpace($HomeAssistantURL) -or
    -not [string]::IsNullOrWhiteSpace($HomeAssistantSensor) -or
    -not [string]::IsNullOrWhiteSpace($HomeAssistantToken)
$useMqtt = -not [string]::IsNullOrWhiteSpace($MqttHost) -or
    -not [string]::IsNullOrWhiteSpace($MqttTopic)

if (-not $useRest -and -not $useMqtt) {
    Write-FatalError "Configure either MQTT (-MqttHost and -MqttTopic) or REST (-HomeAssistantURL, -HomeAssistantSensor, and -HomeAssistantToken)."
}

if ($useRest) {
    if ([string]::IsNullOrWhiteSpace($HomeAssistantURL) -or
        [string]::IsNullOrWhiteSpace($HomeAssistantSensor) -or
        [string]::IsNullOrWhiteSpace($HomeAssistantToken)) {
        Write-FatalError "REST publishing requires -HomeAssistantURL, -HomeAssistantSensor, and -HomeAssistantToken."
    }

    $HomeAssistantURL = $HomeAssistantURL.TrimEnd('/')
    $HomeAssistantAPIURL = "$HomeAssistantURL/api/states/$HomeAssistantSensor"
}

if ($useMqtt -and ([string]::IsNullOrWhiteSpace($MqttHost) -or [string]::IsNullOrWhiteSpace($MqttTopic))) {
    Write-FatalError "MQTT publishing requires -MqttHost and -MqttTopic."
}

$additionalAttributes = ConvertFrom-SensorAttributesJson -Json $SensorAttributes

if ($EasyInstall) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Install-ScheduledTaskEasy -ScriptPath $scriptPath
    return
}

if ($Install) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Install-ScheduledTaskClassic -ScriptPath $scriptPath
    return
}

if (-not [string]::IsNullOrWhiteSpace($NetworkSSID)) {
    if (-not (Test-NetworkMatch -ExpectedNetworkName $NetworkSSID)) {
        Write-Output "Not connected to SSID or network profile '$NetworkSSID'. Exiting."
        return
    }
}

$batteryData = Get-BatterySnapshot
if ($null -eq $batteryData) {
    Write-Output "Battery information is not available."
    return
}

if ($useMqtt) {
    Publish-DataToMqtt -BatteryData $batteryData -AdditionalAttributes $additionalAttributes
}

if ($useRest) {
    Send-DataToHomeAssistant -BatteryData $batteryData -AdditionalAttributes $additionalAttributes
}
