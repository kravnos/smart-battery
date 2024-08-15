@echo off

:: Get admin permissions
SET "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || ( echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

:: Paths to the XML files for Task Scheduler
set "batteryTaskXML=BATTERY.XML"
set "batterySleepTaskXML=BATTERY-SLEEP.XML"

:: Check if the XML files exist
if not exist "%batteryTaskXML%" (
    echo Error: %batteryTaskXML% not found.
    pause
    exit /b 1
)

if not exist "%batterySleepTaskXML%" (
    echo Error: %batterySleepTaskXML% not found.
    pause
    exit /b 1
)

:: Update Task Scheduler XML files working directory
"%WINDIR%\SYSTEM32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy bypass -file "update.ps1"

:: Import the tasks into Task Scheduler
schtasks /create /xml "%batteryTaskXML%" /tn "BATTERY" /f
if %errorlevel% neq 0 (
    echo Error: Importing %batteryTaskXML%.
    pause
    exit /b 1
)

schtasks /create /xml "%batterySleepTaskXML%" /tn "BATTERY-SLEEP" /f
if %errorlevel% neq 0 (
    echo Error: Importing %batterySleepTaskXML%.
    pause
    exit /b 1
)

echo Success: Scheduled Tasks imported.

:: Add registry entries for Group Policy Scripts
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0" /v "GPO-ID" /t REG_SZ /d "LocalGPO" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0" /v "SOM-ID" /t REG_SZ /d "Local" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0" /v "FileSysPath" /t REG_SZ /d "C:\\Windows\\System32\\GroupPolicy\\Machine" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0" /v "DisplayName" /t REG_SZ /d "Local Group Policy" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0" /v "GPOName" /t REG_SZ /d "Local Group Policy" /f

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0\0" /v "Script" /t REG_SZ /d "%~dp0battery.bat" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0\0" /v "Parameters" /t REG_SZ /d "kill" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0\0" /v "ExecTime" /t REG_BINARY /d 00000000000000000000000000000000 /f

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0" /v "GPO-ID" /t REG_SZ /d "LocalGPO" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0" /v "SOM-ID" /t REG_SZ /d "Local" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0" /v "FileSysPath" /t REG_SZ /d "C:\\Windows\\System32\\GroupPolicy\\Machine" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0" /v "DisplayName" /t REG_SZ /d "Local Group Policy" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0" /v "GPOName" /t REG_SZ /d "Local Group Policy" /f

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0\0" /v "Script" /t REG_SZ /d "%~dp0battery.bat" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0\0" /v "Parameters" /t REG_SZ /d "kill" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0\0" /v "IsPowershell" /t REG_DWORD /d 00000000 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0\0" /v "ExecTime" /t REG_BINARY /d 00000000000000000000000000000000 /f

:: Update scripts.ini file for Group Policy Scripts
set "iniFile=%WINDIR%\System32\GroupPolicy\Machine\Scripts\scripts.ini"

if exist "%iniFile%" (
    attrib -h "%iniFile%"
    del "%iniFile%"
)

(
    echo [Shutdown]
    echo 0CmdLine=%~dp0battery.bat
    echo 0Parameters=kill
) > "%iniFile%"

attrib +h "%iniFile%"

:: Force a Group Policy update
gpupdate /force

echo Success: Group Policy Task imported.
echo Installation Complete.

pause
exit /b 0