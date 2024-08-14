@echo off

REM Get admin permissions
SET "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

REM Paths to the XML files
set "batteryTaskXML=BATTERY.XML"
set "batterySleepTaskXML=BATTERY-SLEEP.XML"

REM Check if the XML files exist
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

REM Update Task Scheduler XML files working directory
"%WINDIR%\SYSTEM32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy bypass -file "update.ps1"

REM Import the tasks into Task Scheduler
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

set iniFile=%WINDIR%\System32\GroupPolicy\Machine\Scripts\scripts.ini

if not exist "%iniFile%" (
    echo [Shutdown] > "%iniFile%"
)

(for /f "tokens=*" %%A in ('findstr /b /c:"0CmdLine=" "%iniFile%"') do (set existingLine=%%A)) || (set existingLine=)
if "%existingLine%"=="" (
    echo 0CmdLine=%~dp0battery.bat >> "%iniFile%"
    echo 0Parameters=kill >> "%iniFile%"
)

gpupdate /force

echo Success: Group Policy Task imported.

pause
exit /b 0