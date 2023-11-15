@echo off

set msvcpath=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133\bin\HostX64\x64
for %%a in (%*) do (
    echo %%a | findstr /C:"/Fo" 1>nul
    if errorlevel 1 (
        REM echo ""
    ) else (
        set output=%%a
    )

)

set dotd=%output%
call set dotd=%%dotd:/Fo=%""%%%
call set dotd=%%dotd:.obj=".d"%%

echo . 2> %dotd% >NUL

"%msvcpath%"\\cl.exe %* >NUL
