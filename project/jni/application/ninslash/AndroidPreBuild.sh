#!/bin/sh

LOCAL_PATH=`dirname $0`
LOCAL_PATH=`cd $LOCAL_PATH && pwd`

cd $LOCAL_PATH/src

[ -n "`find datasrc/*.py -cnewer src/game/generated/protocol.cpp 2>&1`" ] && {
echo "Building autogenerated files"
python --version > /dev/null 2>&1 || { echo "Error: no Python installed" ; exit 1 ; }

mkdir -p src/game/generated
python datasrc/compile.py network_source > src/game/generated/protocol.cpp
python datasrc/compile.py network_header > src/game/generated/protocol.h
python datasrc/compile.py client_content_source > src/game/generated/client_data.cpp
python datasrc/compile.py client_content_header > src/game/generated/client_data.h
python datasrc/compile.py server_content_source > src/game/generated/server_data.cpp
python datasrc/compile.py server_content_header > src/game/generated/server_data.h

python scripts/cmd5.py src/engine/shared/protocol.h src/game/generated/protocol.h src/game/tuning.h src/game/gamecore.cpp src/game/generated/protocol.h > src/game/generated/nethash.cpp
}


echo "Archiving data"
mkdir -p ../AndroidData
ln -sf ../src/logo.png ../AndroidData
rm -f ../AndroidData/data.zip
zip -r ../AndroidData/data.zip data *.txt *.cfg "example configs" >/dev/null


for ARCH in armeabi-v7a x86 arm64-v8a; do
	[ -e ../AndroidData/binaries-$ARCH.zip ] && \
		find `cat ../server-sources.txt` -cnewer ../AndroidData/binaries-$ARCH.zip | \
		[ `wc -c` -eq 0 ] && continue
	rm -rf ninslash_srv
	mkdir -p objs-srv-$ARCH bin/$ARCH
	# server-sources.txt generated by running bam server_release 2>&1 | tee build.log
	# and parsing logs with grep -o ' [^ ]*[.]cp\?p\?' build.log | grep -v /zlib/ > ../server-sources.txt
	echo "Building teeworlds_srv for $ARCH"
	env BUILD_EXECUTABLE=1 NO_SHARED_LIBS=1 ARCH=$ARCH ../../setEnvironment-$ARCH.sh \
		sh -c '
		set -x
		OBJS=
		for F in `cat ../server-sources.txt`; do
			dirname objs-srv-$ARCH/$F.o | xargs mkdir -p
			echo $F
			OBJS="$OBJS objs-srv-$ARCH/$F.o"
			$CXX $CFLAGS -fno-exceptions -fno-rtti --std=c++11 -flto -Wall -DCONF_RELEASE -I src -c $F -o objs-srv-$ARCH/$F.o || exit 1
		done
		echo Linking ninslash_srv
		$CXX $CFLAGS -fno-exceptions -fno-rtti $OBJS $LDFLAGS -pie -flto -pthread -o bin/$ARCH/ninslash_srv || exit 1
		$STRIP --strip-unneeded bin/$ARCH/ninslash_srv
		' || exit 1
	cd bin/$ARCH
	zip ../../../AndroidData/binaries-$ARCH.zip *
	cd ../..
done

ln -s -f ../src/logo.png ../AndroidData/

exit 0
