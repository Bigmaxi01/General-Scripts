#!/bin/bash

# Variables

script_path="/usr/local/bin/web_watchdog.sh"
service_name="web_watchdog"
config_file="/etc/default/web_watchdog"

# Default configuration content
default_config="# Configuration file for Web Watchdog

# Website to check for connectivity
website_to_check=\"google.com\"

# Maximum number of tries before reboot
max_tries=3

# Time interval between tries (in seconds)
time_interval=30

# Log file path
log_file=\"/var/log/web_watchdog.log\"

# Path to the internet checker script
script_path=\"/usr/local/bin/web_watchdog.sh\"

# Enable or disable logging (true/false)
enable_logging=true
"

# Check if config file exists, if not, create it with default content
if [ ! -f "$config_file" ]; then
    echo "Creating default configuration file at $config_file..."
    echo "$default_config" | sudo tee "$config_file" > /dev/null
fi


# Create the internet checker script
cat <<EOL > "$script_path"
#!/bin/bash

# Variables
# Load variables from the configuration file
source "$config_file"


# Function to check internet connection
check_internet_connection() {
    if ping -c 1 "$website_to_check" >/dev/null 2>&1; then
        return 0  # Connection successful
    else
        return 1  # Connection failed
    fi
}

# Function to log results
log_result() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Main loop
for ((try_count = 1; try_count <= max_tries; try_count++)); do
    log_result "Checking internet connection (Try $try_count/$max_tries)..."

    if check_internet_connection; then
        log_result "Connection to $website_to_check successful."
        exit 0  # Exit script successfully
    else
        log_result "Connection to $website_to_check failed."

        if [ "$try_count" -lt "$max_tries" ]; then
            log_result "Waiting for $time_interval seconds before the next try..."
            sleep "$time_interval"
        fi
    fi
done

# Reboot if all tries fail
log_result "Connection to $website_to_check unsuccessful after $max_tries tries. Rebooting..."
sudo reboot

EOL

chmod +x "$script_path"

# Create the systemd service file
cat <<EOL > "/etc/systemd/system/$service_name.service"
[Unit]
Description=Internet Up Watchdog
After=network.target

[Service]
ExecStart=$script_path
Restart=always

[Install]
WantedBy=default.target
EOL

# Reload systemd
sudo systemctl daemon-reload

# Enable and start the service
sudo systemctl enable --now "$service_name.service"
#sudo systemctl start "$service_name.service"

# Display status
sudo systemctl status "$service_name.service"

echo "Internet checker service deployed successfully."

