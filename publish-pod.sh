#!/bin/sh

if [ $# -lt 1 ]; then
	echo "Usage: sh publish-pod.sh [version]"
	exit;
fi;

PODSPEC=./*.podspec

pod lib lint --allow-warnings
if [ $? -ne 0 ]; then
	echo "Library did not pass lint. Please fix before publishing."
	exit
fi;

VERSION=$1

sed -i '.bak' "s/\(\s*spec\.version\)\([[:space:]]*\=[[:space:]]*\)\"\(.*\)\"/\1\2\"$VERSION\"/" $PODSPEC

git add -u $PODSPEC

git commit -m "Bump version to $VERSION"
git push

git tag $VERSION
TAG_SUCCESS=$?

if [ $TAG_SUCCESS -ne 0 ]; then
	echo "Specified version already exists"
	exit
fi;

git push --tags

pod trunk push $PODSPEC --allow-warnings
