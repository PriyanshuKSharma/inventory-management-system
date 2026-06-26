# Use official Node.js LTS image
FROM node:20-alpine

# Install nano editor
RUN apk add --no-cache nano

# Set working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the app
COPY . .

# Expose the port (default 3000, can be overridden by env)
EXPOSE 3000

# Set environment variables (can be overridden at runtime)
ENV NODE_ENV=development

# Install wait-for-it script to wait for MySQL and nano editor
RUN apk add --no-cache bash curl nano
RUN curl -o /usr/local/bin/wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
RUN chmod +x /usr/local/bin/wait-for-it.sh

# Start the server
CMD ["/usr/local/bin/wait-for-it.sh", "mysql:3306", "--timeout=60", "--", "sh", "-c", "npm run create-admin && node server.js"]