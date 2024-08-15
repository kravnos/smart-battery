@echo off

REM Get admin permissions
SET "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

REM Task names to delete
set "batteryTaskName=BATTERY"
set "batterySleepTaskName=BATTERY-SLEEP"

REM Delete the tasks from Task Scheduler
schtasks /delete /tn "%batteryTaskName%" /f
if %errorlevel% neq 0 (
    echo Error: Deleting task "%batteryTaskName%".
    pause
    exit /b 1
)

schtasks /delete /tn "%batterySleepTaskName%" /f
if %errorlevel% neq 0 (
    echo Error: Deleting task "%batterySleepTaskName%".
    pause
    exit /b 1
)

echo Success: Scheduled Tasks deleted.

reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0\0" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0" /f

reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0\0" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0" /f

set "iniFile=%WINDIR%\System32\GroupPolicy\Machine\Scripts\scripts.ini"

if exist "%iniFile%" (
    attrib -h "%iniFile%"
    del "%iniFile%"
)

gpupdate /force

echo Success: Group Policy Task deleted.
echo Uninstall Complete.

pause
exit /b 0