# Get the current directory where the script is running
$currentDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Paths to the XML files
$task1XML = "BATTERY.XML"
$task2XML = "BATTERY-SLEEP.XML"

# Function to update XML files
function Update-TaskXML {
    param (
        [string]$xmlPath,
        [string]$currentDir,
        [int]$sleepTimeoutMinutes = 0
    )

    if (-not (Test-Path $xmlPath)) {
        Write-Host "Error: File $xmlPath not found."
        return
    }

    try {
        # Load the XML file
        [xml]$xml = Get-Content $xmlPath

        # Define the XML namespace
        $namespace = "http://schemas.microsoft.com/windows/2004/02/mit/task"
        $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $namespaceManager.AddNamespace("ns", $namespace)

        if ($xmlPath -eq $task2XML) {
            $idleTriggerEnabledNode = $xml.SelectNodes("//ns:Task//ns:Triggers/ns:IdleTrigger/ns:Enabled", $namespaceManager)
            foreach ($node in $idleTriggerEnabledNode) {
                if ($sleepTimeoutMinutes -gt 0) {
                    $node.InnerText = "true"
                } else {
                    $node.InnerText = "false"
                }
            }

            $durationNode = $xml.SelectNodes("//ns:Task//ns:Settings//ns:IdleSettings/ns:Duration", $namespaceManager)
            foreach ($node in $durationNode) {
                $newDuration = "PT${sleepTimeoutMinutes}M"
                $node.InnerText = $newDuration
            }
        }

        $execNodes = $xml.SelectNodes("//ns:Task//ns:Actions//ns:Exec/ns:Command", $namespaceManager)
        foreach ($node in $execNodes) {
            $fileName = [System.IO.Path]::GetFileName($node.InnerText)
            $node.InnerText = Join-Path -Path $currentDir -ChildPath $fileName
        }

        $workingDirNodes = $xml.SelectNodes("//ns:Task//ns:Actions//ns:Exec/ns:WorkingDirectory", $namespaceManager)
        foreach ($node in $workingDirNodes) {
            $node.InnerText = $currentDir
        }


        # Save the updated XML
        $xml.Save($xmlPath)
        Write-Host "Success: Updated $xmlPath."
    } catch {
        Write-Host "Error: Failed to update $xmlPath. $_"
    }
}

# Function to get the sleep timeout value
function Get-SleepTimeout {
    try {
        $powercfgOutput = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
        $lines = $powercfgOutput -split "`n"
        foreach ($line in $lines) {
            if ($line -match 'Current DC Power Setting Index: 0x([0-9a-fA-F]+)') {
                $dcSleepTimeoutSeconds = [convert]::ToInt32($matches[1], 16)
                return [math]::Round($dcSleepTimeoutSeconds / 60)
            }
        }
    } catch {
        Write-Host "Error: Failed to get sleep timeout. $_"
    }
    return 0
}

# Function to get the hibernate timeout value
function Get-HibernateTimeout {
    try {
        $powercfgOutput = powercfg /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE
        $lines = $powercfgOutput -split "`n"
        foreach ($line in $lines) {
            if ($line -match 'Current DC Power Setting Index: 0x([0-9a-fA-F]+)') {
                $dcSleepTimeoutSeconds = [convert]::ToInt32($matches[1], 16)
                return [math]::Round($dcSleepTimeoutSeconds / 60)
            }
        }
    } catch {
        Write-Host "Error: Failed to get hibernate timeout. $_"
    }
    return 0
}

# Get the sleep timeout value
$sleepTimeoutMinutes = [math]::Max((Get-SleepTimeout) - 15, 0)

# Check if sleep timeout is valid
if ($sleepTimeoutMinutes -le 0) {
    $sleepTimeoutMinutes = [math]::Max((Get-HibernateTimeout) - 15, 0)
}

# Update the XML files
Update-TaskXML -xmlPath $task1XML -currentDir $currentDir
Update-TaskXML -xmlPath $task2XML -currentDir $currentDir -sleepTimeoutMinutes $sleepTimeoutMinutes