if "%1"=="" GOTO NOOPTS
if "%2"=="" GOTO ONEOPT
if "%3"=="" GOTO TWOOPTS
if "%4"=="" GOTO THREEOPTS

GOTO END

:NOOPTS
java -jar installer.jar
GOTO END

:ONEOPT
java -jar installer.jar %1
GOTO END

:TWOOPTS
java -jar installer.jar %1 %2
GOTO END

:THREEOPTS
java -jar installer.jar %1 %2 %3
GOTO END

:END