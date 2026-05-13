# WoW 3.3.5a AzerothCore Server with Playerbots

[![License](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)
[![Platform](https://img.shields.io/badge/platform-Arch%20Linux-blue.svg)](https://archlinux.org/)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)

A complete setup for running a World of Warcraft 3.3.5a private server using AzerothCore with the Playerbots module on Arch Linux. This setup uses Docker containers and includes comprehensive management scripts.

## Credits

This project uses:
- **AzerothCore** - The open-source World of Warcraft server core. Copyright (c) AzerothCore developers. Licensed under AGPLv3.
- **Playerbots Module** - Created by liyunfan1223 and contributors, based on the original work by ike3.
- **Docker Setup** - Based on the official AzerothCore Docker implementation.

This repository contains only management scripts. The AzerothCore server code is downloaded separately and remains under its original license.

## Prerequisites

- Arch Linux (other distributions may work with modifications)
- Docker and Docker Compose
- Git
- At least 8GB RAM (16GB recommended)
- 30GB free disk space
- WoW 3.3.5a client on a separate Windows machine (or Wine)

## Quick Start

Clone this repository and run the setup script:

```bash
git clone https://github.com/YOUR_USERNAME/wow.git
cd wow
chmod +x *.sh
./setup.sh
```

The setup script will:

    Install Docker and dependencies

    Clone AzerothCore Playerbots branch

    Clone the Playerbots module

    Build and start Docker containers

    Import required SQL files

    Create configuration directories

Scripts Reference
Script	Purpose
setup.sh	Initial installation and configuration
start.sh	Start the server
stop.sh	Stop the server
status.sh	Check server status and IP address
update.sh	Update AzerothCore and modules
sqldump.sh	Backup or restore databases
logs.sh	View live server logs
fix-permissions.sh	Fix common permission issues
Server Management
Starting the Server
bash

./start.sh

Stopping the Server
bash

./stop.sh

Checking Status
bash

./status.sh

This displays:

    Container status (database, authserver, worldserver)

    Server IP address for client configuration

Creating a GM Account

After starting the server, attach to the worldserver console:
bash

docker attach ac-worldserver

At the AC> prompt:
text

account create YourUsername YourPassword
account set gmlevel YourUsername 3 -1

Detach from the console using: Ctrl+P then Ctrl+Q
Viewing Logs
bash

# View worldserver logs (default)
./logs.sh

# View authserver logs
./logs.sh ac-authserver

# View database logs
./logs.sh ac-database

Backing Up Databases
bash

# Create a backup
./sqldump.sh --backup

# List available backups
./sqldump.sh --list

# Restore from a backup (YYYY-MM-DD format)
./sqldump.sh --restore 2024-01-15

Updating the Server
bash

./update.sh

This will:

    Prompt for a database backup

    Stop running containers

    Pull latest code from both repositories

    Rebuild containers

    Re-import required SQL files

Fixing Permission Issues

If you encounter permission errors:
bash

./fix-permissions.sh

This fixes ownership of configuration directories and removes stale PID files.
Client Configuration
On Your Windows Machine

    Locate your WoW 3.3.5a client folder

    Navigate to Data\enUS\ (or your language folder)

    Open realmlist.wtf in Notepad

    Replace contents with:

text

set realmlist YOUR_SERVER_IP

Replace YOUR_SERVER_IP with the IP address shown by ./status.sh on your Arch server.

    Save and launch Wow.exe (not the launcher)

Finding Your Server IP

From the Arch server:
bash

./status.sh

Or manually:
bash

hostname -I | awk '{print $1}'

Database Access
Connecting to MySQL
bash

docker exec -it ac-database mysql -uroot -ppassword

Key Database Tables
Database	Purpose	Key Tables
acore_auth	Account management	account, account_access, realmlist
acore_characters	Character data	characters, character_inventory, character_spell
acore_world	Game content	creature_template, item_template, quest_template
acore_playerbots	Bot data	playerbots_* tables
Useful Queries

List all accounts with GM levels:
sql

SELECT a.id, a.username, a.email, aa.gmlevel
FROM acore_auth.account a
LEFT JOIN acore_auth.account_access aa ON a.id = aa.id;

Update server address for client connections:
sql

UPDATE acore_auth.realmlist SET address = '192.168.1.100' WHERE id = 1;

Check online players:
sql

SELECT username FROM acore_auth.account WHERE online = 1;

Playerbots Commands

Once logged into the game as a GM, use these commands:
Command	Description
.playerbot bot add *	Add all your characters as bots
.playerbot bot add Name	Add a specific character as a bot
.playerbot bot remove Name	Remove a bot
.playerbot bot logout	Log out all bots
.playerbot rb status	Show random bot status
Bot Configuration

Edit wotlk/etc/modules/playerbots.conf to adjust bot behavior:
text

AiPlayerbot.RandomBotAutologin = 1
AiPlayerbot.MinRandomBots = 500
AiPlayerbot.MaxRandomBots = 1000
AiPlayerbot.EnableDebugLog = 0

After editing, restart the worldserver:
bash

docker restart ac-worldserver

GM Commands
Command	Security Level	Description
.levelup #	2	Level up character
.additem # [#]	2	Add item to character
.learn #	2	Learn a spell
.tele #	1	Teleport to location
.summon $name	1	Summon a player
.kick $name	1	Kick a player
.announce $msg	2	Broadcast message
.save	0	Save character data

For a complete list, type .help in the worldserver console or in-game.
Directory Structure
text

~/wow/
├── azerothcore-wotlk/      # AzerothCore source (not tracked by git)
├── wotlk/                  # Configuration files
│   └── etc/modules/        # Module configs
├── src/
│   └── .env                # Environment variables (not tracked)
├── sql_dumps/              # Database backups
├── setup.sh                # Installation script
├── start.sh                # Start server
├── stop.sh                 # Stop server
├── status.sh               # Check status
├── update.sh               # Update server
├── sqldump.sh              # Backup/restore
├── logs.sh                 # View logs
├── fix-permissions.sh      # Fix permissions
└── README.md               # This file

Troubleshooting
Permission Denied on Docker Socket

Error: permission denied while trying to connect to the Docker daemon socket

Solution:
bash

sudo usermod -aG docker $USER
# Log out and log back in, then retry

Container Stuck in "Restarting" Loop

Error: cannot attach to a restarting container

Solution:
bash

# Check the logs first
docker logs ac-worldserver --tail 50

# Common fixes:
./fix-permissions.sh
cd azerothcore-wotlk && docker compose down && docker compose up -d

Missing charsections_dbc Table

Error: Table 'acore_world.charsections_dbc' doesn't exist

Solution:
bash

cd azerothcore-wotlk/modules/mod-playerbots
wget https://raw.githubusercontent.com/ZhengPeiRu21/mod-playerbots/AzerothCore/sql/world/world_charsections_dbc.sql
docker exec -i ac-database mysql -uroot -ppassword acore_world < world_charsections_dbc.sql
docker restart ac-worldserver

Port Already in Use

Error: port is already allocated

Solution:
bash

# Find what's using the port (3724 or 8085)
sudo ss -tlnp | grep -E '(3724|8085)'

# Stop the conflicting service or change ports in docker-compose.override.yml

Database Connection Failed

Error: Could not connect to MySQL database

Solution:
bash

# Check if database container is running
docker ps | grep ac-database

# Restart database if needed
docker compose restart ac-database

# Wait 30 seconds for initialization
sleep 30

Client Cannot Connect

Checklist:

    Verify server is running: ./status.sh

    Verify realmlist.wtf has correct IP

    Test port connectivity from Windows:
    cmd

    telnet YOUR_SERVER_IP 3724

    Check Windows Firewall isn't blocking WoW

    Verify database realmlist table has correct address:
    bash

    docker exec -it ac-database mysql -uroot -ppassword -e "SELECT address FROM acore_auth.realmlist;"

Out of Memory Errors

Error: Cannot allocate memory or container OOMKilled

Solution:
bash

# Check memory usage
docker stats

# Reduce bot counts in playerbots.conf:
AiPlayerbot.MinRandomBots = 100
AiPlayerbot.MaxRandomBots = 200

# Restart the server
docker restart ac-worldserver

Stale PID File

Error: Cannot connect to the Docker daemon at unix:///var/run/docker.sock

Solution:
bash

sudo rm -f /tmp/docker-compose.pid
./fix-permissions.sh

Git Nested Repository Warning

Issue: .git directory exists inside azerothcore-wotlk/ (upstream) and also in the parent directory (your personal repo)

Solution: Add azerothcore-wotlk/ to .gitignore in your personal repository:
bash

echo "azerothcore-wotlk/" >> .gitignore
git add .gitignore
git commit -m "Ignore AzerothCore directory"

Network Configuration
Local Network Only (LAN)

No port forwarding required. Use the server's local IP address from ./status.sh.
Remote Access (Internet)

Two secure methods:

Method 1: Tailscale VPN (Recommended)
bash

# On Arch server
sudo pacman -S tailscale
sudo systemctl enable tailscaled --now
sudo tailscale up

# On Windows client - install Tailscale and log in
# Use the Tailscale IP (100.x.x.x) in realmlist.wtf

Method 2: SSH Tunnel (Simple)
bash

# From Windows (using PowerShell or WSL)
ssh -L 3724:localhost:3724 -L 8085:localhost:8085 user@YOUR_ARCH_IP -N
# Set realmlist.wtf to 127.0.0.1

Uninstalling

To completely remove the server:
bash

cd ~/wow/azerothcore-wotlk
docker compose down -v
cd ..
rm -rf azerothcore-wotlk wotlk sql_dumps mysql-data

Remove Docker (if desired):
bash

sudo pacman -Rns docker docker-compose
sudo rm -rf /var/lib/docker

System Requirements
Component	Minimum	Recommended
CPU	2 cores	4+ cores
RAM	8GB	16GB+
Storage	30GB	50GB+
Network	100Mbps	Gigabit
License

The scripts in this repository are provided under the MIT License. AzerothCore itself is licensed under AGPLv3. The WoW client is property of Blizzard Entertainment and is not included.
Contributing

Issues and pull requests are welcome. Ensure scripts are tested and include error handling.
Support

For AzerothCore specific issues, refer to the official documentation. For Playerbots module issues, refer to the module repository. For Docker issues, refer to Docker documentation.
