#!/bin/bash

# deploy.sh - Build Jekyll site and deploy to remote server
# Usage: ./deploy.sh [remote_user@remote_host:remote_path]
# Example: ./deploy.sh user@vis42.roberttwomey.com:/var/www/html
# Or set DEPLOY_TARGET environment variable

set -e  # Exit on error

# Get deployment target from argument or environment variable
DEPLOY_TARGET="${1:-${DEPLOY_TARGET}}"

if [ -z "$DEPLOY_TARGET" ]; then
    echo "Error: Deployment target not specified."
    echo ""
    echo "Usage: ./deploy.sh [user@host:path]"
    echo "   or: DEPLOY_TARGET=user@host:path ./deploy.sh"
    echo ""
    echo "Example: ./deploy.sh user@vis42.roberttwomey.com:/var/www/html"
    exit 1
fi

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

# Extract hostname and path from DEPLOY_TARGET
HOSTNAME=$(echo "$DEPLOY_TARGET" | cut -d: -f1 | cut -d@ -f2)
DEPLOY_PATH=$(echo "$DEPLOY_TARGET" | cut -d: -f2)

# Extract the web-accessible path (last directory in deploy path)
# e.g., /home/user/site/web/ -> /web
BASEURL=$(echo "$DEPLOY_PATH" | sed 's|/$||' | awk -F'/' '{print "/"$NF}')

# If baseurl is empty or just "/", set it to empty string
if [ "$BASEURL" = "/" ] || [ -z "$BASEURL" ]; then
    BASEURL=""
fi

SITE_URL="https://${HOSTNAME}${BASEURL}"

echo "Building Jekyll site for production..."
echo "Site URL: $SITE_URL"
echo "Base URL: ${BASEURL:-/}"

# Create a temporary config file with production URL and baseurl
# Jekyll requires URL to be set in config file, not as a command-line option
# macOS mktemp doesn't support --suffix, so create temp file and add extension
TMP_CONFIG=$(mktemp)
TMP_CONFIG_YML="${TMP_CONFIG}.yml"
mv "$TMP_CONFIG" "$TMP_CONFIG_YML"
TMP_CONFIG="$TMP_CONFIG_YML"
trap "rm -f '$TMP_CONFIG'" EXIT INT TERM

# Copy base config and append URL/baseurl settings
# Use a repository format that won't be interpreted as GitHub Pages
cat _config.yml > "$TMP_CONFIG"
echo "" >> "$TMP_CONFIG"
echo "url: $SITE_URL" >> "$TMP_CONFIG"
if [ -n "$BASEURL" ]; then
    echo "baseurl: $BASEURL" >> "$TMP_CONFIG"
fi
# Use a format that won't trigger GitHub Pages baseurl logic
echo "github:" >> "$TMP_CONFIG"
echo "  repository_url: https://github.com/dummy/dummy" >> "$TMP_CONFIG"

# Build with production environment using the config file
# Use both configs so base settings are preserved
JEKYLL_ENV=production bundle exec jekyll build --config "_config.yml,$TMP_CONFIG"

if [ ! -d "_site" ]; then
    echo "Error: Build directory '_site' not found. Build may have failed."
    exit 1
fi

# Verify that theme assets are present and contain actual styles
if [ ! -d "_site/assets" ] || [ ! -f "_site/assets/css/style.css" ]; then
    echo "Error: Theme assets not found in _site directory."
    echo "Expected: _site/assets/css/style.css"
    echo "This indicates a build issue with the Jekyll theme."
    exit 1
fi

# Verify the CSS file has content (theme Sass files are compiled into this)
CSS_SIZE=$(wc -c < "_site/assets/css/style.css" | tr -d ' ')
if [ "$CSS_SIZE" -lt 1000 ]; then
    echo "Warning: CSS file seems too small ($CSS_SIZE bytes). Theme may not have compiled correctly."
fi

echo "✓ Build complete. Assets verified (CSS: ${CSS_SIZE} bytes)."
echo "  Note: Theme Sass files are automatically compiled into CSS during build."
echo "  No need to copy Sass files - they're processed from the gem."

echo ""
echo "Deploying to $DEPLOY_TARGET..."
echo ""

# Try rsync first, fallback to scp if rsync is not available
if command -v rsync &> /dev/null; then
    echo "Using rsync..."
    echo "Copying files (this may take a moment)..."
    rsync -avz --delete \
        --exclude='.DS_Store' \
        --exclude='.git' \
        --exclude='.gitignore' \
        --exclude='*.sh' \
        --exclude='README.md' \
        --exclude='*.map' \
        --perms --executability \
        _site/ "$DEPLOY_TARGET/"
    echo ""
    echo "Deployment complete!"
    echo "Site should be live at: $SITE_URL"
    if [ -n "$BASEURL" ]; then
        echo "Note: Site is deployed to subdirectory $BASEURL"
    fi
elif command -v scp &> /dev/null; then
    echo "rsync not found, using scp (fallback)..."
    echo "Note: scp will copy files but won't delete remote files that don't exist locally."
    scp -r _site/* "$DEPLOY_TARGET/"
    echo ""
    echo "Deployment complete!"
    echo "Site should be live at: $SITE_URL"
    if [ -n "$BASEURL" ]; then
        echo "Note: Site is deployed to subdirectory $BASEURL"
    fi
else
    echo "Error: Neither rsync nor scp is available."
    echo "Please install rsync or scp to deploy."
    exit 1
fi

