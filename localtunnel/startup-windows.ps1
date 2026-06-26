# Marquardt Inventory Management System - Windows PowerShell Startup Script
# PowerShell version for modern Windows systems

param(
    [string]$Subdomain = "project-interns-app"
)

# Enable strict mode
Set-StrictMode -Version Latest

# Colors for output
function Write-Header { param($Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }

Write-Header "🚀 Starting Marquardt Inventory Management System on Windows"
Write-Header "================================================================="
Write-Header "📦 Application: Node.js Inventory Management System"
Write-Header "🗄️  Database: MySQL on Windows"
Write-Header "🌐 Local access: http://localhost:3001"
Write-Header "🌍 Global access via LocalTunnel"
Write-Header "📊 Admin login: admin / password"
Write-Header "================================================================="

# Function to check if a service is running
function Test-ServiceRunning {
    param([string]$ServiceName)
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        return $service.Status -eq "Running"
    }
    catch {
        return $false
    }
}

# Function to check if a process is running
function Test-ProcessRunning {
    param([string]$ProcessName)
    try {
        $process = Get-Process -Name $ProcessName -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Check MySQL service
Write-Host "🔍 Checking MySQL service..." -NoNewline
if (Test-ServiceRunning -ServiceName "MySQL*") {
    Write-Success " ✅ MySQL is already running"
} else {
    Write-Warning " ⚠️  MySQL is not running. Attempting to start..."
    try {
        Start-Service -Name "MySQL*" -ErrorAction Stop
        Start-Sleep -Seconds 3
        Write-Success "✅ MySQL started successfully"
    }
    catch {
        Write-Error "❌ Failed to start MySQL. Please start it manually."
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Test database connection
Write-Host "🔍 Checking database connection..."
try {
    $result = mysql -u sigma -psigma -e "USE product_management_system; SELECT 1;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Database connection successful"
    } else {
        throw "Database connection failed"
    }
}
catch {
    Write-Error "❌ Database connection failed. Please check your MySQL setup."
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Check Node.js installation
Write-Host "🔍 Checking Node.js installation..."
try {
    $nodeVersion = node --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Node.js is installed: $nodeVersion"
    } else {
        throw "Node.js not found"
    }
}
catch {
    Write-Error "❌ Node.js is not installed. Please install Node.js first."
    Write-Host "Download from: https://nodejs.org/"
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Install dependencies if needed
if (!(Test-Path "node_modules")) {
    Write-Host "📦 Installing Node.js dependencies..."
    npm install
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Dependencies installed"
    } else {
        Write-Error "❌ Failed to install dependencies"
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Create uploads directory
if (!(Test-Path "uploads\products")) {
    New-Item -Path "uploads\products" -ItemType Directory -Force | Out-Null
    Write-Success "📁 Created uploads directory"
} else {
    Write-Success "📁 Uploads directory exists"
}

# Check LocalTunnel installation
Write-Host "🔍 Checking LocalTunnel installation..."
try {
    lt --version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ LocalTunnel is installed"
    } else {
        throw "LocalTunnel not found"
    }
}
catch {
    Write-Warning "⚠️  LocalTunnel not found. Installing LocalTunnel globally..."
    npm install -g localtunnel
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ LocalTunnel installed successfully"
    } else {
        Write-Error "❌ Failed to install LocalTunnel"
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Setup cleanup handler
$cleanup = {
    Write-Host ""
    Write-Warning "🛑 Shutting down services..."
    Get-Process -Name "lt" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Success "✅ Services stopped"
    Write-Success "👋 Goodbye!"
}

# Register cleanup for Ctrl+C
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanup

# Start LocalTunnel
Write-Host "🌐 Starting LocalTunnel for global access..."
$ltProcess = Start-Process -FilePath "lt" -ArgumentList "--port", "3001", "--subdomain", $Subdomain -NoNewWindow -PassThru
Start-Sleep -Seconds 3
Write-Success "✅ LocalTunnel started with PID: $($ltProcess.Id)"
Write-Success "🌍 Global URL: https://$Subdomain.loca.lt"

# Create admin users
Write-Host "👤 Setting up admin user..."
node scripts/create-admin.js
if ($LASTEXITCODE -ne 0) {
    Write-Warning "⚠️  Warning: Admin user setup may have issues, but continuing..."
}

# Start the application
Write-Header "🚀 Starting the application..."
Write-Header "================================================================="
Write-Header "🌐 Local access: http://localhost:3001"
Write-Header "🌍 Global access: https://$Subdomain.loca.lt"
Write-Header "📊 Login credentials:"
Write-Header "   Username: GuddiS | Password: Welcome@123"
Write-Header "   Username: KatragaddaV | Password: Welcome@123"
Write-Header "================================================================="
Write-Header "Press Ctrl+C to stop all services"
Write-Host ""

try {
    # Start Node.js application
    node server.js
}
finally {
    # Cleanup on exit
    & $cleanup
}
