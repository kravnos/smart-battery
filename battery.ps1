# Check for kill switch
param([string]$kill = $null)

# Default configuration values
$defaultConfig = @"
[Settings]
BATTERY_HIGH=85
BATTERY_LOW=15
BATTERY_VARIANCE=5
tokenExpiry=10
idExpiry=17
loopTime=600
wifiName=SSID
deviceName=DEVICENAME
userName=email@domain.com
password=password
countryCode=us
bizType=smart_life
from=tuya
"@

# Path to the configuration file
$configFile = "config.ini"

# Function to log messages with timestamp
function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "[yyyy-MM-dd] [HH:mm]"
    Write-Host "$timestamp $message"

    if ($message -like "Error:*") {
        Exit 1
    }
}

# Function to create the default config file
function Create-DefaultConfig {
    $defaultConfig | Out-File -FilePath $configFile -Encoding utf8 -Force
    Log-Message "Success: Configuration file wrote to $configFile."
}

# Check if the config file exists
if (-not (Test-Path $configFile)) {
    Create-DefaultConfig
}

# Function to read configuration values from INI file
function Get-ConfigValue {
    param([string]$key)
    
    $section = "Settings"
    
    $regex = [regex]::new("^\s*$key\s*=\s*(.*?)\s*$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    $found = $false
    $value = $null

    $content = Get-Content $configFile

    foreach ($line in $content) {
        if ($line -match "^\s*\[$section\]\s*$") {
            $found = $true
        } elseif ($found -and $line -match $regex) {
            $value = $matches[1]
            break
        }
    }

    return $value
}

# Read values from the config file
$BATTERY_HIGH = [int](Get-ConfigValue "BATTERY_HIGH")
$BATTERY_LOW = [int](Get-ConfigValue "BATTERY_LOW")
$BATTERY_VARIANCE = [int](Get-ConfigValue "BATTERY_VARIANCE")
$tokenExpiry = [int](Get-ConfigValue "tokenExpiry")
$idExpiry = [int](Get-ConfigValue "idExpiry")
$loopTime = [int](Get-ConfigValue "loopTime")
$wifiName = Get-ConfigValue "wifiName"
$deviceName = Get-ConfigValue "deviceName"
$userName = Get-ConfigValue "userName"
$password = Get-ConfigValue "password"
$countryCode = Get-ConfigValue "countryCode"
$bizType = Get-ConfigValue "bizType"
$from = Get-ConfigValue "from"
$baseURL = "https://px1.tuya$countryCode.com/homeassistant"
$tokenFile = "battery_token.txt"
$idFile = "battery_id.txt"
$tokenCache = $null
$idCache = $null
$curDate = Get-Date
$randomVariance = Get-Random -Minimum -$BATTERY_VARIANCE -Maximum ($BATTERY_VARIANCE + 1)

# Check if default values are valid
if (($BATTERY_HIGH -le $BATTERY_LOW) -or (($BATTERY_HIGH + $BATTERY_VARIANCE) -gt 100) -or (($BATTERY_LOW - $BATTERY_VARIANCE) -le 5)) {
    Log-Message "Error: Invalid values for BATTERY_HIGH, BATTERY_LOW or BATTERY_VARIANCE."
}

# Check if system returns any battery percentage
$battery = Get-WmiObject Win32_Battery
if (-not $battery) {
    Log-Message "Error: No battery detected."
}

# Check if script is already running
if ([string]::IsNullOrWhiteSpace($kill)) {
    $scriptName = $MyInvocation.MyCommand.Name
    $running = Get-WmiObject Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object { $_.CommandLine -like "*$scriptName*" }
    if ($running.Count -gt 1) {
        Log-Message "Error: Script is already running."
    }
}

# Function to request and save token
function Request-Token {
    # Define the URL and body for the POST request
    $url = "$baseURL/auth.do"
    $body = @{
        userName = $userName
        password = $password
        countryCode = $countryCode
        bizType = $bizType
        from = $from
    }
    $headers = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    # Make the POST request
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers
        
        if ($response.access_token) {
            # Success response
            $response.access_token | Out-File $tokenFile -Force
            Log-Message "Success: Access token wrote to $tokenFile."
        } elseif ($response.responseStatus -eq "error") {
            # Fail response
            Log-Message "Error: $($response.errorMsg)"
        } else {
            Log-Message "Error: Unexpected response.`n`n$($response | ConvertTo-Json)"
        }
    } catch {
        Log-Message "Error: Failed to request access token. $_"
    }
}

# Function to request and save device id
function Request-DeviceID {
    param([string]$accessToken)

    # Define the URL for the POST request
    $url = "$baseURL/skill"

    # Define the body for the request in JSON format
    $body = @{
        header = @{
            name = "Discovery"
            namespace = "discovery"
            payloadVersion = 1
        }
        payload = @{
            accessToken = $accessToken
        }
    } | ConvertTo-Json
    $headers = @{
        "Content-Type" = "application/json"
    }

    # Make the POST request
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers
        
        if ($response.header.code -eq "SUCCESS" -and $response.payload.devices) {
            # Success response, extract the ID for the device name
            $device = $response.payload.devices | Where-Object { $_.name -eq $deviceName }
            if ($device) {
                $deviceID = $device.id
                $deviceID | Out-File $idFile -Force
                Log-Message "Success: Device ID wrote to $idFile."
            } else {
                Log-Message "Error: Device not found in the response."
            }
        } elseif ($response.header.code -eq "InvalidAccessTokenError") {
            Log-Message "Error: Invalid access token."
        } elseif ($response.header.code -eq "FrequentlyInvoke") {
            Log-Message "Error: Discovery frequently invoked."
        } else {
            Log-Message "Error: Unexpected response.`n`n$($response | ConvertTo-Json)"
        }
    } catch {
        Log-Message "Error: Failed to request device ID. $_"
    }
}

# Function to ensure token and device ID are not expired
function TokenAndDeviceID {
    # Ensure token is valid
    if (-not (Test-Path $tokenFile) -or ((Get-Date) -gt (Get-Item $tokenFile).LastWriteTime.AddDays($tokenExpiry))) {
        $tokenCache = $null

        Request-Token
    }

    if (-not $tokenCache) {
        if (Test-Path $tokenFile) {
            $tokenCache = Get-Content $tokenFile

            # Check if the token is valid
            if (-not [string]::IsNullOrWhiteSpace($tokenCache)) {
                Log-Message "Success: Access token read from $tokenFile."
            } else {
                Log-Message "Error: Access token is empty or invalid."
            }
        } else {
            Log-Message "Error: Token file does not exist."
        }
    } else {
        Log-Message "Success: Access token read from cache."
    }

    # Ensure device ID is valid
    if (-not (Test-Path $idFile) -or (((Get-Date) -gt (Get-Item $idFile).LastWriteTime.AddMinutes($idExpiry)) -and (($curDate) -gt (Get-Item $idFile).LastWriteTime))) {
        $idCache = $null

        Request-DeviceID -accessToken $tokenCache
    }

    if (-not $idCache) {
        if (Test-Path $idFile) {
            $idCache = Get-Content $idFile

            # Check if the device ID is valid
            if (-not [string]::IsNullOrWhiteSpace($idCache)) {
                Log-Message "Success: Device ID read from $idFile."
            } else {
                Log-Message "Error: Device ID is empty or invalid."
            }
        } else {
            Log-Message "Error: Device ID file does not exist."
        }
    } else {
        Log-Message "Success: Device ID read from cache."
    }

    return @($tokenCache, $idCache)
}

# Function to turn device on or off
function Action-Device {
    param(
        [string]$accessToken,
        [string]$deviceID,
        [int]$value
    )

    # Define the URL for the POST request
    $url = "$baseURL/skill"

    # Define the body for the request in JSON format
    $body = @{
        header = @{
            name = "turnOnOff"
            namespace = "control"
            payloadVersion = 1
        }
        payload = @{
            accessToken = $accessToken
            devId = $deviceID
            value = $value
        }
    } | ConvertTo-Json
    $headers = @{
        "Content-Type" = "application/json"
    }

    # Make the POST request
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -Headers $headers
        
        if ($response.header.code -eq "SUCCESS") {
            # Success response
            $action = if ($value -eq 0) { "off" } else { "on" }
            Log-Message "Success: Device $deviceName turned $action."
        } elseif ($response.header.code -eq "NoSuchTarget") {
            Log-Message "Error: Device $deviceName not found."
        } elseif ($response.header.code -eq "TargetOffline") {
            Log-Message "Error: Device $deviceName is offline."
        } else {
            Log-Message "Error: Unexpected response.`n`n$($response | ConvertTo-Json)"
        }
    } catch {
        Log-Message "Error: Failed to execute device action. $_"
    }
}

# Turn off the device with kill parameter
if (-not [string]::IsNullOrWhiteSpace($kill)) {
    $wifiSSID = (Get-NetConnectionProfile).Name
    Log-Message "Warning: Sleep or shutdown event detected."

    if ($wifiSSID -like "*$wifiName*") {
        $battery = Get-WmiObject Win32_Battery
        $pluggedIn = $battery.BatteryStatus -eq 2

        if ($pluggedIn) {
            if ($curDate -lt (Get-Date).AddSeconds(2)) {
                $result = TokenAndDeviceID
                $token = $result[0]
                $deviceID = $result[1]
                Action-Device -accessToken $token -deviceID $deviceID -value 0
                Start-Sleep -Seconds 2
            } else {
                Log-Message "Warning: Device action was interrupted."
            }
        } else {
            Log-Message "Warning: No device action required."
        }
    } else {
        Log-Message "Warning: Not connected to $wifiName Wi-Fi."
    }

    # Close PowerShell
    Exit
}

# Main loop
while ($true) {
    # Check if connected to local Wi-Fi (SSID contains $wifiName)
    $wifiSSID = (Get-NetConnectionProfile).Name
    if (-not ($wifiSSID -like "*$wifiName*")) {
        Log-Message "Warning: Not connected to $wifiName Wi-Fi."
        Start-Sleep -Seconds $loopTime
        continue
    }

    $battery = Get-WmiObject Win32_Battery
    $batteryPercent = [int]$battery.EstimatedChargeRemaining
    $pluggedIn = $battery.BatteryStatus -eq 2
    $polarity = if ($pluggedIn) { "++" } else { "--" }
    Log-Message "Battery: $batteryPercent$polarity"

    if ($batteryPercent -ge ($BATTERY_HIGH + $randomVariance) -and $pluggedIn) {
        # Ensure token and device ID are up to date
        $result = TokenAndDeviceID
        $token = $result[0]
        $deviceID = $result[1]

        # Turn off the device
        Action-Device -accessToken $token -deviceID $deviceID -value 0
    } elseif ($batteryPercent -le ($BATTERY_LOW + $randomVariance) -and -not $pluggedIn) {
        # Ensure token and device ID are up to date
        $result = TokenAndDeviceID
        $token = $result[0]
        $deviceID = $result[1]

        # Turn on the device
        Action-Device -accessToken $token -deviceID $deviceID -value 1
    }

    Start-Sleep -Seconds $loopTime
}

# Close PowerShell
Exit