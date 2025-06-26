#!/bin/bash

# Installation script for Cron Job Email Reporter
# Compatible with Ubuntu/Xubuntu systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. This is recommended for system-wide installation."
    else
        print_warning "Not running as root. Some features may require sudo privileges."
    fi
}

# Install required packages
install_packages() {
    print_status "Updating package list..."
    sudo apt update

    print_status "Installing required packages..."
    
    # Install mail utilities
    if ! command -v mail >/dev/null 2>&1; then
        print_status "Installing mailutils..."
        sudo apt install -y mailutils
    else
        print_success "mailutils already installed"
    fi

    # Install postfix for local mail delivery (optional)
    if ! command -v postfix >/dev/null 2>&1; then
        print_status "Installing postfix..."
        echo "postfix postfix/main_mailer_type select Local only" | sudo debconf-set-selections
        echo "postfix postfix/mailname string $(hostname)" | sudo debconf-set-selections
        sudo apt install -y postfix
    else
        print_success "postfix already installed"
    fi

    # Install other useful tools
    sudo apt install -y cron rsyslog
}

# Configure mail system
configure_mail() {
    print_status "Configuring mail system..."
    
    # Ensure postfix is configured for local delivery
    if [ -f /etc/postfix/main.cf ]; then
        sudo postconf -e "inet_interfaces = loopback-only"
        sudo postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
        sudo systemctl restart postfix
        print_success "Postfix configured for local delivery"
    fi

    # Test mail functionality
    print_status "Testing mail functionality..."
    if echo "Test email from cron-email-reporter installation" | mail -s "Test Email" root; then
        print_success "Mail test sent to root user"
    else
        print_warning "Mail test failed - you may need to configure your mail system manually"
    fi
}

# Install the cron reporter script
install_script() {
    SCRIPT_DIR="/usr/local/bin"
    SCRIPT_PATH="$SCRIPT_DIR/cron-email-reporter.sh"
    
    print_status "Installing cron-email-reporter script..."
    
    # Copy script to system location
    sudo cp cron-email-reporter.sh "$SCRIPT_PATH"
    sudo chmod +x "$SCRIPT_PATH"
    
    print_success "Script installed to $SCRIPT_PATH"
}

# Create configuration file
create_config() {
    CONFIG_FILE="/etc/cron-email-reporter.conf"
    
    print_status "Creating configuration file..."
    
    cat << 'EOF' | sudo tee "$CONFIG_FILE" > /dev/null
# Cron Email Reporter Configuration
# Customize these settings for your environment

# Email configuration
CRON_EMAIL_TO="admin@yourdomain.com"
CRON_EMAIL_FROM="cronreports@$(hostname)"

# Log analysis settings
CRON_LOG_DAYS="1"

# Additional settings
# CRON_EMAIL_SUBJECT="Custom Daily Cron Report - $(hostname) - $(date +%Y-%m-%d)"
EOF

    print_success "Configuration file created at $CONFIG_FILE"
    print_warning "Please edit $CONFIG_FILE to set your email address"
}

# Setup cron job
setup_cron() {
    print_status "Setting up daily cron job..."
    
    # Create cron job entry
    CRON_ENTRY="0 8 * * * root source /etc/cron-email-reporter.conf 2>/dev/null || true; /usr/local/bin/cron-email-reporter.sh >> /var/log/cron-email-reporter.log 2>&1"
    
    # Add to system crontab
    echo "$CRON_ENTRY" | sudo tee /etc/cron.d/cron-email-reporter > /dev/null
    
    # Ensure proper permissions
    sudo chmod 644 /etc/cron.d/cron-email-reporter
    
    print_success "Daily cron job installed (runs at 8:00 AM)"
    print_status "Cron job will source configuration from /etc/cron-email-reporter.conf"
}

# Create log file
setup_logging() {
    LOG_FILE="/var/log/cron-email-reporter.log"
    
    print_status "Setting up logging..."
    
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    
    # Create logrotate configuration
    cat << EOF | sudo tee /etc/logrotate.d/cron-email-reporter > /dev/null
$LOG_FILE {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

    print_success "Logging configured at $LOG_FILE"
}

# Test installation
test_installation() {
    print_status "Testing installation..."
    
    # Test script execution
    print_status "Running test report generation..."
    if sudo bash -c "source /etc/cron-email-reporter.conf 2>/dev/null || true; /usr/local/bin/cron-email-reporter.sh"; then
        print_success "Test report generated and sent successfully"
    else
        print_error "Test report failed"
        return 1
    fi
}

# Main installation process
main() {
    echo "=================================================="
    echo "  Cron Job Email Reporter Installation Script"
    echo "=================================================="
    echo ""
    
    check_root
    
    print_status "Starting installation process..."
    
    # Check if script exists
    if [ ! -f "cron-email-reporter.sh" ]; then
        print_error "cron-email-reporter.sh not found in current directory"
        exit 1
    fi
    
    # Installation steps
    install_packages
    configure_mail
    install_script
    create_config
    setup_cron
    setup_logging
    
    echo ""
    echo "=================================================="
    echo "              Installation Complete!"
    echo "=================================================="
    echo ""
    print_success "Cron Email Reporter has been successfully installed"
    echo ""
    echo "Next steps:"
    echo "1. Edit /etc/cron-email-reporter.conf to set your email address"
    echo "2. Test the installation by running:"
    echo "   sudo /usr/local/bin/cron-email-reporter.sh"
    echo "3. Check logs at: /var/log/cron-email-reporter.log"
    echo "4. Daily reports will be sent at 8:00 AM"
    echo ""
    echo "To customize the schedule, edit: /etc/cron.d/cron-email-reporter"
    echo ""
    
    # Ask if user wants to run test
    read -p "Would you like to run a test report now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_installation
    fi
}

# Run main function
main "$@" 