@echo off

set msvcpath=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133\bin\HostX64\x64

"%msvcpath%"\\link.exe %*
