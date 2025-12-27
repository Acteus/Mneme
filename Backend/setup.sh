#!/bin/bash
# Mneme Backend Setup Script
# Run this to set up the Python environment

set -e

echo "🧠 Mneme Backend Setup"
echo "====================="

cd "$(dirname "$0")"

# Check Python version
echo "Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    echo "Found Python $PYTHON_VERSION"
else
    echo "❌ Python 3 not found. Please install Python 3.9+"
    exit 1
fi

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

echo ""
echo "✅ Setup complete!"
echo ""
echo "To test the backend:"
echo "  source venv/bin/activate"
echo "  python bridge.py"
echo ""
echo "Then type: {\"action\": \"ping\"}"

