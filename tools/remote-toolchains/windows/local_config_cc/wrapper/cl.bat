
@echo off

set msvcpath=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133\bin\HostX64\x64
setlocal EnableDelayedExpansion

set "paramfile=%~1"
echo %paramfile | findstr /b /C:"@" 1>nul
if errorlevel 1 (
    REM Free arguments, iterate through them to find the output file path.
    for %%a in (%*) do (
        echo %%a | findstr /C:"/Fo" 1>nul
        if errorlevel 1 (
            echo "Unable to find the /Fo flag"
        ) else (
            echo "Argument: %%a"
            set dotd=%%a
            call set dotd=%%dotd:/Fo=%""%%%
            call set dotd=%%dotd:.obj=".d"%%
            goto :success
        )
    )
) else (
    REM Parameter file
    set dotd=%paramfile%
    call set dotd=%%dotd:@=%%
    call set dotd=%%dotd:.params=%%
    call set dotd=%%dotd:.obj=.d%%
    goto :success
)


REM could not determine the output filepath.
exit /B 101

:success

echo "writing to dotd file: %dotd%"
echo "Intentionally empty file to satisfy Bazel's predeclared output; MSVC does not produce .d files." > %dotd%

"%msvcpath%"\\cl.exe %*
