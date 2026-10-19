@rem Run Vibe agent Ralph Loop 'n' times with arguments (without quotes).
@if "%~1"=="" goto error
@if "%~2"=="" goto error
@for /L %%i in (1,1,%1) do (
    @echo ---------- LOOP %%i ---------- 
    call vibe-cli "/ralph-loop %2"
    @echo %errorlevel%
    @echo ++++++++++ DONE %%i ++++++++++
)
@goto end
:error
@echo Needs 1. count and 2. name of loop task list file (@).
@exit /b 1
:end
