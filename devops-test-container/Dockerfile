#------------------------
# Stage 1: Build the app

FROM node:18-alpine AS builder

# Create app directory
WORKDIR /app

# Copy app files
COPY package*.json ./
COPY server.js ./

# Install only production deps
RUN npm install --production

#--------------------------
# Stage 2: Production image

FROM node:18-alpine

WORKDIR /app

# Copy only necessary files from builder stage
COPY --from=builder /app /app

# Expose the port
EXPOSE 80

# Start server
CMD ["node", "server.js"]

