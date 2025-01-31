#!/bin/bash

# Cassandra, by inflatebot
# Believe it or not, it's a TUI launcher for Aphrodite Engine. 
# I'll be here all week.
# Intended for use with installations based on the embedded micromamba runtime.

# TO USER: prefer to export $APHRODITE_ENGINE and $APHRODITE_ENGINE_CONFIGS in
# 	your bash/zshrc (or w/e shell you use) over modifying this script.
#	Cassandra will not override these settings!
# Some other environment variables you may consider setting there:
# HF_HUB_CACHE: Download location for HuggingFace models, to avoid clogging your /home directory
# HF_HUB_ENABLE_HF_TRANSFER=true: Enable faster downloading from the Hub, of particular use to RunPod users.
#	Requires hf_transfer to be installed; see https://huggingface.co/docs/huggingface_hub/en/package_reference/environment_variables#hfhubenablehftransfer

# Check if variables for Aphrodite Engine and its configs are in the environment, and if so, defer to them
if [ -z $APHRODITE_ENGINE ]; then
	export APHRODITE_ENGINE=$HOME/AI/text/aphrodite-engine
fi

if [ -z $APHRODITE_ENGINE_CONFIGS ]; then
	export APHRODITE_ENGINE_CONFIGS=$HOME/.cassandra/configs
fi

# startup checks
if [ ! -f "$APHRODITE_ENGINE/runtime.sh" ]; then
	echo "Cassandra couldn't find the runtime.sh script for Aphrodite's embedded micromamba runtime at $aphrodite . \n Currently, Cassandra only works with the embedded micromamba runtime."
	exit 1
	else echo "Aphrodite Micromamba runtime found."
fi

if [ ! $(which 'whiptail') ]; then
	echo "Cassandra requires Whiptail. This is stock in most distros but if you're on a server (or RunPod) you might have to install it."
	exit 1
	else echo "Whiptail found."
fi

if [ ! -d "$APHRODITE_ENGINE_CONFIGS" ]; then
	echo "Config directory not found, making one. If this is surprising, (or making the directory fails) then check your permissions."
	mkdir -p $APHRODITE_ENGINE_CONFIGS
else
	echo "Config directory found."
fi

# Find all .yaml files in the directory
getfiles () { files=$(find "$APHRODITE_ENGINE_CONFIGS" -maxdepth 1 -type f -name "*.yaml" -print0 | sort -z | xargs -0 -n 1 basename 2>/dev/null); }
getfiles

# If no files are found, grab the default from Aphrodite
if [ -z "$files" ]; then
    echo "No .yaml files found in '$APHRODITE_ENGINE_CONFIGS'. Copying the default config from Aphrodite."
    cp "$APHRODITE_ENGINE/config.yaml" "$APHRODITE_ENGINE_CONFIGS/default.yaml"
    getfiles
fi

# Prepare arguments for whiptail
options=()
while IFS= read -r -d $'\0' file; do
	options+=( "$(basename "$file")" "" )
done < <(printf '%s\0' "$files")

# Use whiptail to select a file
selection=$(whiptail --title "Cassandra" --menu "Select a configuration file:" 30 60 15 "${options[@]}" 3>&1 1>&2 2>&3 3>&- )

# Check if whiptail returned successfully
if [ $? -ne 0 ]; then
  echo "User cancelled or error." >&2
  exit 1
fi

# Construct full path and print to stdout
if [ -n "$selection" ]; then
  full_path="$APHRODITE_ENGINE_CONFIGS/$selection"
  echo "$full_path"
fi

# Launch Aphrodite via micromamba runtime
exec $APHRODITE_ENGINE/runtime.sh aphrodite yaml $full_path
