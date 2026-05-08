#!/bin/sh

# change to the directory where the script is located
dir="$0"
name=`basename "$dir"`
if [ "$name" = "$dir" ]; then
	OIFS=$IFS
	IFS=:
	for path in $PATH; do
		if [ -x "$path/$name" ]; then
			dir="$path/$name"
			break;
		fi
	done
	IFS=$OIFS
fi
while [ -L "$dir" ]; do
	dir=`readlink "$dir"`
done
cd "`dirname "$dir"`"

# Determine libs path
if [ "$(uname -m)" = "x86_64" ]; then
  libs="./libs-x86_64"
  exe="./hon-x86_64"
else
  libs="./libs-x86"
  exe="./hon-x86"
fi

# Check well known locations for libudev.so.1
for udevpath in /lib/x86_64-linux-gnu/libudev.so.1 /usr/lib64/libudev.so.1 /usr/lib/libudev.so.1 /lib/i386-linux-gnu/libudev.so.1 /lib/libudev.so.1 ; do
  if [ -f "$udevpath" ]; then
    # Map libudev.so.1 to libudev.so.0, if necessary
    ln -sf "$udevpath" $libs/libudev.so.0
    break
  fi
done

# launch the appropriate binary
exec $exe "$*"
