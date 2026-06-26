# 🔧 Inventory Management System - Backend Login Error Diagnosis & Fix

## 📋 Problem Summary
**Error:** "An error occurred during login" when attempting to access the Azure-hosted inventory management system at:
```
https://inventory-rdt-b5a5ayfkfqgsbuep.southindia-01.azurewebsites.net/login
```

---

## 🔍 Root Cause Analysis

### Primary Issue: Database Connection Failure
The login error at line 502 in `server.js` indicates the backend is catching an exception in the login handler. The most common cause is:

```javascript
} catch (error) {
    console.error('Login error:', error);
    req.flash('error', 'An error occurred during login');
    return res.redirect('/login');
}
```

### Likely Culprits (in order of probability):

1. **❌ Missing/Invalid Database Connection** (90% probability)
   - Database credentials not configured in Azure App Service environment variables
   - Connection string format incorrect for Azure MySQL
   - Database server offline or unreachable

2. **❌ Missing Environment Variables** (70% probability)
   - `DATABASE_URL` not set in Azure App Service
   - `MYSQLCONNSTR_DEFAULT` not configured
   - Database host, user, password missing

3. **❌ Database Not Initialized** (60% probability)
   - Database schema/tables not created
   - Users table empty (no test user to login with)
   - Required columns missing from users table

4. **❌ Firewall/Network Issues** (40% probability)
   - Azure App Service can't reach the database server
   - Database firewall rules blocking the connection
   - VNet security group restrictions

---

## ✅ Step-by-Step Diagnostic & Fix Guide

### **STEP 1: Check Environment Variables in Azure**

Your app is running on **Azure App Service**. The backend expects database credentials as environment variables.

#### **Action Items:**

1. **Go to Azure Portal** → App Services → Your App → Settings → Configuration

2. **Verify these environment variables exist:**

```
DATABASE_URL  
OR
MYSQLCONNSTR_DEFAULT

Plus individual variables:
- DB_HOST
- DB_USER (or DB_USERNAME)
- DB_PASSWORD
- DB_NAME (or DB_DATABASE)
- DB_PORT
- SESSION_SECRET
```

3. **For Azure MySQL, use one of these formats:**

**Option A: Connection String (Recommended)**
```
DATABASE_URL=mysql://username:password@hostname:3306/database_name
```
Example:
```
DATABASE_URL=mysql://sqlroot:YourPassword123@inventory-db.mysql.database.azure.com:3306/product_management_system
```

**Option B: Individual Variables**
```
DB_HOST=inventory-db.mysql.database.azure.com
DB_USER=sqlroot
DB_PASSWORD=YourPassword123
DB_NAME=product_management_system
DB_PORT=3306
```

---

### **STEP 2: Verify Database Connection String Parsing**

The code at line 144-190 of `server.js` attempts to parse connection strings. Let's verify it works:

#### **Check if parsing is working:**

Look at your Azure connection string format. The code expects:

**Format 1:** Standard MySQL URL
```
mysql://user:password@host:port/database
```

**Format 2:** Azure Portal format (with semicolons)
```
Server=hostname;Database=dbname;Uid=username;Pwd=password;
```

**Format 3:** Connection string with server and initial catalog
```
server=hostname;user id=username;password=password;initial catalog=dbname;
```

---

### **STEP 3: Check Database Exists and Tables Are Created**

The login fails because the query at line 421-423 can't execute:

```javascript
const [users] = await pool.execute(
    'SELECT u.*, e.department_id FROM users u LEFT JOIN employees e ON u.user_id = e.user_id WHERE u.username = ? AND u.is_active = 1 LIMIT 1',
    [username]
);
```

#### **Required: Run Database Setup**

You need to:

1. **Connect to your Azure MySQL database** (use MySQL Workbench, DBeaver, or Azure Cloud Shell)

2. **Run the database initialization script:**
   ```bash
   node scripts/setup-db.js
   ```
   
   OR manually execute the SQL from `sql/database.sql`

3. **Create at least one test user:**
   ```bash
   node scripts/create-admin.js
   ```

4. **Verify tables exist:**
   ```sql
   SHOW TABLES;
   DESCRIBE users;
   DESCRIBE employees;
   ```

---

### **STEP 4: Enable Database Logging to Diagnose Issues**

Since the error is generic, enable more detailed logging:

#### **Edit `server.js` line 500-504:**

Replace:
```javascript
} catch (error) {
    console.error('Login error:', error);
    req.flash('error', 'An error occurred during login');
    return res.redirect('/login');
}
```

With:
```javascript
} catch (error) {
    console.error('🔴 Login error details:');
    console.error('   Error Message:', error.message);
    console.error('   Error Code:', error.code);
    console.error('   SQL State:', error.sqlState);
    console.error('   Full Error:', error);
    
    // Log more info about the failure point
    if (error.code === 'ER_ACCESS_DENIED_ERROR') {
        console.error('   ❌ Database authentication failed - check DB_USER and DB_PASSWORD');
    } else if (error.code === 'ER_BAD_DB_ERROR') {
        console.error('   ❌ Database does not exist - run setup-db.js');
    } else if (error.code === 'ENOTFOUND' || error.code === 'ECONNREFUSED') {
        console.error('   ❌ Cannot reach database server - check DB_HOST and network');
    }
    
    req.flash('error', 'An error occurred during login');
    return res.redirect('/login');
}
```

---

### **STEP 5: Test Database Connection**

Create a simple test file to verify the connection:

#### **Create `/test-db.js`:**

```javascript
const mysql = require('mysql2/promise');
require('dotenv').config();

const parseMySqlConnectionString = (connectionString) => {
    if (!connectionString) return null;
    const value = connectionString.trim();
    
    if (value.startsWith('mysql://') || value.startsWith('mysqls://')) {
        const parsed = new URL(value);
        return {
            host: parsed.hostname,
            port: parsed.port ? Number(parsed.port) : 3306,
            user: decodeURIComponent(parsed.username),
            password: decodeURIComponent(parsed.password),
            database: parsed.pathname ? parsed.pathname.replace(/^\//, '') : undefined,
            ssl: value.startsWith('mysqls://') ? { rejectUnauthorized: false } : undefined
        };
    }
    return null;
};

async function testConnection() {
    console.log('🧪 Testing database connection...\n');
    
    const azureConnectionString =
        process.env.DATABASE_URL ||
        process.env.MYSQLCONNSTR_DEFAULT ||
        Object.entries(process.env).find(([key]) => key.startsWith('MYSQLCONNSTR_'))?.[1] ||
        null;
    
    const connectionFromAzure = parseMySqlConnectionString(azureConnectionString);
    
    const dbConfig = connectionFromAzure || {
        host: process.env.DB_HOST || 'localhost',
        user: process.env.DB_USER || process.env.DB_USERNAME || 'sigma',
        password: process.env.DB_PASSWORD || 'sigma',
        database: process.env.DB_NAME || process.env.DB_DATABASE || 'product_management_system',
        port: process.env.DB_PORT || 3306,
        ssl: { rejectUnauthorized: false }
    };
    
    console.log('📋 Using config:');
    console.log('   Host:', dbConfig.host);
    console.log('   User:', dbConfig.user);
    console.log('   Database:', dbConfig.database);
    console.log('   Port:', dbConfig.port);
    console.log('   SSL:', !!dbConfig.ssl);
    console.log('');
    
    try {
        const pool = mysql.createPool(dbConfig);
        const connection = await pool.getConnection();
        
        console.log('✅ Database connection successful!');
        
        // Check if users table exists
        const [tables] = await connection.execute(
            "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'"
        );
        
        if (tables.length === 0) {
            console.log('❌ Users table does not exist');
            console.log('   Run: node scripts/setup-db.js');
        } else {
            console.log('✅ Users table exists');
            
            // Count users
            const [users] = await connection.execute('SELECT COUNT(*) as count FROM users');
            console.log(`   Users in database: ${users[0].count}`);
            
            if (users[0].count === 0) {
                console.log('   ⚠️  No users in database');
                console.log('   Run: node scripts/create-admin.js');
            }
        }
        
        connection.release();
        pool.end();
        
    } catch (error) {
        console.error('❌ Connection failed!');
        console.error('\nError Details:');
        console.error('   Code:', error.code);
        console.error('   Message:', error.message);
        console.error('   SQL State:', error.sqlState);
        
        if (error.code === 'ER_ACCESS_DENIED_ERROR') {
            console.error('\n🔧 Fix: Check DB_USER and DB_PASSWORD');
        } else if (error.code === 'ENOTFOUND') {
            console.error('\n🔧 Fix: Check DB_HOST - cannot reach the server');
        } else if (error.code === 'ECONNREFUSED') {
            console.error('\n🔧 Fix: Check DB_PORT and that MySQL is running');
        }
    }
}

testConnection();
```

#### **Run it locally:**
```bash
node test-db.js
```

---

## 📝 Azure Configuration Checklist

Create/Update your `.env` file for Azure with these settings:

```bash
# ==========================================
# AZURE DEPLOYMENT CONFIGURATION
# ==========================================

NODE_ENV=production
PORT=8080

# ⚠️ IMPORTANT: Set this in Azure App Service Settings > Configuration
# The connection string should be in ONE of these formats:

# Option 1: Full URL format
DATABASE_URL=mysql://username:password@hostname:3306/database_name

# Option 2: Azure MySQL standard format  
MYSQLCONNSTR_DEFAULT=Server=hostname;Database=dbname;Uid=username;Pwd=password;

# Option 3: Individual environment variables
DB_HOST=hostname.mysql.database.azure.com
DB_USER=username@servername
DB_PASSWORD=your_secure_password
DB_NAME=product_management_system
DB_PORT=3306

# Session secret (should be a random string in production)
SESSION_SECRET=$(openssl rand -hex 32)

# Email configuration
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your_email@gmail.com
EMAIL_PASS=your_app_password
ADMIN_EMAIL=admin@company.com
```

---

## 🚨 Common Errors & Solutions

### Error 1: "connect ENOTFOUND"
**Cause:** Cannot resolve hostname
```
Fix:
1. Check DB_HOST is correct (should end with .mysql.database.azure.com)
2. Verify database server is running in Azure
3. Check Azure firewall allows connections
```

### Error 2: "ER_ACCESS_DENIED_ERROR"
**Cause:** Username or password incorrect
```
Fix:
1. In Azure, user format is: username@servername (not just username)
2. Verify password doesn't have special characters (or escape them)
3. Check the user has correct permissions in MySQL
```

### Error 3: "ER_BAD_DB_ERROR"
**Cause:** Database doesn't exist
```
Fix:
1. Run: node scripts/setup-db.js
2. Or manually create the database in Azure MySQL
```

### Error 4: "Table 'database.users' doesn't exist"
**Cause:** Tables not initialized
```
Fix:
1. Connect to Azure MySQL directly
2. Run the SQL from: sql/database.sql
3. Or run: node scripts/setup-db.js
```

### Error 5: "Invalid username or password" (but credentials are correct)
**Cause:** User doesn't exist in database
```
Fix:
1. Run: node scripts/create-admin.js
2. Enter username and password when prompted
3. Try login again with those credentials
```

---

## 🔐 Security Notes for Production

When deploying to Azure:

1. **Never commit `.env` files** to version control
2. **Use Azure Key Vault** for sensitive credentials
3. **Enable SSL** for database connections (use `mysqls://`)
4. **Set `SESSION_SECRET`** to a strong random value
5. **Use Azure Managed Identity** instead of hardcoded credentials (advanced)
6. **Enable Azure MySQL firewall** and restrict to App Service IP

---

## 🧪 Testing the Login After Fixes

1. **Verify database is ready:**
   ```bash
   node test-db.js
   ```

2. **Check users exist:**
   ```bash
   node scripts/create-admin.js
   ```

3. **Start the server locally to test:**
   ```bash
   npm start
   ```

4. **Try login at:** `http://localhost:3000/login`

5. **Monitor logs in Azure:**
   - Azure Portal → App Service → Monitoring → Logs
   - Or use: `az webapp log tail --name <app-name> --resource-group <group-name>`

---

## 📞 Additional Resources

- **Database SQL Schema:** `sql/database.sql`
- **Setup Script:** `scripts/setup-db.js`
- **Admin Creation:** `scripts/create-admin.js`
- **Deployment Guide:** `deployment/COMPLETE-INSTALLATION-GUIDE.md`
- **Docker Guide:** `docs/DOCKER_DEPLOYMENT_GUIDE.md`
- **Azure Guide:** `docs/GCP_DEPLOYMENT_GUIDE.md` (has Azure section)

---

## 🎯 Quick Fix Checklist

- [ ] Verify all environment variables set in Azure App Service
- [ ] Test database connection with `test-db.js`
- [ ] Run `scripts/setup-db.js` to initialize database
- [ ] Create a test user with `scripts/create-admin.js`
- [ ] Check Azure MySQL firewall allows App Service IP
- [ ] Enable detailed logging in `server.js`
- [ ] Check Azure App Service logs for detailed errors
- [ ] Test login locally before deploying again
- [ ] Verify `package.json` dependencies are installed (`npm install`)
- [ ] Check Node.js version is >=18.0.0 in Azure

---

## 📊 Login Flow Diagram

```
User Input (username/password)
         ↓
[POST /login] handler receives request
         ↓
Query database: SELECT users WHERE username = ? AND is_active = 1
         ↓ (DATABASE CONNECTION FAILS HERE? ← Main Issue)
         ↓
If user not found → "Invalid username or password"
         ↓
If found → Verify password with bcrypt
         ↓
If password invalid → "Invalid username or password"
         ↓
If valid → Create session (req.session.user = {...})
         ↓
Redirect to role-specific dashboard (/admin/dashboard, /monitor/dashboard, /employee/dashboard)
```

---

**Last Updated:** June 2026
**Status:** Backend Database Connection Issue
**Priority:** 🔴 Critical - Blocks Login Functionality
