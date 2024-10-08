#!/bin/bash
# Default variables
function="install"
# Options
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
        case "$1" in
        -in|--install)
            function="install"
            shift
            ;;
        -up|--update)
            function="update"
            shift
            ;;
        -un|--uninstall)
            function="uninstall"
            shift
            ;;
        *|--)
    break
	;;
	esac
done
install() {
#docker install
cd $HOME
. <(wget -qO- https://raw.githubusercontent.com/mgpwnz/VS/main/docker.sh)
#create dir and config
if [ ! -d $HOME/chasm ]; then
  mkdir $HOME/chasm
fi
sleep 1

function check_empty {
  local varname=$1
  while [ -z "${!varname}" ]; do
    read -p "$2" input
    if [ -n "$input" ]; then
      eval $varname=\"$input\"
    else
      echo "The value cannot be empty. Please try again."
    fi
  done
}

function confirm_input {
  echo "You have entered the following information:"
  echo "Node Name: $NAME"
  echo "Scout UID: $SID"
  echo "WEBHOOK_API_KEY: $WAK"
  echo "Groq API: $GAPI"
  echo "Openrouter API: $ORAPI"
  echo "OpenAI API: $OPENAI"
  
  read -p "Is this information correct? (yes/no): " CONFIRM
  CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  
  if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    echo "Let's try again..."
    return 1 
  fi
  return 0 
}

while true; do
  NAME=""
  SID=""
  WAK=""
  GAPI=""
  ORAPI=""
  OPENAI=""
  
  check_empty NAME "Enter node NAME: "
  check_empty SID "Scout UID: "
  check_empty WAK "WEBHOOK_API_KEY: "
  check_empty GAPI "Groq API: "
  check_empty ORAPI "Openrouter API: "
  check_empty OPENAI "OpenAI API: "
  
  confirm_input
  if [ $? -eq 0 ]; then
    break 
  fi
done

echo "All data is confirmed. Proceeding..."

# Create script 
tee $HOME/chasm/docker-compose.yml > /dev/null <<EOF
version: "3.7"
name: chasm

services:
  node:
    image: chasmtech/chasm-scout:latest
    restart: always
    env_file:
      - ./.env
    ports:
    - '3004:3004'
networks:
  default:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.100.0/24

EOF
#env
tee $HOME/chasm/.env > /dev/null <<EOF
PORT=3004
LOGGER_LEVEL=debug

# Chasm
ORCHESTRATOR_URL=https://orchestrator.chasm.net
SCOUT_NAME=$NAME
SCOUT_UID=$SID
WEBHOOK_API_KEY=$WAK
# Scout Webhook Url, update based on your server's IP and Port
# e.g. http://123.123.123.123:3001/
WEBHOOK_URL=http://`wget -qO- eth0.me`:3004/

# Chosen Provider (groq, openai)
PROVIDERS=groq
MODEL=gemma2-9b-it
GROQ_API_KEY=$GAPI

# Optional
OPENROUTER_API_KEY=$ORAPI
OPENAI_API_KEY=$OPENAI

EOF
#Run nnode
docker compose -f $HOME/chasm/docker-compose.yml up -d
}
update() {
docker compose -f $HOME/chasm/docker-compose.yml down
docker compose -f $HOME/chasm/docker-compose.yml pull
docker compose -f $HOME/chasm/docker-compose.yml up -d
docker logs -f chasm-node-1

}
uninstall() {
if [ ! -d "$HOME/chasm" ]; then
    echo "Directory not found"
    break
fi

read -r -p "Wipe all DATA? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        docker-compose -f "$HOME/chasm/docker-compose.yml" down -v
        rm -rf "$HOME/chasm"
        echo "Data wiped"
        ;;
    *)
        echo "Canceled"
        break
        ;;
esac
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function