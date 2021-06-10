@echo off
cls
echo Version (X.X.X.X [Text]):
set /P v=
verpatch era.dll "%v%" /va