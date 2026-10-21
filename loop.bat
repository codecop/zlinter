@rem Run Vibe agent Ralph Loop 'n' times with arguments (without quotes).
@if "%~1"=="" goto error
@if "%~2"=="" goto error
@if "%~1"=="scan" goto scan

:loop
@for /L %%i in (1,1,%1) do (
    @echo ---------- LOOP nr. %%i ---------- 
    call vibe-cli "/ralph-loop %2"
    @echo Error: %errorlevel%
    @echo ++++++++++ DONE nr. %%i ++++++++++
)
@goto end

:scan
grep "\[ \]" "%2" > nul
@if errorlevel 1 goto end
@echo ---------- LOOP ---------- 
call vibe-cli "/ralph-loop %2"
@echo Error: %errorlevel%
@echo ++++++++++ DONE ++++++++++
loop %1 %2

:error
@echo Needs 1. count and 2. name of loop task list file (@).
@exit /b 1
:end
