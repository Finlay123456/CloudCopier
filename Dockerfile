FROM node:18-alpine

WORKDIR /app

# Copy server package files
COPY server/package*.json ./server/

# Install dependencies
RUN cd server && npm install --only=production

# Copy server source code
COPY server/ ./server/

# Expose port
EXPOSE 3000

# Change to server directory and start
WORKDIR /app/server
CMD ["node", "server.js"]