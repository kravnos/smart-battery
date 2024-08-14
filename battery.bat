@ECHO OFF

SET "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~sdp0"" && %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

SET "date=%date: =-%"
SET "date=%date:/=-%"
SET "LOGFILE=logs\battery-%date%.log"

IF NOT "%params%"=="" (
	IF "%params%"=="sleep" (
		TIMEOUT /T 2700 /NOBREAK
	)
	GOTO SKIP
)

IF NOT EXIST "logs\" (
	MKDIR "logs\"
)

CALL :LOG >> %LOGFILE%
EXIT /B
:LOG

:SKIP

"%WINDIR%\SYSTEM32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy bypass -file "battery.ps1" %params%

FOR /F "TOKENS=1,2 DELIMS=:" %%A IN ("%TIME%") DO (
	set "hh=%%A"
	set "mm=%%B"
)

IF NOT "%params%"=="" (
	IF EXIST "%LOGFILE%" (
		:: "sendEmail.exe" -f email@domain.com -t email@domain.com -u [%date%] [%hh%:%mm%]: battery.bat -m Session End -s mail.domain.com:26 -xu email@domain.com -xp password -o tls=no -a "%LOGFILE%"
		:: TIMEOUT /T 2 /NOBREAK
	)

	IF "%params%"=="sleep" (
		rundll32.exe powrprof.dll,SetSuspendState Sleep
	)
)

EXIT