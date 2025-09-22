#!/bin/bash

# Nabha Digital Learning Platform Deployment Script
# This script handles deployment for rural school environments

set -e

echo "🚀 Starting deployment of Nabha Digital Learning Platform..."

# Configuration
BUILD_DIR="build"
DEPLOY_DIR="/var/www/nabha-learning"
BACKUP_DIR="/var/backups/nabha-learning"
SERVICE_NAME="nabha-learning"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 16 or higher."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
    print_error "Node.js version 16 or higher is required. Current version: $(node -v)"
    exit 1
fi

print_status "Prerequisites check passed ✓"

# Install dependencies
print_status "Installing dependencies..."
npm ci --production=false

# Run tests
print_status "Running tests..."
npm test -- --coverage --watchAll=false

# Build the application
print_status "Building application for production..."
npm run build

# Check if build was successful
if [ ! -d "$BUILD_DIR" ]; then
    print_error "Build failed. $BUILD_DIR directory not found."
    exit 1
fi

print_status "Build completed successfully ✓"

# Create backup of current deployment
if [ -d "$DEPLOY_DIR" ]; then
    print_status "Creating backup of current deployment..."
    BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -r "$DEPLOY_DIR" "$BACKUP_DIR/$BACKUP_NAME"
    print_status "Backup created: $BACKUP_DIR/$BACKUP_NAME"
fi

# Deploy to production directory
print_status "Deploying to production directory..."
sudo mkdir -p "$DEPLOY_DIR"
sudo cp -r "$BUILD_DIR"/* "$DEPLOY_DIR/"

# Set proper permissions
print_status "Setting file permissions..."
sudo chown -R www-data:www-data "$DEPLOY_DIR"
sudo chmod -R 755 "$DEPLOY_DIR"

# Configure nginx (if nginx is installed)
if command -v nginx &> /dev/null; then
    print_status "Configuring nginx..."
    
    # Create nginx configuration
    sudo tee /etc/nginx/sites-available/nabha-learning > /dev/null <<EOF
server {
    listen 80;
    server_name localhost;
    root $DEPLOY_DIR;
    index index.html;

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Handle client-side routing
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Service worker
    location /sw.js {
        add_header Cache-Control "no-cache";
        proxy_cache_bypass \$http_pragma;
        proxy_cache_revalidate on;
        expires off;
        access_log off;
    }
}
EOF

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/nabha-learning /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    sudo nginx -t
    
    # Reload nginx
    sudo systemctl reload nginx
    
    print_status "Nginx configured successfully ✓"
fi

# Configure systemd service (if systemd is available)
if command -v systemctl &> /dev/null; then
    print_status "Configuring systemd service..."
    
    sudo tee /etc/systemd/system/nabha-learning.service > /dev/null <<EOF
[Unit]
Description=Nabha Digital Learning Platform
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$DEPLOY_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable nabha-learning
    sudo systemctl start nabha-learning
    
    print_status "Systemd service configured ✓"
fi

# Set up SSL certificate (Let's Encrypt)
if command -v certbot &> /dev/null; then
    print_warning "SSL certificate setup available. Run 'sudo certbot --nginx' to enable HTTPS."
fi

# Create deployment info file
print_status "Creating deployment info..."
cat > "$DEPLOY_DIR/deployment-info.json" <<EOF
{
    "deploymentDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')",
    "buildNumber": "$(date +%Y%m%d%H%M%S)",
    "environment": "production",
    "nodeVersion": "$(node -v)",
    "npmVersion": "$(npm -v)"
}
EOF

# Health check
print_status "Performing health check..."
if curl -f http://localhost > /dev/null 2>&1; then
    print_status "Health check passed ✓"
else
    print_warning "Health check failed. Please check the application manually."
fi

# Cleanup
print_status "Cleaning up build artifacts..."
rm -rf "$BUILD_DIR"

# Final status
print_status "🎉 Deployment completed successfully!"
print_status "Application is available at: http://localhost"
print_status "Deployment directory: $DEPLOY_DIR"
print_status "Backup directory: $BACKUP_DIR"

# Display useful commands
echo ""
echo "Useful commands:"
echo "  View logs: sudo journalctl -u nabha-learning -f"
echo "  Restart service: sudo systemctl restart nabha-learning"
echo "  Check status: sudo systemctl status nabha-learning"
echo "  View nginx logs: sudo tail -f /var/log/nginx/error.log"

echo ""
print_status "Deployment script completed! 🚀"
