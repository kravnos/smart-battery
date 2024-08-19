@echo off

:: Get admin permissions
SET "params=%*"
CD /D "%~dp0"
IF EXIST "%temp%\getadmin.vbs" (
    DEL /Q "%temp%\getadmin.vbs"
)

FSUTIL DIRTY QUERY %systemdrive% 1>nul 2>nul || (
    ECHO SET UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/K CD ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    EXIT /B
)

:: Task names to delete
set "batteryTaskName=BATTERY"
set "batterySleepTaskName=BATTERY-SLEEP"

:: Delete the tasks from Task Scheduler
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

:: Check if powershell.exe is running
tasklist /FI "IMAGENAME eq powershell.exe" | find /I "powershell.exe" >nul
if %ERRORLEVEL% EQU 0 (
    TASKKILL /IM "powershell.exe" /F
    if %ERRORLEVEL% NEQ 0 (
        echo Error: Failed to terminate powershell.exe.
        pause
        exit /b 1
    )
    TIMEOUT /T 2 /NOBREAK
)

:: Clean up files
set "idFile=%~dp0battery_id.txt"
set "tokenFile=%~dp0battery_token.txt"
set "logsDir=%~dp0logs\"

if exist "%idFile%" (
    del /q "%idFile%"
)
if exist "%tokenFile%" (
    del /q "%tokenFile%"
)
if exist "%logsDir" (
    rd /s /q "%logsDir%"
)
echo Success: Cleaned up files.

:: Remove registry entries for Group Policy Scripts
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0\0" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0" /f

reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0\0" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0" /f

set "iniFile=%WINDIR%\System32\GroupPolicy\Machine\Scripts\scripts.ini"

if exist "%iniFile%" (
    attrib -h "%iniFile%"
    del /q "%iniFile%"
)

:: Force a Group Policy update
gpupdate /force

echo Success: Group Policy Task deleted.
echo Uninstall Complete.

pause
exit /b 0