#!/bin/bash

# Cassandra, by inflatebot
# Believe it or not, it's a TUI launcher for Aphrodite Engine.
# I'll be here all week.

# TO USER: prefer to export $APHRODITE_ENGINE, $APHRODITE_ENGINE_CONFIGS and $APHRODITE_LAUNCH_COMMAND in
# 	your bash/zshrc (or w/e shell you use) over modifying this script.
#	Cassandra will not override these settings!
# Some other environment variables you may consider setting there:
# HF_HUB_CACHE: Download location for HuggingFace models, to avoid clogging your /home directory
# HF_HUB_ENABLE_HF_TRANSFER=true: Enable faster downloading from the Hub, of particular use to RunPod users.
#	Requires hf_transfer to be installed; see https://huggingface.co/docs/huggingface_hub/en/package_reference/environment_variables#hfhubenablehftransfer
# By default, Cassandra uses the embedded micromamba runtime. But if you prefer to launch Aphrodite another way, you can do this by setting the $APHRODITE_LAUNCH_COMMAND environment variable.  By default it looks like this:
# 	APHRODITE_LAUNCH_COMMAND="$APHRODITE_ENGINE/runtime.sh aphrodite yaml $full_path"
# 	(where $full_path is derived by Cassandra, and shouldn't be forced as an environment variable.)


# Check if variables for Aphrodite Engine and its configs are in the environment, and if so, defer to them
if [ -z $APHRODITE_ENGINE ]; then
	export APHRODITE_ENGINE=$HOME/AI/text/aphrodite-engine
fi

if [ -z $APHRODITE_ENGINE_CONFIGS ]; then
	export APHRODITE_ENGINE_CONFIGS=$HOME/.cassandra/configs
fi

# See Line 79 for the launch command variable. Bash can't hoist, so this needs to be set after we determine the config path. I could make functions to set these, but I don't... want to.

# startup checks
if [ ! -f "$APHRODITE_ENGINE/runtime.sh" ]; then
	if [ ! -z $APHRODITE_LAUNCH_COMMAND ]; then
    	echo "runtime.sh was not found in $APHRODITE_ENGINE, and \$APHRODITE_LAUNCH_COMMAND is not set. cassandra can't figure out how to run Aphrodite. Run ./update-runtime.sh in Aphrodite's directory and it'll make this file. Note that currently one of the compilation steps for Aphrodite eats up an insane amount of RAM for no apparent reason (MAX_JOBS=4 caused an OOM with 32GB of system RAM); you may have to set MAX_JOBS to 1 or 2 or allocate a bunch of swap to avoid running out of memory. Both of these options are very slow. I'm sorry."
    	exit 1
	fi
	echo "You've set \$APHRODITE_LAUNCH_COMMAND to $APHRODITE_LAUNCH_COMMAND. Note that Cassandra is intended for use with Aphrodite Engine's embedded Micromamba runtime. I trust that you know what you're doing, but if you have any issues, include \"unsetting \$APHRODITE_LAUNCH_COMMAND and using the Micromamba runtime\" in your debugging steps, as I can't currently provide support for other launch methods."
	else echo "Aphrodite Micromamba runtime found."
fi

if [ ! $(which 'whiptail') ]; then
	echo "Cassandra requires Whiptail. This is stock in most distros but if you're on a server (or RunPod) you might have to install it."
	exit 1
	else echo "Whiptail found."
fi

if [ ! -d "$APHRODITE_ENGINE_CONFIGS" ]; then
	echo "Config directory not found, making one at $APHRODITE_ENGINE_CONFIGS. If this is surprising (or making the directory fails,) then check your permissions and environment variables."
	mkdir -p $APHRODITE_ENGINE_CONFIGS
else
	echo "Config directory found."
fi

# Find all .yaml files in the directory and process them directly
options=()
while IFS= read -r -d $'\0' file; do
    options+=( "$(basename "$file")" "$file" )
done < <(find "$APHRODITE_ENGINE_CONFIGS" -maxdepth 1 -type f -name "*.yaml" -print0 | sort -z)

# If no files are found (check after the loop, by checking options array)
if [ ${#options[@]} -eq 0 ]; then
    echo "No .yaml files found in '$APHRODITE_ENGINE_CONFIGS'. Copying the default config from Aphrodite."
    cp "$APHRODITE_ENGINE/config.yaml" "$APHRODITE_ENGINE_CONFIGS/default.yaml"
    # Re-run find and populate options again after copying default
    options=()
    while IFS= read -r -d $'\0' file; do
        options+=( "$(basename "$file")" "$file" )
    done < <(find "$APHRODITE_ENGINE_CONFIGS" -maxdepth 1 -type f -name "*.yaml" -print0 | sort -z)
    if [ ${#options[@]} -eq 0 ]; then # Double check after copy, just in case
        echo "Error: Still no config files found after copying default. Does $APHRODITE_ENGINE/default.yaml exist, and do we have write permissions for $APHRODITE_ENGINE_CONFIGS ?" >&2
        exit 1
    fi
fi

# Use whiptail to select a file. TODO: calculate dimensions based on terminal size
selection=$(whiptail --title "Cassandra" --menu "Select a configuration file:" 30 90 15 "${options[@]}" 3>&1 1>&2 2>&3 3>&- )

# Check if whiptail returned successfully
if [ $? -ne 0 ]; then
  echo "User cancelled or error." >&2
  exit 1
fi

# Construct full path and print to stdout
if [ -n "$selection" ]; then
  full_path="$APHRODITE_ENGINE_CONFIGS/$selection" # Selection *is* already the full path now # NO IT'S NOT, GEMINI, DUMB FU--
  echo "Config path: $full_path"
fi

# we have to do this one down here cuz bash doesn't hoist
if [ -z $APHRODITE_LAUNCH_COMMAND ]; then
    export APHRODITE_LAUNCH_COMMAND="$APHRODITE_ENGINE/runtime.sh aphrodite yaml $full_path"
fi

# Launch Aphrodite via launch command
echo "Launch command: $APHRODITE_LAUNCH_COMMAND"
exec $APHRODITE_LAUNCH_COMMAND
