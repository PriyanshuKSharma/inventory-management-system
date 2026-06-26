/**
 * IMPROVED LOGIN ERROR HANDLER
 * 
 * Replace the login error handling in your server.js with this enhanced version
 * This provides much better error diagnostics for debugging
 * 
 * Location: server.js lines 410-505 (the app.post('/login') handler)
 * 
 * Benefits:
 * ✅ Detailed error logging to console
 * ✅ Identifies specific failure points
 * ✅ Helps diagnose database vs auth issues
 * ✅ Better user feedback messages
 */

// =============================================================================
// IMPROVED LOGIN HANDLER WITH DETAILED ERROR LOGGING
// =============================================================================

app.post('/login', async (req, res) => {
    const { username, password } = req.body;
    
    try {
        // Validate input
        if (!username || !password) {
            console.warn(`⚠️  Login attempt with missing credentials (user: ${username || 'empty'})`);
            req.flash('error', 'Username and password are required');
            return res.redirect('/login');
        }

        console.log(`🔐 Login attempt for user: ${username}`);
        
        // ==================== DATABASE QUERY ====================
        // This is the most likely point of failure - database connection issues
        let users;
        let querySuccess = false;
        
        try {
            console.log('📡 Querying database for user...');
            const [result] = await pool.execute(
                'SELECT u.*, e.department_id FROM users u LEFT JOIN employees e ON u.user_id = e.user_id WHERE u.username = ? AND u.is_active = 1 LIMIT 1',
                [username]
            );
            users = result;
            querySuccess = true;
            console.log(`✅ Database query successful. Found users: ${users.length}`);
        } catch (dbError) {
            // DATABASE CONNECTION ERROR
            console.error('❌ DATABASE QUERY FAILED!');
            console.error('   Error Code:', dbError.code);
            console.error('   Error Message:', dbError.message);
            console.error('   SQL State:', dbError.sqlState);
            console.error('   Errno:', dbError.errno);
            
            // Provide detailed error info
            if (dbError.code === 'ER_ACCESS_DENIED_ERROR') {
                console.error('\n🔧 FIX: Authentication error - Database credentials incorrect');
                console.error('   Check: DB_USER, DB_PASSWORD in environment variables');
            } else if (dbError.code === 'ER_BAD_DB_ERROR') {
                console.error('\n🔧 FIX: Database does not exist');
                console.error('   Check: DB_NAME in environment variables');
                console.error('   Run: node scripts/setup-db.js');
            } else if (dbError.code === 'ER_NO_SUCH_TABLE') {
                console.error('\n🔧 FIX: Users table does not exist');
                console.error('   Run: node scripts/setup-db.js');
            } else if (dbError.code === 'ENOTFOUND' || dbError.code === 'GETADDRINFO_NOTFOUND') {
                console.error('\n🔧 FIX: Cannot reach database server');
                console.error('   Check: DB_HOST is correct');
                console.error('   Check: Network can reach the hostname');
            } else if (dbError.code === 'ECONNREFUSED') {
                console.error('\n🔧 FIX: Connection refused');
                console.error('   Check: DB_PORT is correct (default: 3306)');
                console.error('   Check: MySQL service is running');
                console.error('   Check: Azure firewall allows the connection');
            } else if (dbError.code === 'ETIMEDOUT' || dbError.code === 'EHOSTUNREACH') {
                console.error('\n🔧 FIX: Connection timeout - cannot reach database');
                console.error('   Check: Network connectivity');
                console.error('   Check: Firewall rules');
                console.error('   Check: Database server is running');
            } else if (dbError.code === 'PROTOCOL_CONNECTION_LOST') {
                console.error('\n🔧 FIX: Connection lost during query');
                console.error('   Database may have crashed or connection was reset');
                console.error('   Try: Restarting the database service');
            } else {
                console.error('\n🔧 FIX: Unknown database error');
                console.error('   Review error details above');
            }
            
            // Don't leak database error details to user
            req.flash('error', 'An error occurred during login. Please try again.');
            return res.redirect('/login');
        }
        
        // ==================== USER VALIDATION ====================
        if (!querySuccess || users.length === 0) {
            console.warn(`❌ No user found with username: ${username}`);
            req.flash('error', 'Invalid username or password');
            return res.redirect('/login');
        }
        
        const user = users[0];
        console.log(`✅ User found: ${user.full_name} (Role: ${user.role})`);

        // ==================== USERNAME VERIFICATION ====================
        if (user.username !== username) {
            console.warn(`⚠️  Username case mismatch for: ${username}`);
            req.flash('error', 'Invalid username or password');
            return res.redirect('/login');
        }

        // ==================== PASSWORD VERIFICATION ====================
        console.log('🔐 Verifying password with bcrypt...');
        
        let isValid = false;
        try {
            isValid = await bcrypt.compare(password, user.password);
            if (isValid) {
                console.log('✅ Password is valid!');
            } else {
                console.warn(`❌ Password mismatch for user: ${username}`);
            }
        } catch (bcryptError) {
            console.error('❌ Password verification error!');
            console.error('   Error:', bcryptError.message);
            console.error('   This might indicate a corrupted password hash');
            console.error('   User may need password reset');
            isValid = false;
        }
        
        if (!isValid) {
            req.flash('error', 'Invalid username or password');
            return res.redirect('/login');
        }

        // ==================== SESSION CREATION ====================
        console.log('📝 Creating user session...');
        
        req.session.user = {
            user_id: user.user_id,
            username: user.username,
            full_name: user.full_name,
            role: user.role,
            email: user.email,
            is_super_admin: user.is_super_admin || false,
            department_id: user.department_id
        };
        
        console.log(`✅ Session object created for user: ${user.username}`);
        console.log(`   Session ID: ${req.sessionID}`);

        // ==================== SESSION PERSISTENCE ====================
        req.session.save((saveError) => {
            if (saveError) {
                console.error('❌ SESSION SAVE FAILED!');
                console.error('   Error:', saveError.message);
                console.error('   This might be a session store issue');
                
                if (saveError.code === 'PROTOCOL_SEQUENCE_TIMEOUT') {
                    console.error('   Check: Database session store connectivity');
                } else if (saveError.code === 'ER_ACCESS_DENIED_ERROR') {
                    console.error('   Check: Session database user permissions');
                } else {
                    console.error('   Check: express-session configuration');
                }
                
                req.flash('error', 'Login failed. Please try again.');
                return res.redirect('/login');
            }

            console.log('✅ Session saved successfully');

            // ==================== ACTIVITY LOGGING ====================
            // Log login activity for audit trail (if available)
            if (ActivityLogger && ActivityLogger.logLogin) {
                try {
                    console.log('📊 Logging login activity...');
                    ActivityLogger.logLogin(user.user_id, {
                        username: user.username,
                        full_name: user.full_name,
                        ip: req.ip || req.connection.remoteAddress,
                        userAgent: req.get('User-Agent')
                    });
                    console.log('✅ Activity logged');
                } catch (logError) {
                    console.warn('⚠️  Failed to log activity (non-critical):', logError.message);
                    // Don't fail the login if activity logging fails
                }
            }

            // ==================== REDIRECT TO DASHBOARD ====================
            console.log(`✅ Login successful! Redirecting ${user.role}...`);
            
            if (user.role === 'admin') {
                console.log('   → /admin/dashboard');
                return res.redirect('/admin/dashboard');
            } else if (user.role === 'monitor') {
                console.log('   → /monitor/dashboard');
                return res.redirect('/monitor/dashboard');
            } else if (user.role === 'employee') {
                console.log('   → /employee/dashboard');
                return res.redirect('/employee/dashboard');
            }

            console.log('   → /dashboard (default)');
            return res.redirect('/dashboard');
        });

    } catch (error) {
        // UNEXPECTED ERROR - CATCH ALL
        console.error('🔴 UNEXPECTED ERROR IN LOGIN HANDLER!');
        console.error('   Error Type:', error.constructor.name);
        console.error('   Error Message:', error.message);
        console.error('   Stack Trace:');
        console.error(error.stack);
        
        // Try to identify the issue
        if (error.message.includes('pool') || error.message.includes('connection')) {
            console.error('\n🔧 Likely cause: Database connection pool issue');
            console.error('   Check: Database is running and accessible');
            console.error('   Check: Connection string is correct');
        } else if (error.message.includes('bcrypt')) {
            console.error('\n🔧 Likely cause: Password hashing issue');
            console.error('   Check: bcryptjs package is installed');
            console.error('   Check: Password hash in database is valid');
        } else if (error.message.includes('session')) {
            console.error('\n🔧 Likely cause: Session management issue');
            console.error('   Check: express-session configuration');
            console.error('   Check: Session store connectivity');
        }
        
        // Don't leak error details to user
        req.flash('error', 'An error occurred during login. Please try again.');
        return res.redirect('/login');
    }
});

// =============================================================================
// ENHANCED ERROR LOGGING MIDDLEWARE
// =============================================================================

// Add this after your login handler to catch any unhandled errors
app.use((err, req, res, next) => {
    console.error('='.repeat(70));
    console.error('❌ UNHANDLED ERROR IN EXPRESS APP');
    console.error('='.repeat(70));
    console.error('URL:', req.method, req.originalUrl);
    console.error('Error:', err.message);
    console.error('Stack:', err.stack);
    console.error('='.repeat(70));
    
    if (res.headersSent) {
        return next(err);
    }
    
    res.status(500).render('error', { 
        message: 'An unexpected error occurred' 
    });
});

// =============================================================================
// INSTALLATION INSTRUCTIONS
// =============================================================================

/*
HOW TO USE THIS IMPROVED ERROR HANDLER:

1. Open your server.js file
2. Find the app.post('/login', async (req, res) => { section (around line 410)
3. Replace the entire handler with the code above
4. Also add the error handling middleware at the end (before the export)
5. Save the file

6. Restart your server:
   npm start

7. Try logging in again
8. Check the console output for detailed error messages

WHAT YOU'LL SEE:

Success (no database errors):
   🔐 Login attempt for user: admin
   📡 Querying database for user...
   ✅ Database query successful. Found users: 1
   ✅ User found: Admin User (Role: admin)
   🔐 Verifying password with bcrypt...
   ✅ Password is valid!
   📝 Creating user session...
   ✅ Session object created for user: admin
   ✅ Session saved successfully
   ✅ Login successful! Redirecting admin...
      → /admin/dashboard

Database Error (most common):
   ❌ DATABASE QUERY FAILED!
   Error Code: ENOTFOUND
   Error Message: getaddrinfo ENOTFOUND [hostname]
   
   🔧 FIX: Cannot reach database server
      Check: DB_HOST is correct
      Check: Network can reach the hostname

Wrong Credentials:
   ❌ No user found with username: testuser
   (or)
   ❌ Password mismatch for user: testuser

This helps you pinpoint exactly where the login fails.
*/
