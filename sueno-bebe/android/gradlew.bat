@echo off
setlocal
set APP_HOME=%~dp0
set URL=https://services.gradle.org/distributions/gradle-8.13-bin.zip
set EXPECTED=20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78
set VERSION=8.13
if "%GRADLE_USER_HOME%"=="" set GRADLE_USER_HOME=%USERPROFILE%\.gradle
set BASE=%GRADLE_USER_HOME%\wrapper\dists\manual-gradle-%VERSION%
set ZIP=%BASE%\gradle-%VERSION%-bin.zip
set GRADLE=%BASE%\gradle-%VERSION%\bin\gradle.bat
if not exist "%GRADLE%" (
  if not exist "%BASE%" mkdir "%BASE%"
  if not exist "%ZIP%" powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%URL%' -OutFile '%ZIP%'"
  for /f %%H in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-FileHash -Algorithm SHA256 '%ZIP%').Hash.ToLowerInvariant()"') do set ACTUAL=%%H
  if /I not "%ACTUAL%"=="%EXPECTED%" (
    echo El SHA-256 de Gradle no coincide.
    del /q "%ZIP%"
    exit /b 1
  )
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%BASE%' -Force"
)
call "%GRADLE%" %*
endlocal
