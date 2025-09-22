#!/bin/bash

echo "Starting Nabha Digital Learning Platform..."
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed!"
    echo "Please install Node.js from https://nodejs.org/"
    echo
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm is not installed!"
    echo "Please install Node.js which includes npm"
    echo
    exit 1
fi

echo "Node.js version:"
node --version
echo
echo "npm version:"
npm --version
echo

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install dependencies!"
        exit 1
    fi
    echo "Dependencies installed successfully!"
    echo
fi

# Start the development server
echo "Starting development server..."
echo "The application will open in your browser at http://localhost:3000"
echo
echo "Press Ctrl+C to stop the server"
echo
npm start
