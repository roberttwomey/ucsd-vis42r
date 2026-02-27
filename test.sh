#!/bin/bash

# test.sh - Build and serve Jekyll website locally for testing
# Usage: ./test.sh

set -e  # Exit on error

# Check if bundle is installed
if ! command -v bundle &> /dev/null; then
    echo "Error: Bundler is not installed."
    echo ""
    echo "Please install Bundler:"
    echo "  gem install bundler"
    exit 1
fi

# Check if Gemfile exists
if [ ! -f "Gemfile" ]; then
    echo "Error: Gemfile not found."
    echo "Please create a Gemfile with Jekyll dependencies."
    exit 1
fi

# Check if dependencies are installed, install if not
if ! bundle check &> /dev/null; then
    echo "Installing Jekyll dependencies..."
    bundle install
fi

echo "Building Jekyll site..."
bundle exec jekyll build

echo ""
echo "Starting Jekyll server..."
echo "Site will be available at http://localhost:4000"
echo "Press Ctrl+C to stop the server"
echo ""

bundle exec jekyll serve --host 0.0.0.0

