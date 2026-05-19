# WoW 3.3.5a AzerothCore Server with Playerbots

 [![License](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)
 [![Platform](https://img.shields.io/badge/platform-Arch%20Linux-blue.svg)](https://archlinux.org/)
 [![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)

 A complete setup for running a World of Warcraft 3.3.5a private server using AzerothCore 
 with the Playerbots module on Arch Linux. This setup uses Docker containers and includes 
 comprehensive management scripts.


CREDITS

 This project uses:
- AzerothCore - The open-source World of Warcraft server core. 
  Copyright (c) AzerothCore developers. Licensed under AGPLv3.
- Playerbots Module - Created by liyunfan1223 and contributors, based on the 
  original work by ike3.
- Docker Setup - Based on the official AzerothCore Docker implementation.

This repository contains only management scripts. The AzerothCore server code 
is downloaded separately and remains under its original license.


 PREREQUISITES
 
 - Arch Linux (other distributions may work with modifications)
 - Docker and Docker Compose
 - Git
 - At least 8GB RAM (16GB recommended)
- 30GB free disk space
- WoW 3.3.5a client on a separate Windows machine (or Wine)

 
 QUICK START
 
 Clone this repository and run the setup script:

```
git clone https://github.com/ffdiracex/wow.git

cd wow

chmod +x *.sh

./_setup.sh
```

----The setup script will:
   1. Install Docker and dependencies
  2. Clone AzerothCore Playerbots branch
   3. Clone the Playerbots module
   4. Build and start Docker containers
   5. Import required SQL files
   6. Create configuration directories

SCRIPTS REFERENCE
- _setup.sh           - Initial installation and configuration
- start_stop_acore.sh           - Start the server, or stop the server IF running. it will automatically determine.
- update.sh          - Update AzerothCore and modules
- sqldump.sh         - Backup or restore databases

SERVER MANAGEMENT
```
Starting the Server
./start_stop_acore.sh
```

```
# Stopping the Server
./start_stop_acore.sh

# Creating a GM Account
 After starting the server, attach to the worldserver console:
docker attach ac-worldserver

# At the AC> prompt:
account create YourUsername YourPassword
account set gmlevel YourUsername 3 -1

# Viewing Logs
docker logs <ac-*> // select what endpoint you want to log, is it the ac-worldserver? specify please

# Backing Up Databases
./sqldump.sh --backup                //Create a backup
./sqldump.sh --list                  //List available backups
./sqldump.sh --restore 2026-01-15   // Restore from a backup (YYYY-MM-DD format)
```

- Updating the Server
``` ./update.sh ```
- This will:
   - Prompt for a database backup
   - Stop running containers
   - Pull latest code from both repositories
   - Rebuild containers
   - Re-import required SQL files

- Fixing Permission Issues
```
sudo chown -R 1000:1000 wotlk
```
This fixes ownership of configuration directories and removes stale PID files.

- CLIENT CONFIGURATION

- On Your Windows Machine:
   1. Locate your WoW 3.3.5a client folder
   2. Navigate to Data\enUS\ (or your language folder)
   3. Open realmlist.wtf in Notepad
   4. Replace contents with:
set realmlist YOUR_SERVER_IP // 192.168.xxx.xxx or 10.0.xxx.xxx or 172.xxx.xxx.xxx
   5. Save and launch Wow.exe (not the launcher)

- Finding Your Server IP (from Arch server):
- 
``` hostname -I | awk '{print $1}' ``` 
   OR
```ip addr show ``` and look for wlp2s0 (Wi-Fi) or enp2s0 (ethernet)

DATABASE ACCESS

- Connecting to MySQL:
``` docker exec -it ac-database mysql -uroot -ppassword ```

- Key Database Tables:
   acore_auth        - Account management (account, account_access, realmlist)
   acore_characters  - Character data (characters, character_inventory, character_spell)
  acore_world       - Game content (creature_template, item_template, quest_template)
   acore_playerbots  - Bot data (playerbots_* tables)

- Useful Queries:

 List all accounts with GM levels:
 ```
docker exec -it ac-database mysql -uroot -ppassword -e "
SELECT a.id, a.username, a.email, aa.gmlevel
FROM acore_auth.account a
LEFT JOIN acore_auth.account_access aa ON a.id = aa.id;"
```

Update server address for client connections:
```
docker exec -it ac-database mysql -uroot -ppassword -e "
UPDATE acore_auth.realmlist SET address = '192.168.1.100' WHERE id = 1;"
```

 Check online players:
```
docker exec -it ac-database mysql -uroot -ppassword -e "
SELECT username FROM acore_auth.account WHERE online = 1;"
```

 PLAYERBOTS COMMANDS

Once logged into the game as a GM, use these commands:
```
   .playerbot bot add *          # Add all your characters as bots
   .playerbot bot add Name       # Add a specific character as a bot
   .playerbot bot remove Name    # Remove a bot
   .playerbot bot logout         # Log out all bots
  .playerbot rb status          # Show random bot status
```

 Bot Configuration:
 Edit wotlk/etc/modules/playerbots.conf to adjust bot behavior:
```
   AiPlayerbot.RandomBotAutologin = 1
   AiPlayerbot.MinRandomBots = 500
   AiPlayerbot.MaxRandomBots = 1000
   AiPlayerbot.EnableDebugLog = 0
```
After editing, restart the worldserver:
docker restart ac-worldserver

```
GM COMMANDS

 .levelup            - Level up character (level 2)
 .additem  [ID]       - Add item to character (level 2)
 .learn              - Learn a spell (level 2)
 .tele LOCATION              - Teleport to location (level 1)
 .summon $name        - Summon a player (level 1)
 .kick $name          - Kick a player (level 1)
 .announce $msg       - Broadcast message (level 2)
 .save                - Save character data (level 0)

 For a complete list, type .help in the worldserver console or in-game.

```
```
 DIRECTORY STRUCTURE
 ~/wow/
 ├── azerothcore-wotlk/      # AzerothCore source (not tracked by git)
 ├── wotlk/                   #Configuration files
 │   └── etc/modules/         #Module configs
 ├── src/
 │   └── .env                 #Environment variables (not tracked)
 ├── sql_dumps/               #Database backups //not there by default, is created upon running sqldump.sh
 ├── setup.sh                 #Installation script
 ├── start_stop_acore.sh      #Start server /  Stop server
 ├── update.sh                #Update server
 ├── sqldump.sh               #Backup/restore
 └── README.md                #This file
```

 TROUBLESHOOTING

 Permission Denied on Docker Socket
 Error: permission denied while trying to connect to the Docker daemon socket
sudo usermod -aG docker $USER
 Log out and log back in, then retry

Container Stuck in "Restarting" Loop
 Error: cannot attach to a restarting container
docker logs ac-worldserver --tail 50
./fix-permissions.sh
cd azerothcore-wotlk && docker compose down && docker compose up -d

 Missing charsections_dbc Table
 Error: Table 'acore_world.charsections_dbc' doesn't exist

cd azerothcore-wotlk/modules/mod-playerbots

wget https://raw.githubusercontent.com/ZhengPeiRu21/mod-playerbots/AzerothCore/sql/world/world_charsections_dbc.sql
docker exec -i ac-database mysql -uroot -ppassword acore_world < world_charsections_dbc.sql
docker restart ac-worldserver

 Port Already in Use
 Error: port is already allocated
sudo ss -tlnp | grep -E '(3724|8085)'
 Stop the conflicting service or change ports in docker-compose.override.yml

 Database Connection Failed
 Error: Could not connect to MySQL database
docker ps | grep ac-database
docker compose restart ac-database
sleep 30

 Client Cannot Connect - Checklist:
   1. Verify server is running: ./status.sh
   2. Verify realmlist.wtf has correct IP
   3. Test port connectivity from Windows:
        telnet YOUR_SERVER_IP 3724
   4. Check Windows Firewall isn't blocking WoW
   5. Verify database realmlist table:
docker exec -it ac-database mysql -uroot -ppassword -e "SELECT address FROM acore_auth.realmlist;"

 Out of Memory Errors
 Error: Cannot allocate memory or container OOMKilled
docker stats
 Reduce bot counts in playerbots.conf:
   AiPlayerbot.MinRandomBots = 100
   AiPlayerbot.MaxRandomBots = 200
docker restart ac-worldserver

 Stale PID File
 Error: Cannot connect to the Docker daemon at unix:///var/run/docker.sock
sudo rm -f /tmp/docker-compose.pid
./fix-permissions.sh

 Git Nested Repository Warning
 Issue: .git directory exists inside azerothcore-wotlk/ and also in parent directory
echo "azerothcore-wotlk/" >> .gitignore
git add .gitignore
git commit -m "Ignore AzerothCore directory"

 NETWORK CONFIGURATION

 Local Network Only (LAN)
No port forwarding required. Use the server's local IP from ./status.sh.

 Remote Access (Internet) - Method 1: Tailscale VPN (Recommended)
sudo pacman -S tailscale
sudo systemctl enable tailscaled --now
sudo tailscale up
 On Windows client - install Tailscale and log in
 Use the Tailscale IP (100.x.x.x) in realmlist.wtf

 Remote Access (Internet) - Method 2: SSH Tunnel (Simple)
 From Windows (using PowerShell or WSL):
ssh -L 3724:localhost:3724 -L 8085:localhost:8085 user@YOUR_ARCH_IP -N
 Set realmlist.wtf to 127.0.0.1

 UNINSTALLING

 To completely remove the server:
cd ~/wow/azerothcore-wotlk
docker compose down -v
cd ..
rm -rf azerothcore-wotlk wotlk sql_dumps mysql-data

 Remove Docker (if desired):
sudo pacman -Rns docker docker-compose
sudo rm -rf /var/lib/docker

 SYSTEM REQUIREMENTS
 Component   | Minimum    | Recommended
 ------------|------------|-------------
 CPU         | 2 cores    | 4+ cores
 RAM         | 8GB        | 16GB+
 Storage     | 30GB       | 50GB+
 Network     | 100Mbps    | Gigabit

 LICENSE
 The scripts in this repository are provided under the MIT License. 
 AzerothCore itself is licensed under AGPLv3. 
 The WoW client is property of Blizzard Entertainment and is not included.


 CONTRIBUTING
 Issues and pull requests are welcome. Ensure scripts are tested and include 
 error handling.

 SUPPORT
 For AzerothCore specific issues, refer to the official documentation.
 For Playerbots module issues, refer to the module repository.
 For Docker issues, refer to Docker documentation.
