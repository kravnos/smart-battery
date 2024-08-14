# Get the current directory where the script is running
$currentDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Path to the INI file
$iniFile = Join-Path -Path $env:WINDIR -ChildPath "System32\GroupPolicy\Machine\Scripts\scripts.ini"

# Paths to the XML files
$task1XML = "BATTERY.XML"
$task2XML = "BATTERY-SLEEP.XML"

# Function to update XML files
function Update-TaskXML {
    param (
        [string]$xmlPath,
        [string]$currentDir,
        [int]$sleepTimeoutMinutes
    )

    if (-not (Test-Path $xmlPath)) {
        Write-Host "Error: File $xmlPath not found."
        exit 1
    }

    # Load the XML file
    [xml]$xml = Get-Content $xmlPath

    # Define the XML namespace
    $namespace = "http://schemas.microsoft.com/windows/2004/02/mit/task"
    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $namespaceManager.AddNamespace("ns", $namespace)

    $execNodes = $xml.SelectNodes("//ns:Exec/ns:Command", $namespaceManager)
    foreach ($node in $execNodes) {
        $fileName = [System.IO.Path]::GetFileName($node.InnerText)
        $node.InnerText = Join-Path -Path $currentDir -ChildPath $fileName
    }

    $workingDirNodes = $xml.SelectNodes("//ns:Exec/ns:WorkingDirectory", $namespaceManager)
    foreach ($node in $workingDirNodes) {
        $node.InnerText = $currentDir
    }

    if ($xmlPath -eq $task2XML) {
        $durationNode = $xml.SelectNodes("//ns:IdleSettings/ns:Duration", $namespaceManager)
        foreach ($node in $durationNode) {
            $newDuration = "PT${sleepTimeoutMinutes}M"
            $node.InnerText = $newDuration
        }

        $idleTriggerEnabledNode = $xml.SelectNodes("//ns:Triggers/ns:IdleTrigger/ns:Enabled", $namespaceManager)
        foreach ($node in $idleTriggerEnabledNode) {
            if ($sleepTimeoutMinutes -gt 0) {
                $node.InnerText = "true"
            } else {
                $node.InnerText = "false"
            }
        }
    }

    # Save the updated XML
    $xml.Save($xmlPath)
    Write-Host "Success: Updated $xmlPath."
}

# Function to get the sleep timeout value
function Get-SleepTimeout {
    # Run the powercfg command and capture its output
    $powercfgOutput = powercfg /query SCHEME_CURRENT SUBSLEEP

    # Split the output into lines
    $lines = $powercfgOutput -split "`n"

    # Initialize variables to hold the sleep timeout values
    $dcSleepTimeoutMinutes = $null

    # Flag to indicate we are in the Sleep after section
    $inSleepAfterSection = $false

    # Loop through each line to find relevant settings
    foreach ($line in $lines) {
        if ($line -match '\(Sleep after\)') {
            $inSleepAfterSection = $true
        } elseif ($line -match 'Power Setting GUID:') {
            $inSleepAfterSection = $false
        }

        if ($inSleepAfterSection -and $line -match 'Current DC Power Setting Index: 0x([0-9a-fA-F]+)') {
            $dcSleepTimeoutSeconds = [convert]::ToInt32($matches[1], 16)
            $dcSleepTimeoutMinutes = [math]::Round($dcSleepTimeoutSeconds / 60)
            return $dcSleepTimeoutMinutes
        }
    }

    # Return zero if no timeout value is found
    return 0
}

# Get the sleep timeout value
$sleepTimeoutMinutes = [math]::Max((Get-SleepTimeout) - 15, 0)

# Update the XML files
Update-TaskXML -xmlPath $task1XML -currentDir $currentDir
Update-TaskXML -xmlPath $task2XML -currentDir $currentDir -sleepTimeoutMinutes $sleepTimeoutMinutes

# Handle the scripts.ini file
if (-not (Test-Path $iniFile)) {
    # Create the ini file with UTF-16 LE encoding
    $content = "[Shutdown]`r`n"
    [System.IO.File]::WriteAllText($iniFile, $content, [System.Text.Encoding]::Unicode)

    # Set the file to hidden
    (Get-Item $iniFile).Attributes = [System.IO.FileAttributes]::Hidden
}

# Read existing content
$existingContent = [System.IO.File]::ReadAllText($iniFile, [System.Text.Encoding]::Unicode)

# Check if 0CmdLine= entry is present
if ($existingContent -notmatch "0CmdLine=") {
    $cmdLineEntry = "0CmdLine=$currentDir\battery.bat`r`n"
    $parametersEntry = "0Parameters=kill`r`n"
    [System.IO.File]::AppendAllText($iniFile, $cmdLineEntry, [System.Text.Encoding]::Unicode)
    [System.IO.File]::AppendAllText($iniFile, $parametersEntry, [System.Text.Encoding]::Unicode)
}