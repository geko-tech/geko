DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "$1" ]; then
  response=$(curl -sS -f https://api.github.com/repos/geko-tech/geko/releases/latest 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "❌ Unable to get latest tag from GitHub."
    echo "👉 Pass the tag manually: ./install.sh Geko@1.0.0"
    exit 1
  fi

  TAG=$(echo "$response" | jq -r '.tag_name')
  if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
    echo "❌ GitHub returned an invalid response."
    echo "👉 Pass the tag manually: ./install.sh Geko@1.0.0"
    exit 1
  fi
else
  TAG="$1"
fi

echo "ℹ️ Installing geko version $TAG"

USER_DIR="$HOME"
ZSHRC_FILE="$USER_DIR/.zshrc"
GEKO_DESTINATION_DIR="$USER_DIR/.geko/bin"
# create and check if tmp dir was created
TEMP_DIR=$(mktemp -d -p "$DIR") || {
    echo "❌ Could not create temp dir"
    exit
}

# deletes the temp directory
function cleanup {      
  rm -rf "$TEMP_DIR"
  echo "✅ Deleted temp working directory $TEMP_DIR"
}

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT

# clean folder before installation 
while true; do
	read -p "⚠️ Geko will be installed into dir $GEKO_DESTINATION_DIR. Before install directory will be cleared. Continue? [y] [n]" yn < /dev/tty
	case $yn in
		[Yy]* ) rm -rf "$GEKO_DESTINATION_DIR"; break;;
		[Nn]* ) exit;;
		* ) echo "Answer should be 'y' or 'n'";;
	esac
done

# download geko to temp dir
curl --output "$TEMP_DIR/geko.zip" -L "https://github.com/geko-tech/geko/releases/download/$TAG/geko_macos.zip"

# Unarhive geko.zip
cd "$TEMP_DIR"
unzip "geko.zip"

# Copy into dir
mkdir -p "$GEKO_DESTINATION_DIR"
cp -R geko ProjectDescription.framework geko_source.json Templates "$GEKO_DESTINATION_DIR"

cd "$DIR"

# Add geko path inside zshrc
GEKO_ZSHRC_LINE="export PATH=$GEKO_DESTINATION_DIR:\$PATH"
echo "ℹ️ Add geko path into PATH variable inside $ZSHRC_FILE"
if grep -Fxq "$GEKO_ZSHRC_LINE" "$ZSHRC_FILE"
then
  echo "⚠️ Geko path already exist inside $ZSHRC_FILE"
  echo "✅ Ready"
else
  echo "$GEKO_ZSHRC_LINE" >> "$ZSHRC_FILE"
  echo "✅ Ready"
fi
