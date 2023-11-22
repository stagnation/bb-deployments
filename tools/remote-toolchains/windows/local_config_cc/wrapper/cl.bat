
@echo off
REM FINDSTR: Cannot open statusor.obj.params
REM The process cannot access the file because it is being used by another process.
REM
REM When using a simple script we expect it to show the full path
REM     $ ./clean-test-param.bat @fixtures/param.filex
REM     FINDSTR: Cannot open fixtures/param.filex
REM
REM But the script does not work either in the action directory
REM     $ ./clean-test-param.bat @bazel-out/k8-fastbuild/bin/external/com_google_protobuf/_objs/protoc_lib/cpp_enum.obj.params
REM     FINDSTR: Cannot open cpp_enum.obj.params
REM     ECHO is off.
REM
REM Sharing Violation?
REM     nils@yoga MINGW64 /c/tmp/bb/worker/build/16898c097a184105/root
REM     $ cp bazel-out/k8-fastbuild/bin/external/com_google_protobuf/_objs/protoc_lib/cpp_enum.obj.params test.params

REM     nils@yoga MINGW64 /c/tmp/bb/worker/build/16898c097a184105/root
REM     $ ./clean-test-param.bat test.params
REM     /Fobazel-out/k8-fastbuild/bin/external/com_google_protobuf/_objs/protoc_lib/cpp_enum.obj
REM
REM It seems to be some issue with directory-listing, there is no sharing violation in procmon
REM
REM Directory listing?
REM
REM     # copy here works
REM     nils@yoga MINGW64 /c/tmp/bb/worker/build/00ec43a0c49dbd09/root
REM     $ ./clean-test-param.bat lite.obj.params
REM     /Fobazel-out/k8-fastbuild/bin/external/com_google_protobuf/_objs/protobuf_lite/generated_message_tctable_lite.obj

REM     # copy inside the output directory does not
REM     nils@yoga MINGW64 /c/tmp/bb/worker/build/00ec43a0c49dbd09/root
REM     $ cp bazel-out/k8-fastbuild/bin/external/com_google_protobuf/_objs/protobuf_lite/generated_message_tctable_lite.obj.params{,2}

REM     nils@yoga MINGW64 /c/tmp/bb/worker/build/00ec43a0c49dbd09/root
REM     $ ./clean-test-param.bat @bazel-out/k8-fastbuild/bin/external/com_google_protobuf/_objs/protobuf_lite/generated_message_tctable_lite.obj.params
REM     FINDSTR: Cannot open generated_message_tctable_lite.obj.params
REM     ECHO is off.

REM     nils@yoga MINGW64 /c/tmp/bb/worker/build/00ec43a0c49dbd09/root
REM     $ ./clean-test-param.bat @bazel-out/k8-fastbuild/bin/external/com_google_protobuf/_objs/protobuf_lite/generated_message_tctable_lite.obj.params2
REM     FINDSTR: Cannot open generated_message_tctable_lite.obj.params2
REM     ECHO is off.


set msvcpath=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133\bin\HostX64\x64
setlocal EnableDelayedExpansion

set "paramfile=%~1"
echo %paramfile | findstr /b /C:"@" 1>nul
if errorlevel 1 (
    echo No param file
    for %%a in (%*) do (
        echo %%a | findstr /C:"/Fo" 1>nul
        if errorlevel 1 (
            REM echo ""
        ) else (
            set output=%%a
            goto :success
        )
    )
) else (
    echo Param file
    call set paramfile=%%paramfile:@=%%
    echo inner paramfile: !paramfile!
    for /f %%i in ('findstr /R "Fo" "!paramfile!"') do (
        set output=%%i
        goto :success
    )
)


REM could not determine the output filepath.
exit /B 101

:success
echo output arg: %output%

set dotd=%output%
call set dotd=%%dotd:/Fo=%""%%%
call set dotd=%%dotd:.obj=".d"%%

echo "Intentionally empty file to satisfy Bazel's predeclared output; MSVC does not produce .d files." > %dotd%

"%msvcpath%"\\cl.exe %*

:error
echo Failed with error #%errorlevel%.
exit /b %errorlevel%
