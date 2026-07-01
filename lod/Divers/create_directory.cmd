@echo off
REM Script to extract directory from file path and create it if needed

REM Example file path - change this to your actual file path
SET "FILEPATH=C:\Users\Example\Documents\Project\SubFolder\myfile.txt"

REM Extract the directory path from the full file path
FOR %%F IN ("%FILEPATH%") DO SET "DIRPATH=%%~dpF"

REM Remove trailing backslash if present
IF "%DIRPATH:~-1%"=="\" SET "DIRPATH=%DIRPATH:~0,-1%"

ECHO File path: %FILEPATH%
ECHO Directory path: %DIRPATH%
ECHO.

REM Check if directory exists
IF NOT EXIST "%DIRPATH%" (
    ECHO Directory does not exist. Creating: %DIRPATH%
    MKDIR "%DIRPATH%"
    IF ERRORLEVEL 1 (
        ECHO ERROR: Failed to create directory
        EXIT /B 1
    ) ELSE (
        ECHO SUCCESS: Directory created successfully
    )
) ELSE (
    ECHO Directory already exists: %DIRPATH%
)

ECHO.
PAUSE