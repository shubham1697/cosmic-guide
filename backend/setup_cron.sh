#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Setup cron job for daily content population on the database machine.
#
# Usage:
#   chmod +x setup_cron.sh
#   ./setup_cron.sh
#
# This will add a crontab entry that runs populate_daily.py at 00:05 daily.
# Run this on the machine where you want the database + LLM calls to happen.
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="$(which python3)"
LOG_FILE="$SCRIPT_DIR/logs/populate_daily.log"

# Create log directory
mkdir -p "$SCRIPT_DIR/logs"

# Build the cron command
CRON_CMD="5 0 * * * cd $SCRIPT_DIR && $PYTHON populate_daily.py >> $LOG_FILE 2>&1"

echo "Setting up daily content population cron job..."
echo ""
echo "Script directory: $SCRIPT_DIR"
echo "Python:           $PYTHON"
echo "Log file:         $LOG_FILE"
echo "Cron schedule:    00:05 daily"
echo ""
echo "Cron command:"
echo "  $CRON_CMD"
echo ""

# Check if already installed
if crontab -l 2>/dev/null | grep -q "populate_daily.py"; then
    echo "⚠️  A cron entry for populate_daily.py already exists:"
    crontab -l | grep "populate_daily.py"
    echo ""
    read -p "Replace it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old entry and add new
        (crontab -l 2>/dev/null | grep -v "populate_daily.py"; echo "$CRON_CMD") | crontab -
        echo "✅ Cron job updated."
    else
        echo "Skipped."
        exit 0
    fi
else
    # Add new entry
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "✅ Cron job installed."
fi

echo ""
echo "Current crontab:"
crontab -l
echo ""
echo "To test immediately: cd $SCRIPT_DIR && $PYTHON populate_daily.py --dry-run"
echo "To remove: crontab -l | grep -v populate_daily.py | crontab -"
