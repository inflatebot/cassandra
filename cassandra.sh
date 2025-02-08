#!/bin/bash

# Cassandra, by inflatebot
# Believe it or not, it's a TUI launcher for Aphrodite Engine.
# I'll be here all week.

# TO USER: prefer to export $APHRODITE_ENGINE, $APHRODITE_ENGINE_CONFIGS and
# (optionally) $APHRODITE_LAUNCH_COMMAND in your bashrc
# (or equivalent environment script) over modifying this file.
# Cassandra will not override these variables!!
#
# By default, Cassandra uses the embedded micromamba runtime. But if you prefer
# to launch Aphrodite another way, you can do this by setting
# the $APHRODITE_LAUNCH_COMMAND environment variable.

# We defer to exported environment variables if present.
if [ -z $APHRODITE_ENGINE ]; then
	export APHRODITE_ENGINE=$HOME/AI/text/aphrodite-engine
fi

if [ -z $APHRODITE_ENGINE_CONFIGS ]; then
	export APHRODITE_ENGINE_CONFIGS=$HOME/.cassandra/configs
fi

if [ -z $APHRODITE_LAUNCH_COMMAND ]; then
	export APHRODITE_LAUNCH_COMMAND="$APHRODITE_ENGINE/runtime.sh aphrodite yaml"
fi

# startup checks

if [ ! $(which 'whiptail') ]; then
	echo "ERROR: Cassandra requires Whiptail. This is stock in most distros but if you're on a server (or RunPod) you might have to install it.\n(hint for RunPod users: \`unminimize\`)"
	exit 1
	else echo "INFO: Whiptail is installed."
fi

if [ ! -f "$APHRODITE_ENGINE/runtime.sh" ]; then
	if [ ! -z $APHRODITE_LAUNCH_COMMAND ]; then
		echo "ERROR: runtime.sh was not found in $APHRODITE_ENGINE, and \$APHRODITE_LAUNCH_COMMAND is not set.\ncassandra can't figure out how to run Aphrodite.\nEither set \$APHRODITE_LAUNCH_COMMAND, or see the page below for information on setting up the Micromamba runtime (and heed the warning about RAM; you probably don't have enough.) \nhttps://aphrodite.pygmalion.chat/pages/installation/installation.html#building-from-source"
		exit 1
	fi
	echo "WARN: You've set \$APHRODITE_LAUNCH_COMMAND to $APHRODITE_LAUNCH_COMMAND.\nNote that cassandra is intended for use with Aphrodite Engine's embedded Micromamba runtime. I trust that you know what you're doing, but if you have any issues, include \"unsetting \$APHRODITE_LAUNCH_COMMAND and using the Micromamba runtime\" in your debugging steps."
	else echo "INFO: Using embedded Micromamba runtime found at $APHRODITE_ENGINE"
fi

if [ ! -d "$APHRODITE_ENGINE_CONFIGS" ]; then
	echo "WARN: Config directory not found, making one at $APHRODITE_ENGINE_CONFIGS. If this is surprising (or making the directory fails,) then check your permissions and environment variables."
	mkdir -p $APHRODITE_ENGINE_CONFIGS
	else echo "INFO: Config directory found at $APHRODITE_ENGINE_CONFIGS"
fi

# Find all .yaml files in the directory and process them directly
options=()
while IFS= read -r -d $'\0' file; do
	options+=( "$(basename "$file")" "$file" )
done < <(find "$APHRODITE_ENGINE_CONFIGS" -maxdepth 1 -type f -name "*.yaml" -print0 | sort -z)

# If no files are found (check after the loop, by checking options array)
if [ ${#options[@]} -eq 0 ]; then
	echo "WARN: No .yaml files found in '$APHRODITE_ENGINE_CONFIGS'. Copying the default config from Aphrodite."
	cp "$APHRODITE_ENGINE/config.yaml" "$APHRODITE_ENGINE_CONFIGS/default.yaml"
	# Re-run find and populate options again after copying default
	options=()
	while IFS= read -r -d $'\0' file; do
		options+=( "$(basename "$file")" "$file" )
	done < <(find "$APHRODITE_ENGINE_CONFIGS" -maxdepth 1 -type f -name "*.yaml" -print0 | sort -z)
	if [ ${#options[@]} -eq 0 ]; then # Double check after copy, just in case
		echo "ERROR: Still no config files found after copying default. Does $APHRODITE_ENGINE/default.yaml exist, and do we have write permissions for $APHRODITE_ENGINE_CONFIGS ?" >&2
		exit 1
	fi
fi

# Use whiptail to select a file. TODO: calculate dimensions based on terminal size
selection=$(whiptail --title "Cassandra" --menu "Select a configuration file:" 30 80 15 "${options[@]}" 3>&1 1>&2 2>&3 3>&- )

# Check if whiptail returned successfully
if [ $? -ne 0 ]; then
	echo "ERROR: Either user cancelled, or Whiptail returned an error." >&2
	exit 1
fi

# Construct full path and print to stdout
if [ -n "$selection" ]; then
	full_path="$APHRODITE_ENGINE_CONFIGS/$selection" # Selection *is* already the full path now # NO IT'S NOT, GEMINI, DUMB FU--
	echo "INFO: $selection found at $full_path"
fi

# Launch Aphrodite via launch command
echo "INFO: Full launch command: $APHRODITE_LAUNCH_COMMAND"
exec $APHRODITE_LAUNCH_COMMAND $full_path
