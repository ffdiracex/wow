#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#enter cloned repository (NOTE: please clone into ~, else change the scripts)
cd ~/wow/azerothcore-wotlk 2>/dev/null || {
  echo "ERROR: cannot find ~/wow/azerothcore-wotlk"
  exit 1
}

echo -e "\n"
echo -e "${BLUE}azerothcore server status${NC}"

for container in ac-database ac-authserver ac-worldserver; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    UPTIME=$(docker inspect -f '{{.State.StartedAt}}' "$container" 2>/dev/null | cut -d'T' -f1 | tr -d '"')
    echo -e " ${GREEN}*${NC} $container: ${GREEN}running${NC} (since $UPTIME}"
  elif docker ps -a  --format '{{.Names}}' | grep -q "^${container}$"; then
    echo -e " ${YELLOW}*${NC} $container: ${YELLOW}stopped${NC}"
  else
    echo -e " ${RED}X${NC} $container: ${RED}not found${NC}"
  fi
done

echo -e "\n"

#Get server address
IP_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127' | head -1)

if [ -n "$IP_ADDRESS" ]; then
  echo  -e "${GREEN}Server IP for client realmlist.wtf:${NC} $IP_ADDRESS"
else
  echo -e "${RED}Couldn't detect IP address${NC}"
fi

echo -e "\n"

#check the database for realmlist entries
if docker ps --format '{{.Names}}' | grep -q "^ac-database$"; then
  DB_ADDRESS=$(docker exec ac-database mysql -uroot -ppassword -e "SELECT address FROM acore_auth.realmlist;" 2>/dev/null | tail -1)
  if [ -n "$DB_ADDRESS" ]; then
    echo -e "${BLUE}database realmlist address:${NC} $DB_ADDRESS"
    if [ "$DB_ADDRESS" != "$IP_ADDRESS" ] && [ "$DB_ADDRESS" != "0.0.0.0" ]; then
      echo -e "${YELLOW}warning: database address differs from detected IP address${NC}"
    fi
  fi
fi

echo -e "\n"

