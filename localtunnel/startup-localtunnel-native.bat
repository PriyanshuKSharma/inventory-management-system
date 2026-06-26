@echo off
setlocal EnableDelayedExpansion

:: Configuration
set LT_SUBDOMAIN=mqi-rdt-pu-ims
if not "%1"=="" set LT_SUBDOMAIN=%1

echo Starting Marquardt Inventory Management System - Windows Native LocalTunnel
echo ========================================================================
echo Application: Node.js Inventory Management System
echo Database: MySQL on Windows
echo Local access: http://localhost:3000
echo Global access: https://%LT_SUBDOMAIN%.loca.lt
echo Admin login: admin / admin123
echo No signup required - instant public URL!
echo ========================================================================

:: Check if MySQL is running (try different service names)
echo Checking MySQL service...
set MYSQL_FOUND=0

:: Try common MySQL service names
sc query mysql >nul 2>&1
if %errorlevel% equ 0 set MYSQL_FOUND=1

sc query mysql80 >nul 2>&1
if %errorlevel% equ 0 set MYSQL_FOUND=1

sc query mysql57 >nul 2>&1
if %errorlevel% equ 0 set MYSQL_FOUND=1

sc query mysqld >nul 2>&1
if %errorlevel% equ 0 set MYSQL_FOUND=1

:: Check if mysqld.exe is running as a process
tasklist /fi "imagename eq mysqld.exe" 2>nul | find /i "mysqld.exe" >nul
if %errorlevel% equ 0 set MYSQL_FOUND=1

if %MYSQL_FOUND% equ 1 (
    echo [OK] MySQL is running
) else (
    echo [ERROR] MySQL service not found or not running.
    echo    Please ensure MySQL is installed and running.
    echo    - If using XAMPP: Start Apache and MySQL from XAMPP Control Panel
    echo    - If using standalone MySQL: Start MySQL service
    pause
    exit /b 1
)

:: Wait a moment for MySQL to be ready
timeout /t 3 /nobreak >nul

:: Check database and create if needed
echo Checking database setup...
mysql -u sigma -p -e "CREATE DATABASE IF NOT EXISTS product_management_system;" 2>nul
if %errorlevel% neq 0 (
    mysql -u sigma -e "CREATE DATABASE IF NOT EXISTS product_management_system;" 2>nul
    if %errorlevel% neq 0 (
        echo [ERROR] Could not connect to MySQL. Please check your MySQL installation.
        echo    Try running: mysql -u sigma -p
        pause
        exit /b 1
    )
)

:: Create user if needed
echo Setting up database user...
mysql -u sigma -p -e "CREATE USER IF NOT EXISTS 'sigma'@'localhost' IDENTIFIED BY 'sigma'; GRANT ALL PRIVILEGES ON *.* TO 'sigma'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>nul
if %errorlevel% neq 0 (
    mysql -u sigma -e "CREATE USER IF NOT EXISTS 'sigma'@'localhost' IDENTIFIED BY 'sigma'; GRANT ALL PRIVILEGES ON *.* TO 'sigma'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>nul
)

:: Import database schema if sql file exists
if exist "sql\database.sql" (
    echo Importing database schema...
    mysql -u sigma -psigma product_management_system < sql\database.sql
    if %errorlevel% equ 0 (
        echo [OK] Database schema imported successfully
    ) else (
        echo [WARNING] Could not import schema, but continuing...
    )
) else (
    echo [WARNING] Database schema file not found, but continuing...
)

:: Check database connection
echo Testing database connection...
mysql -u sigma -psigma -e "USE product_management_system; SELECT 1;" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Database connection successful
) else (
    echo [ERROR] Database connection failed. Please check MySQL setup.
    pause
    exit /b 1
)

:: Check if Node.js is installed
echo Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed. Please install Node.js first.
    echo    Download from: https://nodejs.org/
    pause
    exit /b 1
) else (
    echo [OK] Node.js is installed
)

:: Install dependencies if node_modules doesn't exist
if not exist "node_modules" (
    echo Installing Node.js dependencies...
    npm install
    if !errorlevel! equ 0 (
        echo [OK] Dependencies installed
    ) else (
        echo [ERROR] Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo [OK] Dependencies already installed
)

:: Create uploads directory if it doesn't exist
if not exist "uploads\products" (
    mkdir uploads\products
    echo [OK] Created uploads directory
) else (
    echo [OK] Uploads directory already exists
)

:: Check if LocalTunnel is installed globally
echo Checking LocalTunnel installation...
lt --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing LocalTunnel globally...
    npm install -g localtunnel
    if !errorlevel! equ 0 (
        echo [OK] LocalTunnel installed successfully
    ) else (
        echo [ERROR] Failed to install LocalTunnel
        pause
        exit /b 1
    )
) else (
    echo [OK] LocalTunnel is installed
)

:: Set environment variables
set NODE_ENV=production
set DB_HOST=localhost
set DB_USER=sigma
set DB_PASSWORD=sigma
set DB_NAME=product_management_system
set DB_PORT=3306
set SESSION_SECRET=localtunnel-secret-2025
set PORT=3000

:: Email configuration
set EMAIL_USER=priyanshu17ks.edu@gmail.com
set EMAIL_PASS=bztn fcvu zaig dztn
set ADMIN_EMAIL=priyanshu17ks.edu@gmail.com

:: Create admin user
echo Setting up admin user...
node scripts\create-admin.js
if %errorlevel% neq 0 (
    echo [WARNING] Admin user setup may have issues, but continuing...
)

:: Start LocalTunnel in background
echo Starting LocalTunnel for global access...
start /b "" lt --port 3000 --subdomain %LT_SUBDOMAIN%
timeout /t 5 /nobreak >nul
echo [OK] LocalTunnel started

:: Setup cleanup function
echo @echo off > cleanup-localtunnel.bat
echo echo. >> cleanup-localtunnel.bat
echo echo [CLEANUP] Shutting down services... >> cleanup-localtunnel.bat
echo taskkill /f /im lt.exe ^>nul 2^>^&1 >> cleanup-localtunnel.bat
echo taskkill /f /im node.exe ^>nul 2^>^&1 >> cleanup-localtunnel.bat
echo echo [OK] Services stopped >> cleanup-localtunnel.bat
echo echo Goodbye! >> cleanup-localtunnel.bat
echo del cleanup-localtunnel.bat >> cleanup-localtunnel.bat

:: Start the application
echo ========================================================================
echo STARTING APPLICATION
echo ========================================================================
echo Local access: http://localhost:3000
echo Global access: https://%LT_SUBDOMAIN%.loca.lt
echo Admin login: admin / admin123
echo ========================================================================
echo Press Ctrl+C to stop all services
echo.

:: Start the Node.js application
node server.js

:: If we get here, the application stopped
echo.
echo [CLEANUP] Application stopped. Cleaning up...
call cleanup-localtunnel.bat

pause
