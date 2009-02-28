#!/bin/bash
set -e

NAME=plowshare
MODULES="megaupload rapidshare 2shared"
INSTALLDIR=${INSTALLDIR:-/usr/local}
LIBDIR=$INSTALLDIR/share/$NAME
BINDIR=$INSTALLDIR/bin
DOCSDIR=$INSTALLDIR/share/doc/$NAME
MODULESDIR=$LIBDIR/modules

# Uninstall
if [ "$1" = "uninstall" ]; then
    rm -vrf $LIBDIR $DOCSDIR
    rm -vf $BINDIR/{plowdown,plowup}
    exit 0
fi

# Documentation
mkdir --verbose -p $DOCSDIR
cp -v CHANGELOG COPYING README $DOCSDIR 

# Enter to source directory
cd src

# Common library 
mkdir --verbose -p $LIBDIR
cp -pv download.sh upload.sh lib.sh $LIBDIR

# Modules
mkdir -p $MODULESDIR
for MODULE in $MODULES; do
    cp -v modules/$MODULE.sh $MODULESDIR
done
mkdir -p $MODULESDIR/extras
cp -pv modules/extras/{jdownloader_captchas.db,megaupload_captcha.py,*.ttf} \
    $MODULESDIR/extras

# Binary files
mkdir --verbose -p $BINDIR 
ln -vsf $(readlink -f $LIBDIR/download.sh) $BINDIR/plowdown
ln -vsf $(readlink -f $LIBDIR/upload.sh) $BINDIR/plowup
