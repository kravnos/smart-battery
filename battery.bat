@ECHO OFF

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

:: Initialize variables
SET "SLEEP=0"     :: Determines if sleep is available
SET "HIBERNATE=0" :: Determines if hibernate is available
SET "SUSPEND=0"   :: Determines whether to sleep or hibernate
SET "TIMEOUT=0"   :: Determines how long to sleep or hibernate
SET "IDLE=900"    :: Time in seconds for task scheduler idle check
SET "date=%date: =-%"
SET "date=%date:/=-%"
SET "LOGFILE=logs\battery-%date%.log"

:: Check available sleep states
FOR /F "tokens=*" %%A IN ('powercfg /AVAILABLESLEEPSTATES') DO (
    IF "%%A"=="Standby (S3)" (
        SET "SLEEP=1"
    ) ELSE IF "%%A"=="Hibernate" (
        SET "HIBERNATE=1"
    ) ELSE IF "%%A"=="The following sleep states are not available on this system:" (
        GOTO :BREAK
    )
)
:BREAK

:: Calculate the timeout based on the current power settings
IF "%SLEEP%"=="1" (
    SET "SUSPEND=0"
    FOR /F "tokens=2 delims=:" %%A IN ('powercfg /QUERY SCHEME_CURRENT SUB_SLEEP STANDBYIDLE ^| findstr /I /C:"Current DC Power Setting Index:"') DO (
        SET /A "TIMEOUT=%%A-%IDLE%"
    )
)

IF "%HIBERNATE%"=="1" (
    :: Adjust timeout if hibernate settings are present
    IF %TIMEOUT% LEQ 0 (
        SET "SUSPEND=1"
        FOR /F "tokens=2 delims=:" %%B IN ('powercfg /QUERY SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE ^| findstr /I /C:"Current DC Power Setting Index:"') DO (
            SET /A "TIMEOUT=%%B-%IDLE%"
        )
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

:: Log the session
CALL :LOG >> %LOGFILE%
EXIT /B
:LOG
:NOLOG

:: Execute the PowerShell script with provided parameters
"%WINDIR%\SYSTEM32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy bypass -file "battery.ps1" %params%

:: Extract hours and minutes from the current time
:: FOR /F "TOKENS=1,2 DELIMS=:" %%A IN ("%TIME%") DO (
::     SET "hh=%%A"
::     SET "mm=%%B"
:: )

:: If parameters are provided and are "sleep", handle the sleep logic
IF NOT "%params%"=="" (
::  IF EXIST "%LOGFILE%" (
::          "sendEmail.exe" -f email@domain.com -t email@domain.com -u [%date%] [%hh%:%mm%]: battery.bat -m Session End -s mail.domain.com:26 -xu email@domain.com -xp password -o tls=no -a "%LOGFILE%"
::      TIMEOUT /T 2 /NOBREAK
::  )

    IF "%params%"=="sleep" (
        IF NOT "%TIMEOUT%"=="" (
            IF %TIMEOUT% GTR 0 (
                rundll32.exe powrprof.dll,SetSuspendState %SUSPEND%,1,%SUSPEND%
            )
        )
    )
)

EXIT
