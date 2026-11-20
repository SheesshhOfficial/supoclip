@echo off
setlocal EnableExtensions DisableDelayedExpansion
title SupoClip - Local launcher
pushd "%~dp0" || goto folder_error
if not exist "docker-compose.yml" goto wrong_folder
if not exist ".env.example" goto wrong_folder

where /q docker.exe || goto docker_missing
docker compose version >nul 2>&1 || goto compose_missing
docker info >nul 2>&1 || goto docker_stopped

if exist ".env" goto check_config
echo Creating local .env with Gemini and Whisper defaults...
powershell.exe -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $text=[IO.File]::ReadAllText('.env.example'); $text=$text -replace '(?m)^TRANSCRIPTION_PROVIDER=[^\r\n]*','TRANSCRIPTION_PROVIDER=whisper' -replace '(?m)^WHISPER_MODEL_SIZE=[^\r\n]*','WHISPER_MODEL_SIZE=base' -replace '(?m)^LLM=[^\r\n]*','LLM=google-gla:gemini-3.1-flash-lite'; [IO.File]::WriteAllText('.env',$text,[Text.UTF8Encoding]::new($false))"
if errorlevel 1 goto config_error

:check_config
powershell.exe -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $text=[IO.File]::ReadAllText('.env'); $model=$env:LLM; if (-not $model) { $model=[regex]::Match($text,'(?m)^[ \t]*LLM[ \t]*=[ \t]*[\x22\x27]?([^\s\x22\x27#]+)').Groups[1].Value }; if (($model -like 'google-gla:*' -or $model -like 'google:*') -and [string]::IsNullOrWhiteSpace($env:GOOGLE_API_KEY) -and $text -notmatch '(?m)^[ \t]*GOOGLE_API_KEY[ \t]*=[ \t]*[\x22\x27]?[A-Za-z0-9_-]+') { exit 2 }"
if errorlevel 3 goto config_error
if errorlevel 2 goto add_key
if errorlevel 1 goto config_error

echo Starting SupoClip. The first Docker build can take several minutes.
docker compose up -d --build --wait --wait-timeout 240
if errorlevel 1 goto startup_error

set "supo_port="
for /f "tokens=2 delims=:" %%P in ('docker compose port frontend 3107 2^>nul') do set "supo_port=%%P"
if not defined supo_port goto startup_error

echo Opening http://localhost:%supo_port%/
start "" "http://localhost:%supo_port%/"
popd
exit /b 0

:add_key
echo Add your Gemini API key as GOOGLE_API_KEY in the local .env file.
echo Use a Google AI Studio key, not a YouTube Data API key.
echo Save the file, then double-click runme.bat again.
start "" notepad.exe ".env"
goto fail

:wrong_folder
echo Put runme.bat next to docker-compose.yml and .env.example.
goto fail
:docker_missing
echo Install Docker Desktop and reopen this launcher.
goto fail
:compose_missing
echo Docker Compose is unavailable. Update or repair Docker Desktop.
goto fail
:docker_stopped
echo Start Docker Desktop, wait until the engine is ready, and try again.
goto fail
:config_error
echo Could not prepare or read .env. Check folder permissions and try again.
goto fail
:startup_error
echo SupoClip did not start or no dashboard port was reported.
docker compose ps
echo To troubleshoot locally, run: docker compose logs --tail 50
goto fail
:folder_error
echo Could not open the folder containing runme.bat.
pause
exit /b 1
:fail
echo.
pause
popd
exit /b 1
