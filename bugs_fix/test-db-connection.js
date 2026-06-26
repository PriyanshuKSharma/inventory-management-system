/**
 * Database Connection Tester
 * Use this script to diagnose database connectivity issues
 * 
 * Usage:
 *   node test-db-connection.js
 * 
 * This will:
 * 1. Test the database connection
 * 2. Verify tables exist
 * 3. Check for test users
 * 4. Provide detailed error messages for debugging
 */

const mysql = require('mysql2/promise');
require('dotenv').config();

/**
 * Parse MySQL connection string from various formats
 * Supports: mysql://, mysqls://, and semicolon-delimited formats
 */
const parseMySqlConnectionString = (connectionString) => {
    if (!connectionString) {
        return null;
    }

    const value = connectionString.trim();

    // Handle mysql:// or mysqls:// format
    if (value.startsWith('mysql://') || value.startsWith('mysqls://')) {
        try {
            const parsed = new URL(value);
            return {
                host: parsed.hostname,
                port: parsed.port ? Number(parsed.port) : 3306,
                user: decodeURIComponent(parsed.username),
                password: decodeURIComponent(parsed.password),
                database: parsed.pathname ? parsed.pathname.replace(/^\//, '') : undefined,
                ssl: value.startsWith('mysqls://') ? { rejectUnauthorized: false } : undefined
            };
        } catch (err) {
            console.error('❌ Failed to parse connection string:', err.message);
            return null;
        }
    }

    // Handle semicolon-delimited format (Azure/ODBC style)
    const parts = value.split(';').reduce((accumulator, segment) => {
        const [key, ...rest] = segment.split('=');

        if (!key || rest.length === 0) {
            return accumulator;
        }

        accumulator[key.trim().toLowerCase()] = rest.join('=').trim();
        return accumulator;
    }, {});

    if (!parts.server && !parts.host) {
        return null;
    }

    const server = parts.server || parts.host;
    const [host, port] = server.split(':');

    return {
        host,
        port: port ? Number(port) : 3306,
        user: parts['user id'] || parts.uid || parts.user || parts.username,
        password: parts.password || parts.pwd,
        database: parts.database || parts['initial catalog'] || parts.db,
        ssl: /required/i.test(parts.sslmode || '') ? { rejectUnauthorized: false } : undefined
    };
};

/**
 * Main test function
 */
async function testConnection() {
    console.log('\n' + '='.repeat(70));
    console.log('🧪 DATABASE CONNECTION TESTER');
    console.log('='.repeat(70) + '\n');

    // Step 1: Gather configuration
    console.log('📋 Step 1: Reading Configuration');
    console.log('-'.repeat(70));

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
        ssl: (process.env.DB_HOST && process.env.DB_HOST !== 'localhost') 
            ? { rejectUnauthorized: false } 
            : undefined
    };

    console.log('✅ Configuration loaded:');
    console.log(`   Host:        ${dbConfig.host}`);
    console.log(`   Port:        ${dbConfig.port}`);
    console.log(`   User:        ${dbConfig.user}`);
    console.log(`   Database:    ${dbConfig.database}`);
    console.log(`   SSL Enabled: ${!!dbConfig.ssl ? 'Yes' : 'No'}`);
    console.log('');

    // Validate configuration
    if (!dbConfig.host) {
        console.error('❌ Error: Database host not configured');
        console.error('   Set DB_HOST or DATABASE_URL environment variable');
        process.exit(1);
    }

    if (!dbConfig.user) {
        console.error('❌ Error: Database user not configured');
        console.error('   Set DB_USER or DB_USERNAME environment variable');
        process.exit(1);
    }

    // Step 2: Test connection
    console.log('📋 Step 2: Testing Connection');
    console.log('-'.repeat(70));

    let pool;
    let connection;

    try {
        pool = mysql.createPool({
            ...dbConfig,
            connectionLimit: 1,
            waitForConnections: true,
            queueLimit: 0
        });

        connection = await pool.getConnection();
        console.log('✅ Successfully connected to MySQL database!\n');

    } catch (error) {
        console.error('❌ Failed to connect to database\n');
        console.error('Error Details:');
        console.error(`   Code:    ${error.code}`);
        console.error(`   Message: ${error.message}`);
        if (error.sqlState) console.error(`   SQL State: ${error.sqlState}`);
        console.error('');

        // Provide specific guidance based on error code
        switch (error.code) {
            case 'ER_ACCESS_DENIED_ERROR':
                console.error('🔧 Fix: Authentication failed');
                console.error('   - Verify DB_USER is correct');
                console.error('   - Verify DB_PASSWORD is correct');
                console.error('   - For Azure MySQL, use format: username@servername');
                break;
            case 'ENOTFOUND':
                console.error('🔧 Fix: Cannot resolve database hostname');
                console.error('   - Check DB_HOST is correct');
                console.error('   - Verify hostname spelling');
                console.error('   - Check network connectivity to host');
                break;
            case 'ECONNREFUSED':
                console.error('🔧 Fix: Connection refused by database server');
                console.error('   - Verify DB_PORT is correct (default: 3306)');
                console.error('   - Check if MySQL is running on that port');
                console.error('   - For Azure: verify firewall allows App Service IP');
                break;
            case 'ETIMEDOUT':
                console.error('🔧 Fix: Connection timeout');
                console.error('   - Database server is slow or unreachable');
                console.error('   - Check network firewall rules');
                console.error('   - For Azure: verify outbound rules allow port 3306');
                break;
            default:
                console.error('🔧 For more help:');
                console.error('   - Check .env file exists and has correct values');
                console.error('   - Verify environment variables in Azure App Service Settings');
        }

        console.error('');
        process.exit(1);
    }

    // Step 3: Check tables exist
    console.log('📋 Step 3: Checking Database Schema');
    console.log('-'.repeat(70));

    const requiredTables = ['users', 'employees', 'products', 'departments'];
    const existingTables = [];
    const missingTables = [];

    try {
        const [tables] = await connection.execute(
            `SELECT TABLE_NAME FROM information_schema.TABLES 
             WHERE TABLE_SCHEMA = DATABASE() 
             ORDER BY TABLE_NAME`
        );

        const tableNames = tables.map(t => t.TABLE_NAME);

        console.log(`✅ Found ${tableNames.length} tables in database:`);
        tableNames.forEach(table => {
            console.log(`   • ${table}`);
        });
        console.log('');

        // Check for required tables
        for (const table of requiredTables) {
            if (tableNames.includes(table)) {
                existingTables.push(table);
            } else {
                missingTables.push(table);
            }
        }

        if (missingTables.length > 0) {
            console.error('⚠️  Warning: Missing required tables:');
            missingTables.forEach(table => {
                console.error(`   • ${table}`);
            });
            console.error('');
            console.error('🔧 Fix: Run database setup script');
            console.error('   node scripts/setup-db.js');
            console.error('');
        } else {
            console.log('✅ All required tables exist!\n');
        }

    } catch (error) {
        console.error('❌ Error checking tables:', error.message);
        console.error('');
    }

    // Step 4: Check users table
    if (existingTables.includes('users')) {
        console.log('📋 Step 4: Checking Users Table');
        console.log('-'.repeat(70));

        try {
            const [columns] = await connection.execute(
                `SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE 
                 FROM information_schema.COLUMNS 
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
                 ORDER BY ORDINAL_POSITION`
            );

            console.log(`✅ Users table has ${columns.length} columns:`);
            columns.forEach(col => {
                const nullable = col.IS_NULLABLE === 'YES' ? '(nullable)' : '';
                console.log(`   • ${col.COLUMN_NAME} (${col.COLUMN_TYPE}) ${nullable}`);
            });
            console.log('');

            // Count users
            const [userCount] = await connection.execute(
                'SELECT COUNT(*) as count FROM users'
            );

            const count = userCount[0].count;
            console.log(`✅ Users in database: ${count}`);

            if (count === 0) {
                console.log('');
                console.error('⚠️  Warning: No users in database');
                console.error('🔧 Fix: Create an admin user');
                console.error('   node scripts/create-admin.js');
            } else {
                console.log('');
                // Show sample users (without passwords)
                const [users] = await connection.execute(
                    'SELECT user_id, username, full_name, role, is_active FROM users LIMIT 5'
                );

                console.log('📝 Sample users:');
                users.forEach(user => {
                    const active = user.is_active ? '✓' : '✗';
                    console.log(`   [${active}] ${user.username} (${user.role}) - ${user.full_name}`);
                });

                if (count > 5) {
                    console.log(`   ... and ${count - 5} more users`);
                }
                console.log('');
            }

        } catch (error) {
            console.error('❌ Error checking users table:', error.message);
            console.error('');
        }
    }

    // Step 5: Test login query
    console.log('📋 Step 5: Testing Login Query');
    console.log('-'.repeat(70));

    try {
        const testUsername = 'admin';
        const [result] = await connection.execute(
            `SELECT u.user_id, u.username, u.full_name, u.role, u.password 
             FROM users u 
             LEFT JOIN employees e ON u.user_id = e.user_id 
             WHERE u.username = ? AND u.is_active = 1 
             LIMIT 1`,
            [testUsername]
        );

        if (result.length === 0) {
            console.log(`ℹ️  No user found with username: '${testUsername}'`);
            console.log('');
            console.log('📝 To test login:');
            console.log('   1. Create a user: node scripts/create-admin.js');
            console.log('   2. Re-run this test');
        } else {
            const user = result[0];
            console.log(`✅ Found user: ${user.full_name} (${user.role})`);
            console.log(`   User ID: ${user.user_id}`);
            console.log(`   Username: ${user.username}`);
            console.log(`   Has password hash: ${user.password ? 'Yes ✓' : 'No ✗'}`);
            console.log('');
            console.log('🔐 Login query would succeed!');
        }
        console.log('');

    } catch (error) {
        console.error('❌ Error testing login query:', error.message);
        console.error('');
    }

    // Cleanup
    connection.release();
    await pool.end();

    // Summary
    console.log('='.repeat(70));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(70));

    const allChecks = [
        { name: 'Database Connection', passed: true },
        { name: 'Required Tables', passed: missingTables.length === 0 },
        { name: 'Users in Database', passed: existingTables.includes('users') }
    ];

    let passCount = 0;
    allChecks.forEach(check => {
        const icon = check.passed ? '✅' : '❌';
        console.log(`${icon} ${check.name}`);
        if (check.passed) passCount++;
    });

    console.log('');
    const percentage = Math.round((passCount / allChecks.length) * 100);
    console.log(`Status: ${percentage}% Ready`);
    console.log('');

    if (percentage === 100) {
        console.log('🎉 Database is ready! Your login should work.');
    } else {
        console.log('⚠️  Follow the fixes above before attempting login.');
    }

    console.log('');
    console.log('='.repeat(70) + '\n');
}

// Run the test
testConnection().catch(err => {
    console.error('Unexpected error:', err);
    process.exit(1);
});
