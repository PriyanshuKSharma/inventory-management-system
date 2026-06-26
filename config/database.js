const mysql = require('mysql2/promise');

const requireDatabaseEnv = (value, name) => {
    if (value === undefined || value === null || value === '') {
        throw new Error(`Missing required database environment variable: ${name}`);
    }

    return value;
};

// Database configuration - different for production vs development
const dbConfig = process.env.NODE_ENV === 'production' ? {
    // Production: Check if using socket path (Cloud SQL) or TCP (Windows)
    ...(process.env.DB_HOST && process.env.DB_HOST.startsWith('/') ? 
        { socketPath: process.env.DB_HOST } : 
        { 
            host: process.env.DB_HOST || 'localhost',
            port: process.env.DB_PORT || 3306
        }
    ),
    user: process.env.DB_USER || process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || process.env.DB_DATABASE,
    connectionLimit: 5,
    waitForConnections: true,
    queueLimit: 0,
    ssl: { rejectUnauthorized: false }
} : {
    // Development: Use standard TCP connection
    host: requireDatabaseEnv(process.env.DB_HOST || process.env.DB_HOSTNAME, 'DB_HOST'),
    user: requireDatabaseEnv(process.env.DB_USER || process.env.DB_USERNAME, 'DB_USER or DB_USERNAME'),
    password: requireDatabaseEnv(process.env.DB_PASSWORD, 'DB_PASSWORD'),
    database: requireDatabaseEnv(process.env.DB_NAME || process.env.DB_DATABASE, 'DB_NAME or DB_DATABASE'),
    port: process.env.DB_PORT ? Number(process.env.DB_PORT) : undefined,
    connectionLimit: 5,
    waitForConnections: true,
    queueLimit: 0,
    ssl: (process.env.DB_HOST || process.env.DB_HOSTNAME) ? { rejectUnauthorized: false } : undefined
};

const pool = mysql.createPool(dbConfig);

module.exports = pool;