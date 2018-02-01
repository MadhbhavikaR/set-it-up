@ECHO OFF
@ECHO This script is meant to be run only first time for setting up 'Set-it-up!' or for clean reset to original defaults.
@ECHO.
@ECHO This means that you would loose all the data saved so far for 'Set-it-up!' and start with a 'Clean Slate Protocol'
@ECHO Proceed with caution (We assume you know what you are doing!) ...
@ECHO.
@PAUSE
REM RMDIR /S docker-volumes
ROBOCOPY anvesak\resources\anvesak docker-volumes\databases\anvesak /E /ETA
docker-compose down
docker-compose up