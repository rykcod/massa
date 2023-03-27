#!/bin/bash

MASSA_PACKAGE="massa_${VERSION}_release_linux.tar.gz"
MASSA_PACKAGE_ARM64="massa_${VERSION}_release_linux_arm64.tar.gz"
MASSA_PACKAGE_LOCATION="https://github.com/massalabs/massa/releases/download/$VERSION/"

if [ "$TARGETARCH" == "amd64" ]; then
	TARBALL=$MASSA_PACKAGE
else
	TARBALL=$MASSA_PACKAGE_ARM64
fi

# Download the package
curl -Ls -o $TARBALL $MASSA_PACKAGE_LOCATION/$TARBALL

# Extract the package's content
tar -zxpf $TARBALL
mv /massa /massa-$VERSION
ln -s /massa-$VERSION /massa

# Delete the package
rm $TARBALL
