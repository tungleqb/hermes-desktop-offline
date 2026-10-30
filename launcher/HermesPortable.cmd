@echo off
rem Fallback launcher (no compile needed). Sets env and starts app\Hermes.exe.
set ROOT=%~dp0..
set HERMES_HOME=%ROOT%\data
set HERMES_RUNTIME_DIR=%ROOT%\runtime
set HERMES_BUNDLED_SKILLS=%ROOT%\skills-bundle\skills
set HERMES_OPTIONAL_SKILLS=%ROOT%\skills-bundle\optional-skills
set HERMES_BUNDLED_PLUGINS=%ROOT%\skills-bundle\plugins
set HERMES_OFFLINE=1
set PYTHONUTF8=1
set HERMES_PORTABLE_ROOT=%ROOT%
set APP=
for %%f in ("%ROOT%\app\*.exe") do (set APP=%%f& goto found)
:found
if "%APP%"=="" (
  echo ERROR: no app exe found under app\. Run launcher\setup.ps1 first.
  exit /b 1
)
start "" "%APP%"

