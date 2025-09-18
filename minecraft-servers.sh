#!/bin/bash

# ==================================
# Multi-server Minecraft launcher with save/backup + stop-one & restart-one
# ==================================

# Define servers: "name:path_to_run_script:world_dir"
SERVERS=(
  "minecraft-paper:/home/gui/Minecraft/Paper/run.sh:/home/gui/Minecraft/Paper/world"
  "minecraft-bmc5:/home/gui/Minecraft/BMC5_Server_Pack_v39/start.sh:/home/gui/Minecraft/BMC5_Server_Pack_v39/world"
)

# Send a Minecraft server command (shell input) to the screen session
send_mc_command() {
  local screen_name=$1
  local cmd=$2
  screen -S "$screen_name" -p 0 -X stuff "$cmd$(printf \\r)"
}

# Check if a screen session is running
is_running() {
  local name=$1
  screen -list | grep -q "\.${name}[[:space:]]"
}

start_server() {
  local name=$1 script=$2

  local dir
  dir=$(dirname "$script")
  cd "$dir" || { echo "Could not enter $dir"; return 1; }

  if is_running "$name"; then
    echo "❌ Server '$name' already running."
  else
    [ -x "$script" ] || chmod +x "$script"
    echo "▶️ Starting server '$name'..."
    screen -dmS "$name" "$script"
  fi
}

stop_server() {
  local name=$1

  if is_running "$name"; then
    echo "⚠️ Saving and stopping server '$name'..."
    send_mc_command "$name" "save-all"
    sleep 2
    send_mc_command "$name" "stop"
  else
    echo "❗ Server '$name' is not running."
  fi
}

save_server() {
  local name=$1

  if is_running "$name"; then
    echo "💾 Saving server '$name'..."
    send_mc_command "$name" "save-all"
  else
    echo "❗ Server '$name' is not running."
  fi
}

backup_server() {
  local name=$1 world_dir=$2

  local script=""
  for entry in "${SERVERS[@]}"; do
    IFS=":" read -r n s w <<< "$entry"
    if [ "$n" = "$name" ]; then
      script="$s"
      break
    fi
  done
  if [ -z "$script" ]; then
    echo "❗ Unknown server '$name'"
    return 1
  fi

  if ! is_running "$name"; then
    echo "❗ Server '$name' is not running — cannot backup safely."
    return 1
  fi

  echo "⚠️ Preparing backup for '$name'..."
  send_mc_command "$name" "say Backing up world — saving now. Please wait..."
  send_mc_command "$name" "save-off"
  send_mc_command "$name" "save-all"
  sleep 2

  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_PATH="$world_dir/../${name}_backup_$TIMESTAMP.tar.gz"
  echo "📦 Backing up world from $world_dir to $BACKUP_PATH"
  tar -czf "$BACKUP_PATH" -C "$(dirname "$world_dir")" "$(basename "$world_dir")"

  sleep 1
  send_mc_command "$name" "save-on"
  send_mc_command "$name" "say Backup complete."
  echo "✅ Backup for '$name' complete."
}

list_servers() {
  echo "Configured servers:"
  for entry in "${SERVERS[@]}"; do
    IFS=":" read -r name path world <<< "$entry"
    local status="stopped"
    if is_running "$name"; then status="running"; fi
    echo " - $name : $path : world=$world [${status}]"
  done
}

# MAIN

case "$1" in
  start)
    for entry in "${SERVERS[@]}"; do
      IFS=":" read -r name path world <<< "$entry"
      start_server "$name" "$path"
    done
    ;;
  stop)
    for entry in "${SERVERS[@]}"; do
      IFS=":" read -r name path world <<< "$entry"
      stop_server "$name"
    done
    ;;
  restart)
    for entry in "${SERVERS[@]}"; do
      IFS=":" read -r name path world <<< "$entry"
      stop_server "$name"
      sleep 2
      start_server "$name" "$path"
    done
    ;;
  start-one)
    shift
    for entry in "${SERVERS[@]}"; do
      IFS=":" read -r name path world <<< "$entry"
      if [ "$name" = "$1" ]; then
        start_server "$name" "$path"
      fi
    done
    ;;
  stop-one)
    shift
    for entry in "${SERVERS[@]}"; do
      IFS=":" read -r name path world <<< "$entry"
      if [ "$name" = "$1" ]; then
        stop_server "$name"
      fi
    done
    ;;
  restart-one)
    shift
    for entry in "${SERVERS[@]}"; do
      IFS=":" read -r name path world <<< "$entry"
      if [ "$name" = "$1" ]; then
        stop_server "$name"
        sleep 2
        start_server "$name" "$path"
      fi
    done
    ;;
  save)
    shift
    save_server "$1"
    ;;
  backup)
    shift
    backup_server "$1"
    ;;
  list)
    list_servers
    ;;
  *)
    echo "Usage: $0 {list|start|stop|restart|start-one SERVER_NAME|stop-one SERVER_NAME|restart-one SERVER_NAME|save SERVER_NAME|backup SERVER_NAME}"
    ;;
esac
