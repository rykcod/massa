#!/bin/bash

MASSA_PACKAGE="massa_${VERSION}_release_linux.tar.gz"
MASSA_PACKAGE_ARM64="massa_${VERSION}_release_linux_arm64.tar.gz"
MASSA_PACKAGE_LOCATION="https://github.com/massalabs/massa/releases/download/$VERSION/"

package=""

if [[ $TARGETPLATFORM =~ linux/arm* ]]; then
	package=$MASSA_PACKAGE_ARM64
else
	package=$MASSA_PACKAGE
fi

# Download the package
wget "$MASSA_PACKAGE_LOCATION/$package"

# Extract the package's content
tar -zxpf "$package"
sed -i 's/retry_delay = 60000/retry_delay = 15000/' massa/massa-node/base_config/config.toml        #Change bootstrap retry delay to 10s (default 60s)
mv /massa /massa-"$VERSION"
ln -s /massa-"$VERSION" /massa

# Delete the package
rm "$package"
