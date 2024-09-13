#!/bin/bash

set -e

# Function to generate a random password
generate_password() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

# Function to update or add a variable in the .env file
update_env() {
    local key=$1
    local value=$2
    local file=".env"
    if grep -q "^$key=" "$file"; then
        sed -i "s|^$key=.*|$key=$value|" "$file"
    else
        echo "$key=$value" >> "$file"
    fi
}

# Clone the repository
git clone https://github.com/massmux/phoenixd-docker.git
cd phoenixd-docker

echo "Repository cloned successfully."

# Copy example files
cp docker-compose.yml.example docker-compose.yml
cp default.conf.example default.conf
cp .env.example .env

echo "Example files copied and renamed."

# Request domains from the user
read -p "Enter the domain for Phoenixd API (e.g., api.yourdomain.com): " PHOENIXD_DOMAIN
read -p "Enter the domain for LNbits (e.g., lnbits.yourdomain.com): " LNBITS_DOMAIN

# Function to generate certificates
generate_certificates() {
    local phoenixd_domain=$1
    local lnbits_domain=$2
    local cert_dir="letsencrypt/live"

    echo "Generating self-signed certificates for testing..."

    # Create necessary directories
    mkdir -p "$cert_dir/$phoenixd_domain"
    mkdir -p "$cert_dir/$lnbits_domain"

    # Generate certificates for Phoenixd domain
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/$phoenixd_domain/privkey.pem" \
        -out "$cert_dir/$phoenixd_domain/fullchain.pem" \
        -subj "/CN=$phoenixd_domain" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "Certificates for $phoenixd_domain generated successfully."
    else
        echo "An error occurred while generating certificates for $phoenixd_domain."
        exit 1
    fi

    # Generate certificates for LNbits domain
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/$lnbits_domain/privkey.pem" \
        -out "$cert_dir/$lnbits_domain/fullchain.pem" \
        -subj "/CN=$lnbits_domain" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "Certificates for $lnbits_domain generated successfully."
    else
        echo "An error occurred while generating certificates for $lnbits_domain."
        exit 1
    fi

    echo "Self-signed certificates generated successfully for testing."
}

# Generate certificates
generate_certificates $PHOENIXD_DOMAIN $LNBITS_DOMAIN

# Generate password for Postgres
POSTGRES_PASSWORD=$(generate_password)

# Update the .env file
echo "Updating the .env file..."

# Remove or comment out unnecessary variables
sed -i '/^LNBITS_BACKEND_WALLET_CLASS=/d' .env
sed -i '/^PHOENIXD_API_ENDPOINT=/d' .env
sed -i '/^PHOENIXD_API_PASSWORD=/d' .env
sed -i '/^LNBITS_DATABASE_URL=/d' .env
sed -i '/^LNBITS_SITE_TITLE=/d' .env
sed -i '/^LNBITS_SITE_TAGLINE=/d' .env
sed -i '/^LNBITS_SITE_DESCRIPTION=/d' .env

# Add or update necessary variables
update_env "LNBITS_BACKEND_WALLET_CLASS" "PhoenixdWallet"
update_env "PHOENIXD_API_ENDPOINT" "http://phoenixd:9740/"
update_env "LNBITS_DATABASE_URL" "postgres://postgres:$POSTGRES_PASSWORD@postgres:5432/lnbits"
update_env "LNBITS_SITE_TITLE" "$LNBITS_DOMAIN"
update_env "LNBITS_SITE_TAGLINE" "free and open-source lightning wallet"
update_env "LNBITS_SITE_DESCRIPTION" "The world's most powerful suite of bitcoin tools. Run for yourself, for others, or as part of a stack."

# Add a comment for PHOENIXD_API_PASSWORD
echo "# PHOENIXD_API_PASSWORD will be set after the first run" >> .env

echo ".env file updated successfully."

# Update the docker-compose.yml file
sed -i "s/POSTGRES_PASSWORD: XXXX/POSTGRES_PASSWORD: $POSTGRES_PASSWORD/" docker-compose.yml

# Update the default.conf file
echo "Updating the default.conf file..."
sed -i "s/server_name n1\.yourdomain\.com;/server_name $PHOENIXD_DOMAIN;/" default.conf
sed -i "s/server_name lb1\.yourdomain\.com;/server_name $LNBITS_DOMAIN;/" default.conf
sed -i "s|ssl_certificate /etc/letsencrypt/live/n1\.yourdomain\.com/|ssl_certificate /etc/letsencrypt/live/$PHOENIXD_DOMAIN/|" default.conf
sed -i "s|ssl_certificate_key /etc/letsencrypt/live/n1\.yourdomain\.com/|ssl_certificate_key /etc/letsencrypt/live/$PHOENIXD_DOMAIN/|" default.conf
sed -i "s|ssl_certificate /etc/letsencrypt/live/lb1\.yourdomain\.com/|ssl_certificate /etc/letsencrypt/live/$LNBITS_DOMAIN/|" default.conf
sed -i "s|ssl_certificate_key /etc/letsencrypt/live/lb1\.yourdomain\.com/|ssl_certificate_key /etc/letsencrypt/live/$LNBITS_DOMAIN/|" default.conf

echo "Configuration completed. Certificates have been generated for $PHOENIXD_DOMAIN and $LNBITS_DOMAIN, Postgres password has been generated, and configuration files have been updated."
echo "The generated password for Postgres is: $POSTGRES_PASSWORD"
echo "Make sure to save this password in a secure location."

# Build Docker images
echo "Building Docker images..."
docker build -t massmux/nginx -f Dockerfile.nginx .
docker build -t massmux/phoenixd -f Dockerfile .
docker build -t massmux/lnbits:0.12.6 -f lnbits/Dockerfile .

# Function to wait for a container to be ready
wait_for_container() {
    echo "Waiting for $1 to be ready..."
    until [ "`docker inspect -f {{.State.Running}} $1`"=="true" ]; do
        sleep 1;
    done;
    echo "$1 is ready."
}

# Start the Postgres container
echo "Starting the Postgres container..."
docker compose up -d postgres

# Wait for Postgres to be ready
echo "Waiting for Postgres to be ready..."
until docker compose exec postgres pg_isready
do
  echo "Postgres is not ready yet. Waiting..."
  sleep 2
done
echo "Postgres is ready."

# Start the Phoenixd container
echo "Starting the Phoenixd container..."
docker compose up -d phoenixd
wait_for_container phoenixd

# Start the LNbits container
echo "Starting the LNbits container..."
docker compose up -d lnbits
wait_for_container lnbits

# Start the Nginx container
echo "Starting the Nginx container..."
docker compose up -d nginx
wait_for_container nginx

echo "All containers have been started."

# Wait a bit to allow containers to fully initialize
echo "Waiting 30 seconds to allow for complete initialization..."
sleep 30

# Stop all containers
echo "Stopping all containers..."
docker compose down

echo "All containers have been stopped."

# Configure phoenix.conf and update .env
echo "Configuring phoenix.conf and updating .env..."

# Use the relative path to the current directory
PHOENIX_CONF="$(pwd)/data/phoenix.conf"

if [ ! -f "$PHOENIX_CONF" ]; then
    echo "ERROR: phoenix.conf file not found in $PHOENIX_CONF"
    echo "Contents of the current directory:"
    ls -la
    echo "Contents of the data directory:"
    ls -la data/
    exit 1
fi

# Add http-bind-ip=0.0.0.0 at the beginning of the file if it doesn't exist
if ! grep -q "^http-bind-ip=0.0.0.0" "$PHOENIX_CONF"; then
    sed -i '1ihttp-bind-ip=0.0.0.0' "$PHOENIX_CONF"
    echo "http-bind-ip=0.0.0.0 added to phoenix.conf"
else
    echo "http-bind-ip=0.0.0.0 already present in phoenix.conf"
fi

# Extract Phoenixd password
PHOENIXD_PASSWORD=$(grep -oP '(?<=http-password=).*' "$PHOENIX_CONF")
if [ -n "$PHOENIXD_PASSWORD" ]; then
    echo "Phoenixd password found: $PHOENIXD_PASSWORD"
    update_env "PHOENIXD_API_PASSWORD" "$PHOENIXD_PASSWORD"
    echo "PHOENIXD_API_PASSWORD updated in .env file"
else
    echo "WARNING: Phoenixd password not found in phoenix.conf"
    echo "Contents of phoenix.conf:"
    cat "$PHOENIX_CONF"
fi

# Verify the contents of the .env file
echo "Relevant contents of the .env file after update:"
grep -E "^(LNBITS_BACKEND_WALLET_CLASS|PHOENIXD_API_ENDPOINT|PHOENIXD_API_PASSWORD|LNBITS_DATABASE_URL|LNBITS_SITE_TITLE|LNBITS_SITE_TAGLINE|LNBITS_SITE_DESCRIPTION)=" .env

echo "Configuration of phoenix.conf and .env update completed."

echo "Setup completed."
echo "Remember to save the Postgres password and Phoenixd password in a secure location:"
echo "Postgres password: $POSTGRES_PASSWORD"
echo "Phoenixd password: $PHOENIXD_PASSWORD"

# Restart all containers
echo "Restarting all containers with the new configurations..."
docker compose up -d

# Wait for all containers to be ready
wait_for_container postgres
wait_for_container phoenixd
wait_for_container lnbits
wait_for_container nginx

echo "All containers have been successfully started with the new configurations."
echo "Your system is now ready for use."
echo "You can access LNbits at https://$LNBITS_DOMAIN"
echo "The Phoenixd API is accessible at https://$PHOENIXD_DOMAIN"
echo "To manage the containers, use the docker compose commands in the project directory."
echo "To view container logs, use 'docker compose logs [container_name]'"
