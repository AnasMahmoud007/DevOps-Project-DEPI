#!/bin/bash

# --- Configuration ---
SQL_SERVER_IMAGE="anasmahmoud007/devops-project-depi:hotel-sqlserver-final"
WEB_APP_IMAGE="anasmahmoud007/devops-project-depi:hotel-webapp-updated"
SQL_SERVER_CONTAINER_NAME="hotel_db_container"
WEB_APP_CONTAINER_NAME="hotel_webapp_container"
DOCKER_NETWORK_NAME="hotel-network"
SQL_INIT_SCRIPT_PATH="./DatabaseTables/full_init.sql"
WEB_APP_PORT="5001"
SQL_SERVER_PORT="1433"
SA_PASSWORD="Hotel!StrongPass123"

# --- Functions ---

# Function to check if a Docker image exists
image_exists() {
  docker images -q "$1" | grep -q .
}

# Function to check if a Docker container exists (running or stopped)
container_exists() {
  docker ps -a --filter "name=$1" | grep -q "$1"
}

# Function to check if a Docker network exists
network_exists() {
  docker network ls --filter "name=$1" | grep -q "$1"
}

# Function to clean up existing containers and network
cleanup() {
  echo "--- Cleaning up existing Docker resources ---"
  if container_exists "$WEB_APP_CONTAINER_NAME"; then
    echo "Stopping and removing $WEB_APP_CONTAINER_NAME..."
    docker stop "$WEB_APP_CONTAINER_NAME" > /dev/null 2>&1
    docker rm "$WEB_APP_CONTAINER_NAME" > /dev/null 2>&1
  fi
  if container_exists "$SQL_SERVER_CONTAINER_NAME"; then
    echo "Stopping and removing $SQL_SERVER_CONTAINER_NAME..."
    docker stop "$SQL_SERVER_CONTAINER_NAME" > /dev/null 2>&1
    docker rm "$SQL_SERVER_CONTAINER_NAME" > /dev/null 2>&1
  fi
  if network_exists "$DOCKER_NETWORK_NAME"; then
    echo "Removing $DOCKER_NETWORK_NAME..."
    docker network rm "$DOCKER_NETWORK_NAME" > /dev/null 2>&1
  fi
  echo "Cleanup complete."
}

# --- Main Script ---

echo "--- Starting Hotel Project Setup ---"

# 1. Load Docker Images
echo "1. Loading Docker images..."

# --- Web App Image ---
WEB_APP_TAR="hotel-webapp-updated.tar"
if [ -f "$WEB_APP_TAR" ]; then
  echo "Loading $WEB_APP_IMAGE from $WEB_APP_TAR..."
  docker load -i "$WEB_APP_TAR" || { echo "Error loading $WEB_APP_IMAGE from tarball. Exiting."; exit 1; }
else
  echo "$WEB_APP_TAR not found."
  if ! image_exists "$WEB_APP_IMAGE"; then
    echo "Pulling $WEB_APP_IMAGE from Docker Hub..."
    docker pull "$WEB_APP_IMAGE" || { echo "Error pulling $WEB_APP_IMAGE from Docker Hub. Exiting."; exit 1; }
  else
    echo "$WEB_APP_IMAGE already exists locally."
  fi
fi

# --- SQL Server Image ---
SQL_SERVER_TAR="hotel-sqlserver-final.tar"
if [ -f "$SQL_SERVER_TAR" ]; then
  echo "Loading $SQL_SERVER_IMAGE from $SQL_SERVER_TAR..."
  docker load -i "$SQL_SERVER_TAR" || { echo "Error loading $SQL_SERVER_IMAGE from tarball. Exiting."; exit 1; }
else
  echo "$SQL_SERVER_TAR not found."
  if ! image_exists "$SQL_SERVER_IMAGE"; then
    echo "Pulling $SQL_SERVER_IMAGE from Docker Hub..."
    docker pull "$SQL_SERVER_IMAGE" || { echo "Error pulling $SQL_SERVER_IMAGE from Docker Hub. Exiting."; exit 1; }
  else
    echo "$SQL_SERVER_IMAGE already exists locally."
  fi
fi

echo "Docker images are ready."

# 2. Create Docker Network
echo "2. Creating Docker network '$DOCKER_NETWORK_NAME'..."
if ! network_exists "$DOCKER_NETWORK_NAME"; then
  docker network create "$DOCKER_NETWORK_NAME" || { echo "Error creating network. Exiting."; exit 1; }
  echo "Network '$DOCKER_NETWORK_NAME' created."
else
  echo "Network '$DOCKER_NETWORK_NAME' already exists."
fi

# 3. Run SQL Server Container
echo "3. Running SQL Server container '$SQL_SERVER_CONTAINER_NAME'..."
if container_exists "$SQL_SERVER_CONTAINER_NAME"; then
  echo "Container '$SQL_SERVER_CONTAINER_NAME' already exists. Cleaning up first."
  cleanup
  # Re-create network if it was removed during cleanup
  if ! network_exists "$DOCKER_NETWORK_NAME"; then
    docker network create "$DOCKER_NETWORK_NAME" || { echo "Error re-creating network after cleanup. Exiting."; exit 1; }
  fi
fi

docker run -d \
  --name "$SQL_SERVER_CONTAINER_NAME" \
  --network "$DOCKER_NETWORK_NAME" \
  -e 'ACCEPT_EULA=Y' \
  -e "MSSQL_SA_PASSWORD=$SA_PASSWORD" \
  -e 'MSSQL_PID=Developer' \
  -p "$SQL_SERVER_PORT":"$SQL_SERVER_PORT" \
  --user root \
  "$SQL_SERVER_IMAGE" || { echo "Error running SQL Server container. Exiting."; exit 1; }
echo "SQL Server container '$SQL_SERVER_CONTAINER_NAME' started."

# 4. Wait for SQL Server to Start
echo "4. Waiting for SQL Server to start (30 seconds)..."
sleep 30
echo "SQL Server should be ready."

# 5. Execute Database Initialization Script
echo "5. Executing database initialization script '$SQL_INIT_SCRIPT_PATH'..."
if [ -f "$SQL_INIT_SCRIPT_PATH" ]; then
  docker exec -i "$SQL_SERVER_CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -N -C < "$SQL_INIT_SCRIPT_PATH" || { echo "Error executing SQL init script. Exiting."; exit 1; }
  echo "Database initialization script executed successfully."
else
  echo "Error: SQL initialization script '$SQL_INIT_SCRIPT_PATH' not found. Skipping database setup."
fi

# 6. Run Web Application Container
echo "6. Running Web Application container '$WEB_APP_CONTAINER_NAME'..."
if container_exists "$WEB_APP_CONTAINER_NAME"; then
  echo "Container '$WEB_APP_CONTAINER_NAME' already exists. Cleaning up first."
  docker stop "$WEB_APP_CONTAINER_NAME" > /dev/null 2>&1
  docker rm "$WEB_APP_CONTAINER_NAME" > /dev/null 2>&1
fi

docker run -d \
  --name "$WEB_APP_CONTAINER_NAME" \
  --network "$DOCKER_NETWORK_NAME" \
  -p "$WEB_APP_PORT":80 \
  -e "ASPNETCORE_ENVIRONMENT=Development" \
  -e "ConnectionStrings__DefaultConnection=Server=$SQL_SERVER_CONTAINER_NAME;Database=Hotel;User Id=sa;Password=$SA_PASSWORD;TrustServerCertificate=True;" \
  "$WEB_APP_IMAGE" || { echo "Error running Web Application container. Exiting."; exit 1; }
echo "Web Application container '$WEB_APP_CONTAINER_NAME' started."

echo "--- Hotel Project Setup Complete ---"

# 7. Accessing the Application
echo ""
echo "Access the application by opening your web browser and navigating to:"
echo "http://localhost:$WEB_APP_PORT"
echo ""
echo "Login Credentials:"
echo "For Guest Login (via main login page):"
echo "  Username: testuser"
echo "  Password: password123"
echo "  (Alternatively: admin / admin123)"
echo ""
echo "For Admin Login (if using a separate admin login page like loginHE):"
echo "  Username: admin"
echo "  Password: Admin!123"
echo ""

# 8. Cleanup Instructions
echo "To clean up and stop/remove the containers and network when you are done, run the following commands:"
echo "docker stop $WEB_APP_CONTAINER_NAME $SQL_SERVER_CONTAINER_NAME"
echo "docker rm $WEB_APP_CONTAINER_NAME $SQL_SERVER_CONTAINER_NAME"
echo "docker network rm $DOCKER_NETWORK_NAME"
