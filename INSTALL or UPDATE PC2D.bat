@echo off
color 0A
title Pokemon Battle Simulator Updater
cls

echo ================================================
echo         POKEMON BATTLE SIMULATOR UPDATER
echo ================================================
echo.
echo Preparing to update your game...
echo.

REM Set repository information
set REPO_URL=https://github.com/ArchieDxncan/Pokemon-Essentials-Projects.git
set REPO_BRANCH=main
set "REPO_SUBFOLDER=Battle Simulator"
set GAME_FOLDER=%~dp0
set TEMP_FOLDER=%TEMP%\pokemon_update_%random%
set GIT_INSTALLER_URL=https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.3/Git-2.41.0.3-64-bit.exe
set GIT_INSTALLER=%TEMP%\git_installer.exe

REM Check if git is installed
where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Git is not installed. Installing Git silently...
    echo This may take a minute, please wait...
    
    REM Download Git installer
    echo Downloading Git installer...
    powershell -Command "Invoke-WebRequest -Uri '%GIT_INSTALLER_URL%' -OutFile '%GIT_INSTALLER%'" >nul 2>&1
    
    if exist "%GIT_INSTALLER%" (
        REM Run Git installer silently
        echo Installing Git...
        start /wait "" "%GIT_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS
        
        REM Add Git to PATH for current session
        set "PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files (x86)\Git\cmd"
        echo Git installed successfully.
    ) else (
        echo ERROR: Failed to download Git installer.
        echo Please try running this updater again with internet connection.
        pause
        exit /b 1
    )
    
    REM Verify Git was installed
    where git >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Git installation failed.
        echo Please try running this updater again or contact game support.
        pause
        exit /b 1
    )
)

echo Downloading latest game files...

REM Create temp folder
if exist "%TEMP_FOLDER%" rmdir /S /Q "%TEMP_FOLDER%"
mkdir "%TEMP_FOLDER%"

REM Clone the repository to temp folder
cd /d "%TEMP_FOLDER%"
echo Cloning repository from GitHub...
git clone --depth 1 --branch %REPO_BRANCH% %REPO_URL% . 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to download the latest game version.
    echo.
    echo Possible reasons:
    echo - No internet connection
    echo - The game repository might be unavailable
    echo.
    rmdir /S /Q "%TEMP_FOLDER%" 2>nul
    pause
    exit /b 1
)

REM Check if the subfolder exists in the repository
if not exist "%TEMP_FOLDER%\%REPO_SUBFOLDER%" (
    echo ERROR: Could not find the Battle Simulator folder in the repository.
    echo Looking for: "%TEMP_FOLDER%\%REPO_SUBFOLDER%"
    echo Available folders in the repository:
    dir "%TEMP_FOLDER%" /AD /B
    echo.
    echo Please contact the game developer.
    rmdir /S /Q "%TEMP_FOLDER%" 2>nul
    pause
    exit /b 1
)

echo Installing updated game files...

REM Create temp folder for STORAGE backup
set "STORAGE_BACKUP=%TEMP%\storage_backup_%random%"
mkdir "%STORAGE_BACKUP%" 2>nul

REM Backup STORAGE folder if it exists
if exist "%GAME_FOLDER%\STORAGE" (
    echo Preserving your save data...
    xcopy /E /I /H /Y "%GAME_FOLDER%\STORAGE" "%STORAGE_BACKUP%\STORAGE" >nul
)

REM Copy all new files from repository subfolder to game folder, overwriting existing ones
echo Copying updated game files...
xcopy /E /I /H /Y "%TEMP_FOLDER%\%REPO_SUBFOLDER%\*" "%GAME_FOLDER%" >nul

REM Restore STORAGE folder if it was backed up
if exist "%STORAGE_BACKUP%\STORAGE" (
    echo Restoring your save data...
    xcopy /E /I /H /Y "%STORAGE_BACKUP%\STORAGE" "%GAME_FOLDER%\STORAGE" >nul
)

REM Clean up
rmdir /S /Q "%TEMP_FOLDER%" 2>nul
rmdir /S /Q "%STORAGE_BACKUP%" 2>nul

echo ================================================
echo          GAME UPDATE COMPLETED SUCCESSFULLY!
echo ================================================
echo.
echo Your Pokemon Battle Simulator is now up to date!
echo Your save data in the STORAGE folder has been preserved.
echo.
echo Press any key to launch the game...
pause >nul

REM Launch the game - update this to match your executable name
cd /d "%GAME_FOLDER%"
if exist "Game.exe" (
    start "" "Game.exe"
) else if exist "Pokemon.exe" (
    start "" "Pokemon.exe"
) else if exist "Pokemon Battle Simulator.exe" (
    start "" "Pokemon Battle Simulator.exe"
) else (
    echo Note: Could not find game executable to launch.
    echo Please start the game manually.
)

exit /b 0