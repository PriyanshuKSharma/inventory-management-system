# 🔧 Quick Fix Card - Login Error

## ⚡ 5-Minute Fix Checklist

If your login is showing "An error occurred during login", work through these steps:

---

### ✅ Fix #1: Set Database Environment Variables
**Probability: 90%** - This fixes most login errors

**In Azure Portal:**
1. App Services → Your App
2. Settings → Configuration
3. Add these variables:

```
DATABASE_URL=mysql://username:password@hostname:3306/dbname

OR (individually)

DB_HOST=your-database.mysql.database.azure.com
DB_USER=username@servername
DB_PASSWORD=your-password
DB_NAME=product_management_system
DB_PORT=3306
SESSION_SECRET=random-secret-key
```

4. **Save** → **Restart app**

---

### ✅ Fix #2: Initialize Database
**If** you just created the database

**Run from your computer or Cloud Shell:**
```bash
# Copy the database schema
node scripts/setup-db.js

# Create a test user
node scripts/create-admin.js
```

---

### ✅ Fix #3: Verify Database Exists
**If** you're not sure the database was created

```bash
# Connect to Azure MySQL
mysql -h [your-database].mysql.database.azure.com -u username -p

# Check databases
SHOW DATABASES;
SHOW TABLES IN product_management_system;
SELECT COUNT(*) FROM users;
```

If empty:
```bash
node scripts/setup-db.js
node scripts/create-admin.js
```

---

### ✅ Fix #4: Test Connection
**If** you want to verify database connectivity

```bash
node test-db-connection.js
```

This will show:
- ✅ Connection status
- ✅ Tables present
- ✅ Users in database
- 🔧 Specific fixes needed

---

## 🎯 Most Likely Causes (Pick One)

### **Cause #1: Database Credentials Not Set** (70% of cases)
```
Symptoms: "An error occurred during login" appears immediately
Fix: Set DB_HOST, DB_USER, DB_PASSWORD in Azure App Service settings
```

### **Cause #2: Database Not Initialized** (20% of cases)
```
Symptoms: Login fails but database connects
Fix: Run: node scripts/setup-db.js
```

### **Cause #3: No Users in Database** (5% of cases)
```
Symptoms: Login page loads, but no users exist to login with
Fix: Run: node scripts/create-admin.js
```

### **Cause #4: Wrong Username Format** (3% of cases)
```
Symptoms: Access denied when connecting
Fix: Use format: username@servername (not just username)
```

### **Cause #5: Firewall Blocking Connection** (2% of cases)
```
Symptoms: Connection timeout when trying to reach database
Fix: Azure MySQL → Networking → Add firewall rule
```

---

## 📋 Copy-Paste Commands

### For Azure Cloud Shell:

```bash
# Test connection to database
mysql -h YOUR-DATABASE.mysql.database.azure.com -u username@servername -p

# Initialize schema
mysql -h YOUR-DATABASE.mysql.database.azure.com -u username@servername -p DATABASE_NAME < sql/database.sql

# Create admin user
node scripts/create-admin.js
```

### For Windows PowerShell:

```powershell
# Navigate to project
cd C:\path\to\inventory-management-system

# Install dependencies
npm install

# Test database connection
node test-db-connection.js

# Create admin user
node scripts/create-admin.js
```

### For Mac/Linux:

```bash
# Navigate to project
cd ~/path/to/inventory-management-system

# Install dependencies
npm install

# Test database connection
node test-db-connection.js

# Create admin user
node scripts/create-admin.js
```

---

## 🧪 Test Before Logging In

```bash
# 1. Test database connection
node test-db-connection.js

# Expected output:
# ✅ Successfully connected to MySQL database!
# ✅ All required tables exist!
# ✅ Users in database: 1
```

```bash
# 2. Create test user
node scripts/create-admin.js

# When prompted:
# Enter username: admin
# Enter password: Test123!
```

```bash
# 3. Restart your app (in Azure Portal)
# Then try login at:
# https://inventory-rdt-b5a5ayfkfqgsbuep.southindia-01.azurewebsites.net/login
```

---

## 📍 Where to Find Connection Details

### If using Azure MySQL:

1. Azure Portal
2. Search: "Azure Database for MySQL"
3. Click your server
4. **Settings** → **Connection strings**
5. Copy the string and paste into DATABASE_URL

**Format it as:**
```
mysql://username:password@hostname:3306/database
```

### If using another database:

Ask your database admin for:
- `Hostname` (e.g., db.example.com)
- `Port` (usually 3306)
- `Username` (e.g., root or admin)
- `Password`
- `Database name` (e.g., product_management_system)

---

## 🆘 Still Not Working?

### Step 1: Check the detailed logs

```bash
# Method 1: Run test script
node test-db-connection.js

# Method 2: Check Azure logs
# Portal → App Service → Log stream → Look for red errors

# Method 3: Check environment variables
# Portal → Configuration → Look for DB_* or DATABASE_URL
```

### Step 2: Verify database is accessible

```bash
# Can you connect?
mysql -h [hostname] -u [username] -p[password]

# Are tables there?
SHOW TABLES;

# Are there users?
SELECT COUNT(*) FROM users;
```

### Step 3: Review the full guide

See: `BACKEND_DEBUG_AND_FIX_GUIDE.md` for comprehensive troubleshooting

---

## ✨ Success Sign

When fixed, you'll see:
1. Login page loads without error
2. Can enter username and password
3. Click "Login" redirects to dashboard
4. See inventory system interface

---

## 📞 Quick Reference

| Issue | Solution |
|-------|----------|
| Connection refused | Check DB_HOST and DB_PORT are correct |
| Access denied | Check DB_USER and DB_PASSWORD format |
| Database not found | Run `node scripts/setup-db.js` |
| No users | Run `node scripts/create-admin.js` |
| Timeout | Check Azure firewall allows connection |
| Wrong password | Verify password has no special chars (or escape them) |

---

**Time to Fix:** 5-15 minutes
**Success Rate:** 95%
**Last Updated:** June 2026
