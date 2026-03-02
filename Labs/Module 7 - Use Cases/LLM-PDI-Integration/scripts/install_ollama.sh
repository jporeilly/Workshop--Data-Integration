#!/bin/bash
# Ollama Setup Script for Ubuntu 24.04
# This script installs Ollama and pulls the required models for the workshop

set -e

echo "=========================================="
echo "Ollama Installation for PDI Workshop"
echo "=========================================="
echo ""

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "Warning: This script is designed for Ubuntu 24.04"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install Ollama
echo "Step 1: Installing Ollama..."
if command -v ollama &> /dev/null; then
    echo "Ollama is already installed."
    ollama --version
else
    curl -fsSL https://ollama.com/install.sh | sh
    echo "Ollama installed successfully!"
fi

echo ""
echo "Step 2: Starting Ollama service..."
# Start Ollama service (it runs as a background service)
sudo systemctl start ollama 2>/dev/null || echo "Service already running or manual start required"
sleep 3

echo ""
echo "Step 3: Pulling recommended models for sentiment analysis..."
echo "This may take several minutes depending on your internet connection..."

# Pull llama3.2 (3B parameters - good balance of speed and accuracy)
echo ""
echo "Pulling llama3.2:3b (Recommended for workshop - fast and efficient)..."
ollama pull llama3.2:3b

# Optional: Pull other models
read -p "Would you like to pull additional models? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Pulling llama3.2:1b (Fastest, good for demos)..."
    ollama pull llama3.2:1b

    echo ""
    echo "Pulling llama2:7b (Alternative option)..."
    ollama pull llama2:7b
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Ollama is now running on: http://localhost:11434"
echo ""
echo "Test the installation with:"
echo "  curl http://localhost:11434/api/tags"
echo ""
echo "Available models:"
ollama list

echo ""
echo "Quick test:"
echo '  ollama run llama3.2:3b "Analyze this review sentiment: Great product, very happy!"'
echo ""
