<#
.SYNOPSIS
    A PowerShell script to send battery status from a Windows PC to a Home Assistant instance.

.DESCRIPTION
    This script retrieves battery status information such as charge percentage, battery_state (charging/discharging), 
    and estimated runtime. It sends the data to a Home Assistant instance using its API.

    The script can also install itself as a scheduled task to run periodically or based on specific triggers.

.PARAMETER HomeAssistantURL
    [Required] The URL of the Home Assistant server. 
    Example: "http://homeassistant.local:8123" or "https://homeassistant.local:8123".

.PARAMETER HomeAssistantSensor
    [Required] The name of the sensor to update in Home Assistant. 
    Example: "sensor.laptop_battery". If entered without "sensor.", the prefix will be added automatically.

.PARAMETER HomeAssistantToken
    [Required] A long-lived access token generated in Home Assistant. 
    This token is used for authenticating API requests.

.PARAMETER NetworkSSID
    [Optional] The SSID of the Wi-Fi network to validate before sending battery data. 
    If provided, the script will only execute when connected to the specified SSID.

.PARAMETER SensorAttributes
    [Optional] One or more additional attributes to include with the sensor update. Added as list of JSON key-value. 
    Each attribute should be specified as a key-value pair. Please notice that when parsing from Powershell command line
    there are strict rules for interpretation of the content. 
    The list of JSON elements here: [{"battery_alert_disabled": true}, {"state_class": "measurement"}}
    would be required to be entered on the command line like this:
    '[{"""battery_alert_disabled""": true}, {"""state_class""": """measurement"""}}'
    
.PARAMETER Install
    [Optional] If specified, the script will install itself as a scheduled task running every 5 minutes and at startup. 
    Additional triggers (e.g., event-based) must be added manually in Task Scheduler.

.EXAMPLE
    Run the script to send battery data directly to Home Assistant:
    .\Send-BatteryStatus.ps1 -HomeAssistantURL "http://homeassistant.local:8123" `
    -HomeAssistantSensor "sensor.laptop_battery" `
    -HomeAssistantToken "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." `
    -SensorAttributes "[{"""battery_alert_disabled""" : true}, {"""device_class""" : """battery""" },{"""state_class""" : """measurement"""}]"

.EXAMPLE
    Install the script as a scheduled task:
    .\Send-BatteryStatus.ps1 -Install `
    -HomeAssistantURL "http://homeassistant.local:8123" `
    -HomeAssistantSensor "sensor.laptop_battery" `
    -HomeAssistantToken "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

.NOTES
    Author: Torsten Juul-Jensen
    Created: January 8, 2025
    Version: 1.5.2
    Version comment: EasyInstall option added. Uses temporary XML file to create a complete Scheduled Task with all triggers. Header updated.

    IMPORTANT note on installation! 
        There are two (!) ways of installing the script - Install and EasyInstall. 
        Read carefully and select your preferred one.

    Using the -EasyInstall option:
        Using EasyInstall is the  recommended for inexperienced users. If you don't know how to create a new account on your windows machine and configure it to run 
        as a service account, select EasyInstall! 
        Please notice that selecting this, it makes the script run as SYSTEM which is a high privilege account and is not recommended for security reasons. 
        It is STRONGLY RECOMMENDED to edit the scheduled task after a successful install and only allow it to run when located on your local WiFi/network:
        Open Task Scheduler and select **Conditions/Network** 
            - Check 'Start only if the following network connection is available' and select the network on which you want the script to run.

    Using the Install option:
        If using the -Install option, you should configure custom triggers in Task Scheduler (e.g., event-based triggers), as described here.
        - After task scheduler installation, you should edit the following in the Windows task scheduler user interface:
        - **Security options:** Enable 'Run whether user is logged on or not'. This will ensure that the execution window runs hidden.
        - **Conditions/Network:** Check 'Start only if the following network connection is available' and select the network on which you want the script to run.
        - **Triggers:** Add an 'On an event' trigger (Log: System, Source: Power-Troubleshooter, Event ID: 1). Triggers on resume from sleep.
        - **Triggers:** Add an 'On an event' trigger (Custom, New event filter, XML). Add the following XML which will trigger when AC power is disconnected:
            ```
            <QueryList>
                <Query Id="0" Path="System">
                    <Select Path="System">*[System[(EventID=105)]] and *[System[Provider[@Name="Microsoft-Windows-Kernel-Power"]]] and *[EventData[Data[@Name="AcOnline"] and (Data='false')]]</Select>
                </Query>
            </QueryList>
            ```
        - Add another custom XML trigger like above, but change `Data='false'` to `Data='true'`. Triggers when AC power is connected.

        
    IMPORTANT note on adding JSON parameters on command line!
        - Additional attributes can be passed via `-SensorAttributes` as JSON are included as key-value pairs in the sensor update payload.
        - Parsing JSON to PowerShell scripts **can be tricky**
          **This format works** when calling the script with -File (notice the single quotes encapsulating the JSON):
                '[{"""battery_alert_disabled""" : true}, {"""device_class""" : """battery""" },{"""state_class""" : """measurement"""}]'
          Other formats might work, but it is a pain to figure the correct syntax.
        - The JSON format above does NOT work when calling the .ps1 directly! (like if you enter .\Send-LaptopBatteryStatus.ps1 from command line).
        - You should use the -File option when calling the script with JSON parameters. Yes, I know I said it twice - But it is highly likely that it fails if you don't'...


.REQUIREMENTS
    - PowerShell 5.1 or later
    - A long-lived access token generated in Home Assistant
    - Administrator privileges (for installing scheduled tasks)
    - A sensor in Home Assistant made for the device. Use the following template to generate a template sensor:
      ```
        - sensor:
            - name: "Laptop Battery"
                unique_id: "laptop_battery"
                state: "{{ this.state }}"
                device_class: battery
                state_class: measurement
                unit_of_measurement: "%"
                attributes:
                status: "{{ this.attributes.status }}"
                battery_state: "{{ this.attributes.battery_state }}"
                time_remaining: "{{ this.attributes.time_remaining }}"  
      ```

.LINK
    For more details on Home Assistant long-lived access tokens:
    https://www.home-assistant.io/docs/authentication/
#>

# Main script for sending battery data or installing as a scheduled task
param (
    [Parameter(Mandatory=$true)]
    [string]$HomeAssistantURL,           # Required: Base URL of the Home Assistant server
    [Parameter(Mandatory=$true)]
    [string]$HomeAssistantSensor,        # Required: Name of the sensor to update
    [Parameter(Mandatory=$true)]
    [string]$HomeAssistantToken,         # Required: Home Assistant Access Token
    [string]$NetworkSSID,                # Optional: SSID for Wi-Fi validation
    [string]$SensorAttributes,           # Optional: Additional attributes for the sensor in JSON format (read .NOTES regarding parsing JSON to powershell!)
    [switch]$Install,                    # Optional: Installs the script as a scheduled task
    [switch]$EasyInstall                 # Optional: Installs the script as a scheduled task using the full trigger via XML import
)

# Ensure HomeAssistantSensor is prefixed with "sensor."
if (-not $HomeAssistantSensor.StartsWith("sensor.")) {
    $HomeAssistantSensor = "sensor.$HomeAssistantSensor"
}

# Ensure HomeAssistantURL does not have a trailing slash
if ($HomeAssistantURL.EndsWith("/")) {
    $HomeAssistantURL = $HomeAssistantURL.TrimEnd("/")
}

# Construct the full API URL
$HomeAssistantAPIURL = "$HomeAssistantURL/api/states/$HomeAssistantSensor"

# Parse SensorAttribute as JSON
$additionalAttributes = @{}
if ($SensorAttributes) {
    try {
        $additionalAttributes = ConvertFrom-Json -InputObject $SensorAttributes
    } catch {
        Write-Error "Invalid JSON format for -SensorAttribute: $_"
        return
    }
}   

# Function to detect active network connections
function Get-NetworkConnections {
    $connections = Get-NetConnectionProfile | Where-Object {
        $_.IPv4Connectivity -ne "Disconnected" -and
        -not [string]::IsNullOrWhiteSpace($_.Name)
    }
    return $connections
}

# Function to send data to Home Assistant
function Send-DataToHomeAssistant($data) {
    $headers = @{
        "Authorization" = "Bearer $HomeAssistantToken"
        "Content-Type" = "application/json"
    }
    # Merge additional attributes with the default attributes
    $attributes = @{
        "status" = $data.status
        "time_remaining" = $data.time_remaining
        "battery_state" = $data.battery_state
        "device_class" = "battery"
        "unit_of_measurement" = "%"
    } 
    
    # Add additional attributes
    foreach ($entry in $additionalAttributes) {
        if ($entry -is [PSCustomObject]) {
            $entry.PSObject.Properties | ForEach-Object {
                $attributes[$_.Name] = $_.Value
            }
        } else {
            Write-Warning "Skipping entry: Not a valid PSCustomObject"
        }
    }

    $body = @{
        "state" = $data.charge_percent
        "attributes" = $attributes
    } | ConvertTo-Json -Depth 10


    try {
        Invoke-RestMethod -Uri $HomeAssistantAPIURL -Method POST -Headers $headers -Body $body
        Write-Output "Battery data sent to Home Assistant successfully."
    } catch {
        Write-Error "Failed to send data to Home Assistant: $_"
    }
}

# Function to install the script as a scheduled task
function Install-ScheduledTask {
    param (
        [string]$ScriptPath
    )

    Write-Output "Starting scheduled task installation..."

    # Confirm configuration
    Write-Output "You have chosen the following configuration:"
    Write-Output "- Script Path: $ScriptPath"
    Write-Output "- Home Assistant URL: $HomeAssistantURL"
    Write-Output "- Sensor: $HomeAssistantSensor"
    Write-Output "- Additional Attributes: $SensorAttributes"
    $confirmation = Read-Host "Do you want to proceed with this configuration? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Output "Installation cancelled by user."
        return
    }

    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable

    # Define the repeating trigger: Daily at midnight, repeats every 5 minutes for 24 hours
    # Using this two-step approach is a workaround as PowerShell cannot create a daily trigger with 5 minute repetition intervals.
    $dailyTrigger = New-ScheduledTaskTrigger -Daily -At 00:00
    $tempTrigger = New-ScheduledTaskTrigger -Once -At 00:00 `
        -RepetitionInterval (New-TimeSpan -Minutes 5) `
        -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 55)

    $dailyTrigger.Repetition = $tempTrigger.Repetition

    # Other task triggers 
    $additionalTriggers = @(
        New-ScheduledTaskTrigger -AtStartup
    )

    # Combine all triggers
    $triggers = $AdditionalTriggers + $dailyTrigger

    # Task action
    $SensorAttributes = $SensorAttributes.Replace('"','"""') # Replae to match JSON requirements from command line
    $arguments = "-WindowStyle hidden -File `"$ScriptPath`" -HomeAssistantURL `"$HomeAssistantURL`" -HomeAssistantSensor `"$HomeAssistantSensor`" -HomeAssistantToken `"$HomeAssistantToken`" -SensorAttributes `"$SensorAttributes`""
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments

    # Register the task
    try {
        Register-ScheduledTask -TaskName "Send Battery Data to Home Assistant" `
                               -Action $action `
                               -Trigger $triggers `
                               -Settings $settings `
                               -Description "Send battery data to Home Assistant every 5 minutes."
        Write-Output "Scheduled task created successfully."
        Write-Output "IMPORTANT: Update Task Scheduler settings as described in the script header."
    } catch {
        Write-Error "Failed to create the scheduled task: $_"
        return
    }
}

function Install-ScheduledTaskEasy {
    param (
        [string]$ScriptPath
    )

    Write-Output "Starting scheduled task installation..."

    # Task details
    $TaskName = "Send Battery Data to Home Assistant"
    $TaskDescription = "Send battery data to Home Assistant automatically."

    # Ensure necessary privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "Administrator privileges are required to install the task."
        return
    }

    # Define the PowerShell execution arguments
    $SensorAttributes = $SensorAttributes.Replace('"','"""') # Escape double-quotes for JSON handling
    $TaskArguments = "-WindowStyle hidden -File `"$ScriptPath`" -HomeAssistantURL `"$HomeAssistantURL`" -HomeAssistantSensor `"$HomeAssistantSensor`" -HomeAssistantToken `"$HomeAssistantToken`" -SensorAttributes `"$SensorAttributes`""

    # Generate XML content dynamically for complex triggers
    $TaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$TaskDescription</Description>
    <URI>\$TaskName</URI>
  </RegistrationInfo>
  <Triggers>
    <!-- Runs the script every 5 minutes -->
    <CalendarTrigger>
      <Repetition>
        <Interval>PT5M</Interval>
        <Duration>P1D</Duration>
        <StopAtDurationEnd>true</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$(Get-Date -Format "yyyy-MM-ddT00:00:00")</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
    <!-- Runs on startup -->
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
    <!-- Runs when waking from sleep -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <!-- Runs when AC power is disconnected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[(EventID=105)]] and *[System[Provider[@Name="Microsoft-Windows-Kernel-Power"]]] and *[EventData[Data[@Name="AcOnline"] and (Data='false')]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <!-- Runs when AC power is reconnected -->
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[(EventID=105)]] and *[System[Provider[@Name="Microsoft-Windows-Kernel-Power"]]] and *[EventData[Data[@Name="AcOnline"] and (Data='true')]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>SYSTEM</UserId>
      <LogonType>Password</LogonType>
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
      <Arguments>$TaskArguments</Arguments>
    </Exec>
  </Actions>
</Task>
"@

    # Save the XML file temporarily - encoded as UTF16 Little Endian as schtasks only accepts this 
    $TaskXmlPath = "$env:TEMP\BatteryTask.xml"
    $TaskXml | Out-File -FilePath $TaskXmlPath -Encoding Unicode

    try {
        # Register the task using schtasks
        schtasks /Create /TN "$TaskName" /XML "$TaskXmlPath" /F
       
        Write-Output "Scheduled task created successfully."
        Write-Output "IMPORTANT: The script is now fully automated with event-based triggers."
    } catch {
        Write-Error "Failed to create the scheduled task: $_"
    } finally {
        # Cleanup the temporary XML file
        Remove-Item -Path $TaskXmlPath -Force -ErrorAction SilentlyContinue
    }
}


# Main Execution Logic
if ($EasyInstall) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Install-ScheduledTaskEasy -ScriptPath $scriptPath
    return
}
elseif ($Install) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Install-ScheduledTask -ScriptPath $scriptPath
    return
}

# Validate the network connection only if NetworkSSID is provided
if ($PSBoundParameters.ContainsKey('NetworkSSID') -and $NetworkSSID) {
    $SSID = Get-NetConnectionProfile | Where-Object { $_.Name -eq $NetworkSSID }
    if (-not $SSID) {
        Write-Output "Not connected to SSID '$NetworkSSID'. Exiting."
        return
    }
}

$batteryData = Get-WmiObject -Class Win32_Battery | Select-Object BatteryStatus, EstimatedChargeRemaining, EstimatedRunTime
if ($batteryData) {
    $battery_state = switch ($batteryData.BatteryStatus) {
        1 { "discharging" }
        2 { "charging" }
        default { "unknown" }
    }
    Send-DataToHomeAssistant @{
        status = $batteryData.BatteryStatus
        battery_state = $battery_state
        charge_percent = $batteryData.EstimatedChargeRemaining
        time_remaining = $batteryData.EstimatedRunTime
    }
} else {
    Write-Output "Battery information is not available."
}
