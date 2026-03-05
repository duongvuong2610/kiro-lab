# Use official Node.js LTS image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY app.js ./

# Expose port 80
EXPOSE 80

# Run the application
CMD ["npm", "start"]
