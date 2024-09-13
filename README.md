# phoenixd-docker

This script automates the setup process for Phoenixd and LNbits using Docker, including SSL certificate generation with Certbot.

## Prerequisites

Before running the script, ensure you have the following installed on your system:

1. **Docker**: 
   - Install Docker following the official documentation: https://docs.docker.com/get-docker/

2. **Docker Compose**:
   - Install Docker Compose following the official documentation: https://docs.docker.com/compose/install/

3. **Certbot**:
   - For Ubuntu/Debian: `sudo apt update && sudo apt install certbot`

4. **Git**:
   - For Ubuntu/Debian: `sudo apt install git`

5. **OpenSSL**:
   - This is usually pre-installed on most systems. If not:
     - For Ubuntu/Debian: `sudo apt install openssl`

## Domain Configuration

Ensure that you have two domain names pointed to your server's IP address:
- One for Phoenixd API
- One for LNbits interface

Both domains should be configured in your DNS settings before running the script.

## Running the Script

1. Clone this repository:
   ```
   git clone https://github.com/WhiteRabbit21m/phoenixd-docker.git
   cd phoenixd-docker
   ```

2. Make the script executable:
   ```
   chmod +x phoenixd-docker.sh
   ```

3. Run the script with sudo privileges:
   ```
   sudo ./phoenixd-docker.sh
   ```

4. Follow the prompts to enter your domain names, email address, and agree to the Let's Encrypt Terms of Service.

## Post-Installation

After the script completes:
- Access LNbits at `https://your-lnbits-domain`
- Access Phoenixd API at `https://your-phoenixd-domain`

Remember to securely store the generated passwords for Postgres and Phoenixd.

## Troubleshooting

If you encounter any issues:
1. Check the Docker logs: `docker compose logs [container_name]`
2. Ensure all prerequisites are correctly installed
3. Verify that your domains are correctly pointed to your server's IP address

For additional help, please open an issue in this repository.

## Security Notes

- This script generates real SSL certificates. Ensure you're running it on a production server with the correct domain names.
- The script requires root privileges to run Certbot and modify system files.
- Regularly update your system and Docker images to maintain security.

## Contributing

Contributions to improve the script are welcome. Please submit a pull request or open an issue for any enhancements.
