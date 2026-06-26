#!/bin/bash

# 🏢 Marquardt India Pvt. Ltd. - Comprehensive Setup Script
# Supports Linux, macOS, and Windows (Git Bash/WSL)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${CYAN}🚀 $1${NC}"
}

# Main setup function
main() {
    clear
    echo "=================================================================="
    echo "🏢 Marquardt India Pvt. Ltd. - Asset Management System Setup"
    echo "=================================================================="
    echo ""
    
    # Move to project root if we're in scripts directory
    if [[ "$(basename "$PWD")" == "scripts" ]]; then
        cd ..
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Install dependencies
    install_dependencies
    
    # Create directories
    create_directories
    
    # Setup database
    setup_database
    
    # Configure environment
    configure_environment
    
    # Initialize application
    initialize_application
    
    # Start application
    start_application
}

# Check if required tools are installed
check_prerequisites() {
    print_header "Checking Prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 20+ from https://nodejs.org/"
        exit 1
    fi
    print_status "Node.js $(node --version) found"
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm"
        exit 1
    fi
    print_status "npm $(npm --version) found"
    
    # Check MySQL
    if ! command -v mysql &> /dev/null; then
        print_warning "MySQL client not found. Please ensure MySQL is installed and accessible"
        print_info "You can install MySQL from: https://dev.mysql.com/downloads/"
    else
        print_status "MySQL client found"
    fi
    
    echo ""
}

# Install Node.js dependencies
install_dependencies() {
    print_header "Installing Dependencies..."
    
    if [ -f "package.json" ]; then
        npm install
        print_status "Node.js dependencies installed successfully"
    else
        print_error "package.json not found. Are you in the correct directory?"
        exit 1
    fi
    
    echo ""
}

# Create necessary directories
create_directories() {
    print_header "Creating Directories..."
    
    # Create required directories
    mkdir -p public/css/dist
    mkdir -p logs
    mkdir -p uploads/products
    mkdir -p sql
    
    print_status "Required directories created"
    echo ""
}

# Setup database
setup_database() {
    print_header "Database Setup..."
    
    # Check if database.sql exists
    if [ ! -f "sql/database.sql" ] && [ ! -f "database.sql" ]; then
        print_error "Database schema file not found (sql/database.sql or database.sql)"
        exit 1
    fi
    
    # Determine database file location
    DB_FILE="sql/database.sql"
    if [ ! -f "$DB_FILE" ] && [ -f "database.sql" ]; then
        DB_FILE="database.sql"
    fi
    
    print_info "Database setup instructions:"
    echo "1. Ensure MySQL server is running"
    echo "2. Create database: product_management_system"
    echo "3. Import schema from: $DB_FILE"
    echo ""
    
    read -p "Do you want to setup the database automatically? (y/n): " setup_db
    
    if [[ $setup_db =~ ^[Yy]$ ]]; then
        read -p "Enter MySQL username: " mysql_user
        read -sp "Enter MySQL password: " mysql_pass
        echo ""
        
        # Create database and import schema
        mysql -u "$mysql_user" -p"$mysql_pass" << EOF
CREATE DATABASE IF NOT EXISTS product_management_system;
USE product_management_system;
SOURCE $DB_FILE;
EOF
        
        if [ $? -eq 0 ]; then
            print_status "Database setup completed successfully"
        else
            print_error "Database setup failed. Please check your credentials and try again"
            exit 1
        fi
    else
        print_warning "Skipping automatic database setup"
        print_info "Please manually create the database and import $DB_FILE"
    fi
    
    echo ""
}

# Configure environment variables
configure_environment() {
    print_header "Environment Configuration..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            print_status "Created .env from .env.example"
        else
            # Create basic .env file
            cat > .env << EOF
# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=product_management_system
DB_PORT=3306

# Application Settings
SESSION_SECRET=your_session_secret_key_here
PORT=3000
NODE_ENV=development

# Email Configuration (Optional for local development)
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-gmail-app-password
EOF
            print_status "Created basic .env file"
        fi
        
        print_warning "Please update the .env file with your database credentials"
        print_info "Edit .env file and update DB_USER, DB_PASSWORD, and SESSION_SECRET"
        
        read -p "Press Enter after updating .env file..."
    else
        print_status ".env file already exists"
    fi
    
    echo ""
}

# Initialize application
initialize_application() {
    print_header "Initializing Application..."
    
    # Create admin account (if script exists)
    if [ -f "scripts/create-admin.js" ]; then
        print_info "Creating admin account..."
        if node scripts/create-admin.js; then
            print_status "Admin account created successfully"
        else
            print_warning "Failed to create admin account - you may need to do this manually"
        fi
    fi
    
    # Setup database connection (if script exists)
    if [ -f "setup-db.js" ]; then
        print_info "Configuring database connection..."
        if node setup-db.js; then
            print_status "Database connection configured successfully"
        else
            print_warning "Failed to setup database connection - check your configuration"
        fi
    fi
    
    echo ""
}

# Start the application
start_application() {
    print_header "Starting Application..."
    
    echo "=================================================================="
    echo "🎉 Setup Complete!"
    echo "=================================================================="
    echo ""
    echo "📋 Next Steps:"
    echo "1. Access the application at: http://localhost:3000"
    echo "2. Default admin login: admin / admin123"
    echo "3. Change default passwords immediately after first login"
    echo ""
    echo "📧 Email Service (Optional):"
    echo "- Configure EMAIL_USER and EMAIL_PASS in .env for notifications"
    echo "- Use Gmail app password for EMAIL_PASS"
    echo ""
    echo "🚀 Production Deployment:"
    echo "- See COMPREHENSIVE_DEPLOYMENT_GUIDE.md for GCP deployment"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo "=================================================================="
    echo ""
    
    # Start development server
    if [ -f "package.json" ]; then
        if npm run dev; then
            print_status "Application started successfully"
        else
            print_error "Failed to start application"
            print_info "Try running 'npm start' manually"
        fi
    else
        print_error "package.json not found"
    fi
}

# Handle script interruption
cleanup() {
    echo ""
    print_info "Setup interrupted. You can run this script again to continue."
    exit 1
}

# Set trap for cleanup
trap cleanup INT

# Run main function
main "$@"
