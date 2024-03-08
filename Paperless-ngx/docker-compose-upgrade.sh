#!/bin/bash

# This is a simple bash script to do a few things related to upgrading [Paperless-ngx](https://docs.paperless-ngx.com) if you're using the official docker containers.  It should help you 1) Backup your data 2) Stop your current containers 3) Download the latest version 4) Test-run that version 5) Run the new version in daemon mode (if all went well) and 6) purge any docker containers not currently in use (so you don't keep a huge number of old versions of things lying around).

# Define a file to capture docker compose output
DOCKER_OUTPUT_FILE="docker_output.log"

# Define colors for printing headers
print_green() {
    echo "\033[1;92m$1\033[0m"
}

print_red() {
    echo "\033[0;31m$1\033[0m"
}

# 1) Run the backup script
print_green "Starting the backup process..."
./backup.sh
if [ $? -ne 0 ]; then
    print_red "Backup process failed. Exiting..."
    exit 1
fi

# 2) Stop the Docker containers using Docker Compose
print_green "Stopping Docker containers..."
sudo docker compose down
if [ $? -ne 0 ]; then
    print_red "Error stopping containers. Exiting..."
    exit 1
fi

# 3) Pull new versions of the Docker container
print_green "Pulling new versions of the Docker container..."
sudo docker compose pull
if [ $? -ne 0 ]; then
    print_red "Error pulling new versions. Exiting..."
    exit 1
fi

# 4) Restart the container, outputting to a file
print_green "Restarting the container and capturing output for the next 30 seconds..."
sudo docker compose up > "$DOCKER_OUTPUT_FILE" 2>&1 &
DOCKER_PID=$!

# Wait for 30 seconds to capture some initial logs
sleep 30

# Display the captured output
print_green "Displaying initial docker compose up output:"
cat "$DOCKER_OUTPUT_FILE"

# 5) Wait for user input to confirm if things are working
print_green "Please review the output above. Enter 'y' if everything is working correctly, or any other key to stop."
read -p "Is everything working correctly? (y/n): " answer
if [ "$answer" != "y" ]; then
    print_red "User indicated a problem. Stopping the container in 30 seconds..."
    sudo docker compose down
    sleep 30
    kill $DOCKER_PID
    exit 1
fi

# If the user indicates everything is working, proceed to stop and restart the container in daemon mode
print_green "Proceeding to restart the container in daemon mode..."
sudo docker compose down
wait $DOCKER_PID # Ensure the background process is terminated

# Now restart in daemon mode
sudo docker compose up -d

# 8) Run a Docker system prune to remove older versions of the container
print_green "Cleaning up unused Docker objects..."
docker system prune -f
if [ $? -ne 0 ]; then
    print_red "Error pruning Docker system. Exiting..."
    exit 1
fi

print_green "Process completed successfully."