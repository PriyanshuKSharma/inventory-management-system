# PowerShell script for Windows Native LocalTunnel deployment
param(
    [string]$LTSubdomain = "mqi-rdt-pu-ims"
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Marquardt Inventory Management System - Windows Native LocalTunnel" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor White
Write-Host "Application: Node.js Inventory Management System" -ForegroundColor Cyan
Write-Host "Database: MySQL on Windows" -ForegroundColor Cyan
Write-Host "Local access: http://localhost:3000" -ForegroundColor Yellow
Write-Host "Global access: https://$LTSubdomain.loca.lt" -ForegroundColor Yellow
Write-Host "Admin login: admin / admin123" -ForegroundColor Green
Write-Host "No signup required - instant public URL!" -ForegroundColor Magenta
Write-Host "========================================================================" -ForegroundColor White

try {
    # Check if MySQL is running
    Write-Host "Checking MySQL service..." -ForegroundColor Blue
    $mysqlFound = $false
    
    # Try different MySQL service names
    $services = @("mysql", "mysql80", "mysql57", "mysqld")
    foreach ($service in $services) {
        try {
            $serviceStatus = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceStatus -and $serviceStatus.Status -eq "Running") {
                $mysqlFound = $true
                break
            }
        } catch {}
    }
    
    # Check if mysqld.exe is running as a process
    if (-not $mysqlFound) {
        $mysqlProcess = Get-Process -Name "mysqld" -ErrorAction SilentlyContinue
        if ($mysqlProcess) {
            $mysqlFound = $true
        }
    }
    
    if (-not $mysqlFound) {
        throw "MySQL service not found or not running. Please ensure MySQL is installed and running."
    }
    Write-Host "[OK] MySQL is running" -ForegroundColor Green
    
    # Check database and create if needed
    Write-Host "Checking database setup..." -ForegroundColor Blue
    try {
        & mysql -u sigma -e "CREATE DATABASE IF NOT EXISTS product_management_system;" 2>$null
    } catch {
        try {
            & mysql -u sigma -p -e "CREATE DATABASE IF NOT EXISTS product_management_system;" 2>$null
        } catch {
            throw "Could not connect to MySQL. Please check your MySQL installation."
        }
    }
    
    # Create user if needed
    Write-Host "Setting up database user..." -ForegroundColor Blue
    try {
        & mysql -u sigma -e "CREATE USER IF NOT EXISTS 'sigma'@'localhost' IDENTIFIED BY 'sigma'; GRANT ALL PRIVILEGES ON *.* TO 'sigma'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>$null
    } catch {
        try {
            & mysql -u sigma -p -e "CREATE USER IF NOT EXISTS 'sigma'@'localhost' IDENTIFIED BY 'sigma'; GRANT ALL PRIVILEGES ON *.* TO 'sigma'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>$null
        } catch {
            Write-Host "[WARNING] Could not create user, but continuing..." -ForegroundColor Yellow
        }
    }
    
    # Import database schema if sql file exists
    if (Test-Path "sql\database.sql") {
        Write-Host "Importing database schema..." -ForegroundColor Blue
        try {
            & mysql -u sigma -psigma product_management_system -e "source sql\database.sql" 2>$null
            Write-Host "[OK] Database schema imported successfully" -ForegroundColor Green
        } catch {
            Write-Host "[WARNING] Could not import schema, but continuing..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WARNING] Database schema file not found, but continuing..." -ForegroundColor Yellow
    }
    
    # Test database connection
    Write-Host "Testing database connection..." -ForegroundColor Blue
    try {
        & mysql -u sigma -psigma -e "USE product_management_system; SELECT 1;" 2>$null | Out-Null
        Write-Host "[OK] Database connection successful" -ForegroundColor Green
    } catch {
        throw "Database connection failed. Please check MySQL setup."
    }
    
    # Check if Node.js is installed
    Write-Host "Checking Node.js installation..." -ForegroundColor Blue
    try {
        & node --version | Out-Null
        Write-Host "[OK] Node.js is installed" -ForegroundColor Green
    } catch {
        throw "Node.js is not installed. Please install Node.js from https://nodejs.org/"
    }
    
    # Install dependencies if needed
    if (-not (Test-Path "node_modules")) {
        Write-Host "Installing Node.js dependencies..." -ForegroundColor Blue
        & npm install
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Dependencies installed" -ForegroundColor Green
        } else {
            throw "Failed to install dependencies"
        }
    } else {
        Write-Host "[OK] Dependencies already installed" -ForegroundColor Green
    }
    
    # Create uploads directory
    if (-not (Test-Path "uploads\products")) {
        New-Item -ItemType Directory -Path "uploads\products" -Force | Out-Null
        Write-Host "[OK] Created uploads directory" -ForegroundColor Green
    } else {
        Write-Host "[OK] Uploads directory already exists" -ForegroundColor Green
    }
    
    # Check LocalTunnel installation
    Write-Host "Checking LocalTunnel installation..." -ForegroundColor Blue
    try {
        & lt --version | Out-Null
        Write-Host "[OK] LocalTunnel is installed" -ForegroundColor Green
    } catch {
        Write-Host "Installing LocalTunnel globally..." -ForegroundColor Blue
        & npm install -g localtunnel
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] LocalTunnel installed successfully" -ForegroundColor Green
        } else {
            throw "Failed to install LocalTunnel"
        }
    }
    
    # Set environment variables
    $env:NODE_ENV = "production"
    $env:DB_HOST = "localhost"
    $env:DB_USER = "sigma"
    $env:DB_PASSWORD = "sigma"
    $env:DB_NAME = "product_management_system"
    $env:DB_PORT = "3306"
    $env:SESSION_SECRET = "localtunnel-secret-2025"
    $env:PORT = "3000"
    
    # Email configuration
    $env:EMAIL_USER = "priyanshu17ks.edu@gmail.com"
    $env:EMAIL_PASS = "bztn fcvu zaig dztn"
    $env:ADMIN_EMAIL = "priyanshu17ks.edu@gmail.com"
    
    # Create admin user
    Write-Host "Setting up admin user..." -ForegroundColor Blue
    try {
        & node scripts/create-admin.js | Out-Null
        Write-Host "[OK] Admin user setup completed" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Admin user setup may have issues, but continuing..." -ForegroundColor Yellow
    }
    
    # Start LocalTunnel in background
    Write-Host "Starting LocalTunnel for global access..." -ForegroundColor Blue
    $ltJob = Start-Job -ScriptBlock {
        param($subdomain)
        & lt --port 3000 --subdomain $subdomain
    } -ArgumentList $LTSubdomain
    
    Start-Sleep -Seconds 5
    Write-Host "[OK] LocalTunnel started" -ForegroundColor Green
    
    # Display startup information
    Write-Host "========================================================================" -ForegroundColor White
    Write-Host "STARTING APPLICATION" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor White
    Write-Host "Local access: http://localhost:3000" -ForegroundColor Yellow
    Write-Host "Global access: https://$LTSubdomain.loca.lt" -ForegroundColor Yellow
    Write-Host "Admin login: admin / admin123" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor White
    Write-Host "Press Ctrl+C to stop all services" -ForegroundColor Cyan
    Write-Host ""
    
    # Start the Node.js application
    & node setup-db.js
    & node server.js
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Make sure MySQL is running (XAMPP or standalone MySQL)" -ForegroundColor White
    Write-Host "2. Ensure Node.js is installed" -ForegroundColor White
    Write-Host "3. Check if port 3000 is available" -ForegroundColor White
    Write-Host "4. Verify database credentials (sigma/sigma)" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
} finally {
    # Cleanup
    Write-Host ""
    Write-Host "[CLEANUP] Shutting down services..." -ForegroundColor Yellow
    
    # Stop LocalTunnel
    if ($ltJob) {
        Stop-Job $ltJob -Force
        Remove-Job $ltJob -Force
    }
    
    # Kill LocalTunnel and Node processes
    Get-Process -Name "lt" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "node" -and $_.CommandLine -like "*server.js*" } | Stop-Process -Force
    
    Write-Host "[OK] Services stopped" -ForegroundColor Green
    Write-Host "Goodbye!" -ForegroundColor Green
}
