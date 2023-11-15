@echo off

set msvcpath=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133\bin\HostX64\x64
for %%a in (%*) do (
    echo %%a | findstr /C:"/Fo" 1>nul
    if errorlevel 1 (
        REM echo ""
    ) else (
        REM echo found
        set output=%%a
    )

)
REM echo %*
REM echo "output: " %output%

set dotd=%output%
REM echo "dotd:" %dotd%
call set dotd=%%dotd:/Fo=%""%%%
call set dotd=%%dotd:.obj=".d"%%
REM echo "dotd:" %dotd%

REM copy /y NUL %dotd% >NUL
echo . 2> %dotd% >NUL

"%msvcpath%"\\cl.exe %* >NUL
