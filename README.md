# Cron Job Email Reporter

A comprehensive solution for monitoring cron jobs on Xubuntu/CasaOS servers and receiving daily email reports about their status, logs, and system health.

## Features

- 📊 **Comprehensive Reporting**: Daily reports including cron job status, logs, and system information
- 📧 **Email Notifications**: Automatic email delivery with detailed reports
- 🔍 **Log Analysis**: Analyzes cron logs for failures and errors
- 🖥️ **System Health**: Includes system uptime, disk usage, and memory statistics
- ⚙️ **Easy Setup**: Automated installation and configuration
- 🔧 **Flexible Configuration**: Support for multiple email providers and custom settings

## Quick Start

1. **Clone or download the files**:
   ```bash
   git clone <repository-url>
   cd CronJobEmail
   ```

2. **Run the installation script**:
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

3. **Configure your email settings**:
   ```bash
   sudo nano /etc/cron-email-reporter.conf
   ```

4. **Test the setup**:
   ```bash
   sudo /usr/local/bin/cron-email-reporter.sh
   ```

## What's Included

### Files

- `cron-email-reporter.sh` - Main reporting script
- `install.sh` - Automated installation script
- `msmtp-config-example.conf` - Example configuration for external email services
- `README.md` - This documentation

### Generated Files (after installation)

- `/usr/local/bin/cron-email-reporter.sh` - Installed reporter script
- `/etc/cron-email-reporter.conf` - Configuration file
- `/etc/cron.d/cron-email-reporter` - Daily cron job
- `/var/log/cron-email-reporter.log` - Script execution logs
- `/etc/logrotate.d/cron-email-reporter` - Log rotation configuration

## Installation Options

### Option 1: Local Mail Delivery (Recommended for beginners)

The installation script sets up Postfix for local mail delivery. This works well if:
- You want to receive emails locally on the server
- You plan to forward emails using mail aliases
- You're setting up a simple monitoring system

```bash
sudo ./install.sh
```

### Option 2: External Email Service (Gmail, Outlook, etc.)

For sending emails to external addresses, you'll need to configure `msmtp`:

1. **Install msmtp**:
   ```bash
   sudo apt install msmtp msmtp-mta
   ```

2. **Configure msmtp** using the example configuration:
   ```bash
   sudo cp msmtp-config-example.conf /etc/msmtprc
   sudo chmod 600 /etc/msmtprc
   sudo nano /etc/msmtprc
   ```

3. **Update the reporter script** to use msmtp (already supported)

4. **Test msmtp**:
   ```bash
   echo "Test email" | msmtp your-email@domain.com
   ```

## Configuration

### Basic Configuration

Edit `/etc/cron-email-reporter.conf`:

```bash
# Email configuration
CRON_EMAIL_TO="admin@yourdomain.com"
CRON_EMAIL_FROM="cronreports@$(hostname)"

# Log analysis settings (days to look back)
CRON_LOG_DAYS="1"

# Optional: Custom email subject
# CRON_EMAIL_SUBJECT="Custom Daily Cron Report - $(hostname) - $(date +%Y-%m-%d)"
```

### Advanced Configuration

You can customize the cron schedule by editing `/etc/cron.d/cron-email-reporter`:

```bash
# Default: Daily at 8:00 AM
0 8 * * * root source /etc/cron-email-reporter.conf 2>/dev/null || true; /usr/local/bin/cron-email-reporter.sh >> /var/log/cron-email-reporter.log 2>&1

# Weekly on Mondays at 9:00 AM
# 0 9 * * 1 root source /etc/cron-email-reporter.conf 2>/dev/null || true; /usr/local/bin/cron-email-reporter.sh >> /var/log/cron-email-reporter.log 2>&1
```

## Email Report Contents

Each report includes:

### System Information
- Hostname and uptime
- Load average
- Disk usage
- Memory usage

### Active Cron Jobs
- Root crontab entries
- System-wide cron jobs (`/etc/crontab`)
- Jobs in `/etc/cron.d/`
- User-specific cron jobs

### Log Analysis
- Recent cron activity (last N days)
- Failed job detection
- Error analysis

### System Events
- Recent system boots
- Service status
- System health indicators

## Email Service Setup

### Gmail Setup

1. **Enable 2-Factor Authentication** in your Google Account
2. **Generate an App Password**:
   - Go to Google Account settings → Security → App passwords
   - Create a new app password for "Mail"
3. **Configure msmtp** with the app password (not your regular password)

### Outlook/Hotmail Setup

1. **Use your regular email and password** in the msmtp configuration
2. **Ensure "Less secure app access"** is enabled if needed

### Custom SMTP Server

Configure your own SMTP server details in the msmtp configuration file.

## Troubleshooting

### Common Issues

1. **No emails received**:
   ```bash
   # Test mail system
   echo "Test email" | mail -s "Test" root
   
   # Check mail logs
   sudo tail -f /var/log/mail.log
   
   # Test the reporter script
   sudo /usr/local/bin/cron-email-reporter.sh
   ```

2. **Permission errors**:
   ```bash
   # Fix script permissions
   sudo chmod +x /usr/local/bin/cron-email-reporter.sh
   
   # Fix config permissions
   sudo chmod 600 /etc/msmtprc  # if using msmtp
   ```

3. **Cron job not running**:
   ```bash
   # Check cron service
   sudo systemctl status cron
   
   # Check cron logs
   sudo grep CRON /var/log/syslog
   
   # Verify cron job exists
   cat /etc/cron.d/cron-email-reporter
   ```

4. **Missing logs**:
   ```bash
   # Ensure rsyslog is running
   sudo systemctl status rsyslog
   
   # Check log file locations
   ls -la /var/log/cron* /var/log/syslog
   ```

### Debug Mode

Run the script manually to see detailed output:

```bash
sudo bash -x /usr/local/bin/cron-email-reporter.sh
```

## Customization

### Adding Custom Checks

You can modify `cron-email-reporter.sh` to add custom system checks:

```bash
# Add custom section
add_section "CUSTOM SYSTEM CHECKS"
echo "Custom check results:" >> "$TEMP_FILE"
# Add your custom commands here
```

### Filtering Logs

Modify the log analysis section to focus on specific cron jobs or exclude certain entries:

```bash
# Filter for specific cron jobs
grep "your-specific-job" "$CRON_LOG" >> "$TEMP_FILE"
```

## Security Considerations

1. **Protect configuration files**:
   ```bash
   sudo chmod 600 /etc/cron-email-reporter.conf
   sudo chmod 600 /etc/msmtprc
   ```

2. **Use app passwords** for Gmail instead of regular passwords

3. **Consider using GPG** to encrypt stored passwords:
   ```bash
   # Encrypt password
   echo "your-password" | gpg --encrypt -r your-email@domain.com > ~/.msmtp-password.gpg
   
   # Use in msmtp config
   passwordeval gpg --quiet --for-your-eyes-only --no-tty --decrypt ~/.msmtp-password.gpg
   ```

## Maintenance

### Log Rotation

Log rotation is automatically configured. Logs are rotated weekly and kept for 4 weeks.

### Updating the Script

To update the reporter script:

```bash
# Download new version
# Copy to system location
sudo cp cron-email-reporter.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/cron-email-reporter.sh
```

### Monitoring the Monitor

You can set up additional monitoring to ensure the email reporter itself is working:

```bash
# Add to your monitoring system
if [ ! -f /var/log/cron-email-reporter.log ] || [ $(find /var/log/cron-email-reporter.log -mtime +2) ]; then
    echo "Cron email reporter may not be working"
fi
```

## Uninstallation

To remove the cron email reporter:

```bash
sudo rm -f /usr/local/bin/cron-email-reporter.sh
sudo rm -f /etc/cron.d/cron-email-reporter
sudo rm -f /etc/cron-email-reporter.conf
sudo rm -f /etc/logrotate.d/cron-email-reporter
sudo rm -f /var/log/cron-email-reporter.log*
```

## Support

For issues, questions, or contributions:

1. Check the troubleshooting section above
2. Review system logs for error messages
3. Test individual components (mail system, cron service, script execution)
4. Ensure all dependencies are installed and configured correctly

## License

This project is open source and available under the MIT License.