@ECHO OFF

:: Get admin permissions
SET "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || ( echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

:: Initialize variables
SET "TIMEOUT="  :: Clear TIMEOUT variable
SET "IDLE=900"  :: Time in seconds for task scheduler idle check
SET "SLEEP=0"   :: Determines whether to sleep or hibernate
SET "date=%date: =-%"
SET "date=%date:/=-%"
SET "LOGFILE=logs\battery-%date%.log"

:: Calculate the timeout based on the current power settings
FOR /F "tokens=2 delims=:" %%A IN ('powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE ^| findstr /C:"Current DC Power Setting Index:"') DO (
    SET /A "TIMEOUT=%%A-%IDLE%"
)

:: If TIMEOUT is not set, default to 0
IF "%TIMEOUT%"=="" (
    SET "TIMEOUT=0"
)

:: Adjust timeout if hibernate settings are present
IF %TIMEOUT% LEQ 0 (
    FOR /F "tokens=2 delims=:" %%B IN ('powercfg /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE ^| findstr /C:"Current DC Power Setting Index:"') DO (
        SET /A "TIMEOUT=%%B-%IDLE%"
        SET "SLEEP=1"
    )
)

:: If parameters are provided and are "sleep", handle sleep logic
IF NOT "%params%"=="" (
    IF "%params%"=="sleep" (
        IF NOT "%TIMEOUT%"=="" (
            IF %TIMEOUT% GTR 0 (
                TIMEOUT /T %TIMEOUT% /NOBREAK
            )
        )
    )
    GOTO NOLOG
)

:: Create logs directory if it doesn't exist
IF NOT EXIST "logs\" (
    MKDIR "logs\"
)

:: Log the session end
CALL :LOG >> %LOGFILE%
EXIT /B
:LOG
:NOLOG

:: Execute the PowerShell script with provided parameters
"%WINDIR%\SYSTEM32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy bypass -file "battery.ps1" %params%

:: Extract hours and minutes from the current time
::FOR /F "TOKENS=1,2 DELIMS=:" %%A IN ("%TIME%") DO (
::    SET "hh=%%A"
::    SET "mm=%%B"
::)

:: If parameters are provided and are "sleep", handle the sleep logic
IF NOT "%params%"=="" (
::	IF EXIST "%LOGFILE%" (
::		"sendEmail.exe" -f email@domain.com -t email@domain.com -u [%date%] [%hh%:%mm%]: battery.bat -m Session End -s mail.domain.com:26 -xu email@domain.com -xp password -o tls=no -a "%LOGFILE%"
::		TIMEOUT /T 2 /NOBREAK
::	)

    IF "%params%"=="sleep" (
        IF NOT "%TIMEOUT%"=="" (
            IF %TIMEOUT% GTR 0 (
                rundll32.exe powrprof.dll,SetSuspendState %SLEEP%,1,%SLEEP%
            )
        )
    )
)

EXIT