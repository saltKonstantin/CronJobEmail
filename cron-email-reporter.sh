#!/bin/bash

# Cron Job Email Reporter
# This script collects cron job logs and system information, then sends a daily email report

# Configuration
EMAIL_TO="${CRON_EMAIL_TO:-admin@yourdomain.com}"
EMAIL_FROM="${CRON_EMAIL_FROM:-cronreports@$(hostname)}"
EMAIL_SUBJECT="Daily Cron Job Report - $(hostname) - $(date +%Y-%m-%d)"
TEMP_FILE="/tmp/cron-report-$(date +%Y%m%d).txt"
LOG_DAYS="${CRON_LOG_DAYS:-1}"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEMP_FILE"
}

# Function to add section header
add_section() {
    echo "" >> "$TEMP_FILE"
    echo "============================================" >> "$TEMP_FILE"
    echo "$1" >> "$TEMP_FILE"
    echo "============================================" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
}

# Check if mail command is available
check_mail_setup() {
    if ! command -v mail >/dev/null 2>&1 && ! command -v msmtp >/dev/null 2>&1; then
        echo "Error: No mail command found. Please install mailutils or msmtp."
        exit 1
    fi
}

# Main report generation
generate_report() {
    # Initialize report file
    echo "Daily Cron Job Report for $(hostname)" > "$TEMP_FILE"
    echo "Generated on: $(date)" >> "$TEMP_FILE"
    echo "Report Period: Last $LOG_DAYS day(s)" >> "$TEMP_FILE"

    # System Information
    add_section "SYSTEM INFORMATION"
    echo "Hostname: $(hostname)" >> "$TEMP_FILE"
    echo "Uptime: $(uptime)" >> "$TEMP_FILE"
    echo "Load Average: $(cat /proc/loadavg)" >> "$TEMP_FILE"
    echo "Disk Usage:" >> "$TEMP_FILE"
    df -h | head -10 >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    echo "Memory Usage:" >> "$TEMP_FILE"
    free -h >> "$TEMP_FILE"

    # Active Cron Jobs
    add_section "ACTIVE CRON JOBS"
    echo "Root crontab:" >> "$TEMP_FILE"
    if crontab -l 2>/dev/null; then
        crontab -l >> "$TEMP_FILE"
    else
        echo "No root crontab found or access denied" >> "$TEMP_FILE"
    fi
    
    echo "" >> "$TEMP_FILE"
    echo "System-wide cron jobs (/etc/crontab):" >> "$TEMP_FILE"
    if [ -f /etc/crontab ]; then
        cat /etc/crontab >> "$TEMP_FILE"
    else
        echo "No /etc/crontab found" >> "$TEMP_FILE"
    fi

    echo "" >> "$TEMP_FILE"
    echo "Cron jobs in /etc/cron.d/:" >> "$TEMP_FILE"
    if [ -d /etc/cron.d ]; then
        for file in /etc/cron.d/*; do
            if [ -f "$file" ]; then
                echo "--- $file ---" >> "$TEMP_FILE"
                cat "$file" >> "$TEMP_FILE"
                echo "" >> "$TEMP_FILE"
            fi
        done
    else
        echo "No /etc/cron.d directory found" >> "$TEMP_FILE"
    fi

    # Cron Logs Analysis
    add_section "CRON LOGS (Last $LOG_DAYS day(s))"
    
    # Check common log locations
    CRON_LOG=""
    for log_path in "/var/log/cron" "/var/log/cron.log" "/var/log/syslog"; do
        if [ -f "$log_path" ]; then
            CRON_LOG="$log_path"
            break
        fi
    done

    if [ -n "$CRON_LOG" ]; then
        echo "Analyzing logs from: $CRON_LOG" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        
        # Get logs from the last N days
        if command -v journalctl >/dev/null 2>&1; then
            echo "Recent cron activity (from systemd journal):" >> "$TEMP_FILE"
            journalctl -u cron --since "$LOG_DAYS days ago" --no-pager >> "$TEMP_FILE" 2>/dev/null || echo "Could not access systemd journal" >> "$TEMP_FILE"
        else
            echo "Recent cron activity:" >> "$TEMP_FILE"
            # Use awk to filter logs from the last N days
            awk -v days="$LOG_DAYS" '
            BEGIN {
                # Get current date
                "date +%s" | getline current_time
                cutoff_time = current_time - (days * 24 * 60 * 60)
            }
            /CRON/ {
                # Try to parse date from log line
                cmd = "date -d \"" $1 " " $2 " " $3 "\" +%s 2>/dev/null"
                if ((cmd | getline timestamp) > 0 && timestamp >= cutoff_time) {
                    print $0
                }
                close(cmd)
            }' "$CRON_LOG" >> "$TEMP_FILE" 2>/dev/null || echo "Could not parse cron logs" >> "$TEMP_FILE"
        fi
    else
        echo "No cron log file found in standard locations" >> "$TEMP_FILE"
        echo "Checked: /var/log/cron, /var/log/cron.log, /var/log/syslog" >> "$TEMP_FILE"
    fi

    # Failed Jobs Summary
    add_section "FAILED JOBS SUMMARY"
    if [ -n "$CRON_LOG" ]; then
        echo "Jobs that may have failed (contains 'error', 'failed', 'denied'):" >> "$TEMP_FILE"
        grep -i -E "(error|failed|denied)" "$CRON_LOG" 2>/dev/null | tail -20 >> "$TEMP_FILE" || echo "No obvious failures detected" >> "$TEMP_FILE"
    else
        echo "Cannot analyze failures - no log file available" >> "$TEMP_FILE"
    fi

    # User-specific logs (if available)
    add_section "USER CRON JOBS"
    echo "Checking for user-specific cron jobs:" >> "$TEMP_FILE"
    for user in $(cut -f1 -d: /etc/passwd); do
        if crontab -l -u "$user" 2>/dev/null | grep -v "^#" | grep -v "^$" >/dev/null; then
            echo "User $user has cron jobs:" >> "$TEMP_FILE"
            crontab -l -u "$user" 2>/dev/null >> "$TEMP_FILE"
            echo "" >> "$TEMP_FILE"
        fi
    done

    # Recent system events that might affect cron
    add_section "RECENT SYSTEM EVENTS"
    echo "Recent system boots:" >> "$TEMP_FILE"
    if command -v last >/dev/null 2>&1; then
        last reboot | head -5 >> "$TEMP_FILE"
    else
        echo "last command not available" >> "$TEMP_FILE"
    fi
    
    echo "" >> "$TEMP_FILE"
    echo "Services status:" >> "$TEMP_FILE"
    systemctl is-active cron >> "$TEMP_FILE" 2>/dev/null || echo "cron service status unknown" >> "$TEMP_FILE"
    
    # Add footer
    echo "" >> "$TEMP_FILE"
    echo "============================================" >> "$TEMP_FILE"
    echo "Report generated by cron-email-reporter.sh" >> "$TEMP_FILE"
    echo "Server: $(hostname)" >> "$TEMP_FILE"
    echo "Time: $(date)" >> "$TEMP_FILE"
    echo "============================================" >> "$TEMP_FILE"
}

# Send email function
send_email() {
    if command -v mail >/dev/null 2>&1; then
        # Using mail command (mailutils)
        mail -s "$EMAIL_SUBJECT" "$EMAIL_TO" < "$TEMP_FILE"
    elif command -v msmtp >/dev/null 2>&1; then
        # Using msmtp
        {
            echo "To: $EMAIL_TO"
            echo "From: $EMAIL_FROM"
            echo "Subject: $EMAIL_SUBJECT"
            echo ""
            cat "$TEMP_FILE"
        } | msmtp "$EMAIL_TO"
    else
        echo "Error: No mail command available"
        exit 1
    fi
}

# Main execution
main() {
    log_message "Starting cron job report generation"
    
    check_mail_setup
    generate_report
    
    log_message "Report generated, sending email to $EMAIL_TO"
    send_email
    
    log_message "Email sent successfully"
    
    # Clean up temporary file
    rm -f "$TEMP_FILE"
    
    log_message "Cron job report completed"
}

# Run main function
main "$@" 