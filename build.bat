@echo off

IF "%~1"=="" GOTO RELEASE
IF "%~1"=="run" GOTO RUN
IF "%~1"=="debug" GOTO DEBUG
IF "%~1"=="release" GOTO RELEASE

:run
odin run src -resource:assets/icon/timealloc.rc -out:timealloc.exe -debug
GOTO DONE

:DEBUG
del *.pdb
odin build src -resource:assets/icon/timealloc.rc -out:timealloc.exe -debug -show-timings
echo Done building timealloc in debug mode.
GOTO DONE

:RELEASE
odin build src -resource:assets/icon/timealloc.rc -out:timealloc.exe -o:speed -show-timings -define:UTC_OFFSET=-5
echo Done building timealloc in release mode.
GOTO DONE

:DONE
