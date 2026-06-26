# Azure App Service Configuration Guide

## 🎯 Quick Setup for Azure Deployment

Your app is running on Azure App Service at:
```
https://inventory-rdt-b5a5ayfkfqgsbuep.southindia-01.azurewebsites.net/
```

### Region: South India ☀️

---

## ⚙️ Step-by-Step Azure Configuration

### Step 1: Navigate to Azure Portal

1. Go to: https://portal.azure.com
2. Search for: **App Services**
3. Click your app name: `inventory-rdt` (or similar)
4. Left sidebar → **Settings** → **Configuration**

---

### Step 2: Add Environment Variables

Click **+ New application setting** for each variable:

#### Required Variables for Login to Work:

```
Name:  DATABASE_URL
Value: mysql://[username]:[password]@[hostname]:3306/[database]

Example:
DATABASE_URL=mysql://sqlroot:MyPassword123!@inventory-db.mysql.database.azure.com:3306/product_management_system
```

OR use individual variables:

```
Name:  DB_HOST
Value: [your-database].mysql.database.azure.com

Name:  DB_USER
Value: [username]@[servername]

Name:  DB_PASSWORD
Value: [your-password]

Name:  DB_NAME
Value: product_management_system

Name:  DB_PORT
Value: 3306

Name:  SESSION_SECRET
Value: [generate-random-string]
```

---

## 📋 Finding Your Database Credentials

### If you have Azure MySQL already:

1. Go to **Azure Database for MySQL** → Your server
2. **Connection strings** → Copy the connection string
3. Format it as: `mysql://user:password@host:3306/dbname`

### If you need to create a database:

1. **Create** → **Azure Database for MySQL**
2. Enter:
   - Server name: `inventory-db`
   - Admin username: `sqlroot`
   - Password: `[Strong Password!]`
   - Networking: Allow access from Azure services

---

## 🔒 Azure MySQL Configuration

### 1. Create Database and Tables

After creating the MySQL server:

```bash
# Connect to Azure MySQL from your computer
mysql -h [server].mysql.database.azure.com -u sqlroot -p

# Create database
CREATE DATABASE IF NOT EXISTS product_management_system;
USE product_management_system;

# Run the schema (copy from sql/database.sql)
```

Or use Cloud Shell:

```bash
# In Azure Cloud Shell
mysql -h [server].mysql.database.azure.com -u sqlroot@[server] -p[password] < sql/database.sql
```

### 2. Configure Firewall

1. Go to **Azure MySQL server** → **Networking**
2. Under **Firewall rules**, add:
   - **Rule name**: `AllowAzureServices`
   - **Start IP**: 0.0.0.0
   - **End IP**: 0.0.0.0
3. Click **Save**

---

## 🧪 Test Your Configuration

After setting environment variables:

1. **Stop** and **Restart** your App Service
   - Portal → App Service → **Restart**

2. **Check logs:**
   - Portal → App Service → **Monitoring** → **Log stream**
   - Look for: `Database connected successfully`

3. **Test the application:**
   - Visit: https://inventory-rdt-b5a5ayfkfqgsbuep.southindia-01.azurewebsites.net/login
   - Try to login

---

## 📋 Environment Variables Checklist

### Copy this template and fill in your values:

```
# Database Configuration (choose one method)
METHOD_1_CONNECTION_STRING=
DATABASE_URL=mysql://[user]:[password]@[host]:3306/[database]

# OR Method 2: Individual variables
DB_HOST=
DB_USER=
DB_PASSWORD=
DB_NAME=product_management_system
DB_PORT=3306

# Application Settings
NODE_ENV=production
PORT=8080
SESSION_SECRET=[generate random string]

# Email Settings (Optional but recommended)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=[your-email]
EMAIL_PASS=[app-specific-password]
ADMIN_EMAIL=[admin-email]
```

---

## 🚀 Deployment Workflow

1. **Set environment variables** (above)
2. **Restart the app** (Portal → Restart)
3. **Initialize database** (if not done yet):
   - In Azure Cloud Shell or local MySQL:
     ```bash
     mysql -h [server] -u [user] -p[pass] [db] < sql/database.sql
     node scripts/create-admin.js
     ```
4. **Test login** at the Azure URL
5. **Check logs** if issues occur

---

## 🐛 Troubleshooting

### Issue: "An error occurred during login"

**Check these in order:**

1. **Are environment variables set?**
   ```
   Portal → App Service → Configuration → Review all variables
   ```

2. **Is the database reachable?**
   ```bash
   # Test locally
   node test-db-connection.js
   ```

3. **Do tables exist?**
   ```sql
   SHOW TABLES IN product_management_system;
   DESCRIBE users;
   ```

4. **Are there any users?**
   ```sql
   SELECT COUNT(*) FROM users;
   ```

5. **Check Azure logs:**
   ```
   Portal → Log Stream → Filter for errors
   ```

---

## 📱 Connection String Formats

### Format 1: Standard MySQL URL
```
mysql://sqlroot:Password123!@inventory-db.mysql.database.azure.com:3306/product_management_system
```

### Format 2: Azure Portal Export Format
```
Server=inventory-db.mysql.database.azure.com;Database=product_management_system;Uid=sqlroot;Pwd=Password123!;
```

### Format 3: Individual Variables
```
DB_HOST=inventory-db.mysql.database.azure.com
DB_USER=sqlroot@inventory-db
DB_PASSWORD=Password123!
DB_NAME=product_management_system
DB_PORT=3306
```

---

## 🔐 Security Best Practices

1. **Use strong passwords** (min 8 chars, mix of case + numbers + symbols)
2. **Don't commit .env files** to source control
3. **Use Azure Key Vault** for sensitive values (advanced)
4. **Enable SSL** for MySQL connections
5. **Restrict firewall** to specific IPs when possible
6. **Rotate credentials** regularly

---

## 📞 Getting Help

If login still doesn't work:

1. **Run the diagnostic:**
   ```bash
   node test-db-connection.js
   ```

2. **Check Azure logs:**
   - App Service → Log stream
   - Look for error messages

3. **Review the fix guide:**
   - See: `BACKEND_DEBUG_AND_FIX_GUIDE.md`

4. **Common issues:**
   - Missing DATABASE_URL or DB_* variables
   - Database doesn't exist or not initialized
   - Firewall blocking connection
   - Wrong username format (should be: username@servername)

---

## ✅ Success Indicators

When everything is working:

- ✅ `Database connected successfully` in logs
- ✅ Users table has test users
- ✅ Login page loads at the Azure URL
- ✅ Can login with valid credentials
- ✅ Redirects to appropriate dashboard

---

**Last Updated:** June 2026
**Application:** Inventory Management System
**Hosting:** Azure App Service (South India)
