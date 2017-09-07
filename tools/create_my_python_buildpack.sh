#!/bin/bash
#
# Usage: ./create_my_python_buildpack.sh <buildpack-dir>
#
if [[ $1 ]]; then
	echo "Creating a new python buildpack in ${buildpack_dir}"

else
	echo "Usage: ./create_my_python_buildpack.sh <buildpack-dir>"
	exit 1
fi

buildpack_dir="$1"
bin_dir="${buildpack_dir}/bin"
resources_dir="${buildpack_dir}/resources"
modules_dir="${resources_dir}/modules"

pipzip="https://pypi.python.org/packages/11/b6/abcb525026a4be042b486df43905d6893fb04f05aac21c32c638e939e447/pip-9.0.1.tar.gz#md5=35f01da33009719497f01a4ba69d63c9"
pipurl="https://pypi.python.org/pypi/pip"
setuptoolszip="https://pypi.python.org/packages/a9/23/720c7558ba6ad3e0f5ad01e0d6ea2288b486da32f053c73e259f7c392042/setuptools-36.0.1.zip#md5=430eb106788183eefe9f444a300007f0"
setuptoolsurl="https://pypi.python.org/pypi/setuptools"

mkdir -p ${buildpack_dir}

rm -rf ${buildpack_dir}/*

mkdir -p ${buildpack_dir}/bin

mkdir -p ${buildpack_dir}/resources

mkdir -p ${buildpack_dir}/resources/modules

echo "Creating bin/detect"
cat > ${buildpack_dir}/bin/detect <<- "EOFDETECT"
#!/usr/bin/env bash

BUILD_DIR=$1

if [ ! -f $BUILD_DIR/runtime.txt ]; then
	exit 1
fi

if grep -q python- "$BUILD_DIR/runtime.txt"; then
	echo detected `cat $BUILD_DIR/runtime.txt`
	exit 0
fi

exit 1
EOFDETECT

chmod 755 ${buildpack_dir}/bin/detect

echo "Creating bin/compile"
cat > ${buildpack_dir}/bin/compile <<- "EOFCOMPILE"
#!/usr/bin/env bash

FCOMPILE=`readlink -f "$0"`
BPDIR=`dirname $FCOMPILE`
BPDIR=`readlink -f "$BPDIR/.."`
BUILD_DIR=$1
CACHE=$2

#HTTP_PROXY=proxy:8080
#export HTTPS_PROXY=http://proxy.wdf.sap.corp:8080
#export HTTP_PROXY=http://proxy.wdf.sap.corp:8080

if [ ! -f $BUILD_DIR/runtime.txt ];then
	echo
	echo BUILPACK: Abort. Cannot find runtime.txt in application directory.
	echo BUILPACK: Please provide runtime.txt with content Python-x.x.x , example Python-3.4.4
	echo
	exit 1
fi

runtime=`cat "$BUILD_DIR"/runtime.txt`
minus=`expr index "$runtime" -`

if [ "$minus" == "0" ];then
	echo "cannot understand runtime.txt"
	echo $runtime
	exit 1
fi

lang=${runtime:0:minus}
version=${runtime:minus}

echo
echo BUILDPACK: Detected language $lang
echo BUILDPACK: Detected version $version
echo

versionxx=${version%.*}
versionx=${versionxx%.*}

mkdir -p work
mkdir -p $CACHE/compiled/Python-$version

runtimedir=`readlink -f "$BUILD_DIR/.buildpack"`
mkdir -p $runtimedir
pyexe=$runtimedir/bin/python
PATH_PY=$runtimedir/lib/python$versionxx
PATH_PY=$PATH_PY:$runtimedir/lib/python$versionxx/lib-dynload
PATH_PY=$PATH_PY:$runtimedir/lib64/python$versionxx/lib-dynload
PATH_PY=$PATH_PY:$runtimedir/lib/python$versionxx/plat-linux
PATH_PY=$PATH_PY:$runtimedir/lib64/python$versionxx/plat-linux
export PYTHONPATH=$PATH_PY
export PYTHONHOME=$runtimedir


pytgz=$CACHE/compiled/Python-${version}.tar.gz
if [ ! -f $pytgz ];then
	pytgz=/tmp/Python-${version}.tar.gz
fi

if [ ! -f $pytgz ];then
	echo
	echo "BUILDPACK: Cached python build $pytgz not found"
	echo

	if [ ! -f $BPDIR/resources/python/Python-$version.tgz ];then
		echo
		echo "BUILDPACK: Downloading python source https://www.python.org/ftp/python/$version/Python-$version.tgz"
		echo
		wget -O work/Python-$version.tgz https://www.python.org/ftp/python/$version/Python-$version.tgz
		wgetexit=$?
		if [ $wgetexit -ne 0 ];then
			echo
			echo "BUILDPACK: Abort -- Python source download failed"
			echo "BUILDPACK: You can put python tar.gz in the BUILDPACK/resources/python and re-create the buildpack to avoid download from internet"
			echo
			exit $wgetexit
		fi
	else
		cp resources/python/Python-$version.tgz work
	fi

	gzip -d -f work/Python-$version.tgz
	tar -xf work/Python-$version.tar -C work
	if [ ! -f /usr/include/zlib.h ];then
		echo
		echo "BUILDPACK: Library zlib missing, not found /usr/include/zlib.h"
		echo
		d_zlib=work/Python-$version/Modules/zlib
		if [ -d $d_zlib ];then
			pushd $d_zlib
				echo
				echo "BUILDPACK: Build python provided zlib"
				echo

				./configure --prefix=$runtimedir

				make -j 8
				make install
				zmakeexit=$?
				if [ $zmakeexit -ne 0 ];then
					echo
					echo "BUILDPACK: Warning - failed to make install python provided zlib work/Python-$version/Modules/zlib"
					echo "BUILDPACK: Ignore last failure"
					echo
				fi
			popd
		else
			echo
			echo "BUILDPACK: Warning - Not found python provided zlib $d_zlib"
			echo
		fi
	fi

	pushd work/Python-$version

		echo
		echo "BUILDPACK: Installing python runtime to $runtimedir"
		echo
		./configure --prefix=$runtimedir --exec-prefix=$runtimedir   
		make -j 8
		make altinstall
		makeexit=$?
	popd

	if [ $makeexit -ne 0 ];then
		echo
		echo BUILDPACK: Abort -> Make failed in buildpack compile step
		echo
		exit $makeexit 
	fi 

	if [ ! -f $pyexe ];then
		echo
		echo BUILDPACK: cp $runtimedir/bin/python$versionxx $pyexe
		echo
		cp $runtimedir/bin/python$versionxx $pyexe
	fi

	echo
	echo BUILDPACK: PYTHONPATH=$PYTHONPATH
	echo

	echo "BUILDPACK: Yo!"
	echo "pwd:"

	pwd

	echo "BUILDPACK: Copying files from resources/modules/*.tar.gz"
	echo $BPDIR/resources/modules/*.tar.gz
	echo

	for f in $BPDIR/resources/modules/*.tar.gz
	do
		echo "  BUILDPACK: cp $f work"
		cp $f work
		fname_tar_gz=${f##*/}
		fname_tar=${fname_tar_gz%.*}
		
		echo "  BUILDPACK: Unzip"
		echo "  BUILDPACK: gzip -d -f work/$fname_tar_gz"
		gzip -d -f work/$fname_tar_gz
		echo "  BUILDPACK: Xtract"
		echo "  BUILDPACK: tar -xf work/$fname_tar -C work"
		tar -xf work/$fname_tar -C work
	done

	echo "BUILDPACK: Copying files from resources/modules/*.zip"
	echo $BPDIR/resources/modules/*.zip
	echo

	pwd

	for f in $BPDIR/resources/modules/*.zip
	do
		echo "  BUILDPACK: cp $f work"
		cp $f work
		fname_zip=${f##*/}

		echo "  BUILDPACK: Unzip"
		pushd work
		echo "  BUILDPACK: unzip -q -u $fname_zip"
		unzip -q -u $fname_zip
		popd
	done

	echo "BUILDPACK: Build setuptools"
	pwd

	pushd work/setuptools*
		echo "BUILDPACK: $pyexe setup.py build install"
		$pyexe setup.py build install
		setupexit=$?
		if [ $setupexit -ne 0 ];then
			echo
			echo "BUILDPACK: Abort --> Failed to install python module setuptools"
			echo
			exit $setupexit
		fi   
	popd

	echo "BUILDPACK: Build pip"

	pushd work/pip*
		echo "BUILDPACK: $pyexe setup.py build install"
		$pyexe setup.py build install
		setupexit=$?
		if [ $setupexit -ne 0 ];then
			echo
			echo "BUILDPACK: WARNING --> Ignored:Failed to install python module pip"
			echo
		fi
	popd

	tar -cf $CACHE/compiled/Python-$version.tar -C $runtimedir .
	gzip $CACHE/compiled/Python-$version.tar

	echo
	echo BUILDPACK: Cached python build $CACHE/compiled/Python-$version.tar.gz
	echo
	cp $CACHE/compiled/Python-$version.tar.gz /tmp/Python-$version.tar.gz
else
	echo
	echo "BUILDPACK: Cached python build found $pytgz"
	echo
	cp $pytgz work
	gzip -d -f work/Python-$version.tar.gz
	tar -xf work/Python-$version.tar -C $runtimedir    
fi

echo
echo "BUILDPACK: Python executable $pyexe"
echo `"$pyexe" --version`
echo

moduleinstall=0
if [ -f $BUILD_DIR/requirements.txt ];then
	echo
	echo BUILDPACK: Try to execute python -m pip install -r r$BUILD_DIR/requirements.txt
	echo
	$pyexe -m pip install -r $BUILD_DIR/requirements.txt
	moduleinstall=$?
fi

if [ $moduleinstall -ne 0 ] && [ -d $BUILD_DIR/vendor ];then
	echo
	echo "BUILDPACK: Install app vendor packages using pip"
	echo $pyexe -m pip install $BUILD_DIR/vendor/*
	echo
	$pyexe -m pip install $BUILD_DIR/vendor/*
	moduleinstall=$?

	if [ $moduleinstall -ne 0 ];then
		echo
		echo "BUILDPACK: Install app vendor tar.gz packages without pip"
		echo

		for f in $BUILD_DIR/vendor/*.tar.gz
		do
			if [ -f $f ];then
				echo
				echo "BUILDPACK: Installing vendor package $f"
				echo
				cp $f work
				fname_tar_gz=${f##*/}
				fname_tar=${fname_tar_gz%.*}
				fname=${fname_tar%.*}

				gzip -d -f work/$fname_tar_gz

				tar -xf work/$fname_tar -C work
				pushd work/$fname
					$pyexe setup.py build install
				popd
			fi
		done
	fi
fi
EOFCOMPILE

chmod 755 ${buildpack_dir}/bin/compile

echo "Creating bin/release"
cat > ${buildpack_dir}/bin/release <<- "EOFRELEASE"
#!/usr/bin/env bash

set -e

BUILD_DIR=$1

FRELEASE=`readlink -f "$0"`
BPDIR=`dirname $FRELEASE`
BPDIR=`readlink -f "$BPDIR/.."`

mkdir -p $BUILD_DIR/.profile.d
cp $BPDIR/resources/env.sh $BUILD_DIR/.profile.d

echo "---"
##echo "config_vars:"
##echo "  PYTHONHOME: $HOME/.buildpack"
echo "default_process_types:"
echo "  web: .buildpack/bin/python server.py"
EOFRELEASE

chmod 755 ${buildpack_dir}/bin/release

echo "Creating resources/env.sh"
cat > ${buildpack_dir}/resources/env.sh <<- "EOFENVSH"
#!/usr/bin/env bash

FENV=`readlink -f "$0"`
DDROPLET=`dirname $FENV`


echo env.sh
echo user `whoami`
echo dir `pwd`
export PYTHONHOME=$DDROPLET/app/.buildpack

PYLIB=$(echo $DDROPLET/app/.buildpack/lib/python*/)
PYLIB64=$(echo $DDROPLET/app/.buildpack/lib64/python*/)

export PYTHONPATH=$PYLIB/:$PYLIB/lib-dynload:$PYLIB64/:$PYLIB64/lib-dynload

echo PYTHONHOME=$PYTHONHOME
echo PYTHONPATH=$PYTHONPATH
EOFENVSH

echo "Creating VERSION file"
cat > ${buildpack_dir}/VERSION <<- "EOFVERSION"
0.0.1
EOFVERSION

echo "Creating README file"
cat > ${buildpack_dir}/README.md <<- "EOFREADMEMD"
# sap_python_buildpack
Very thin and simple buildpack, implemented completely in BASH. Can work both in offline and online mode.

# How it works
* Detect : checks if the app folder contains file runtime.txt containing runtime specification python-<python version>  
* Tries to find python sources \<\<buildpack\>\>/resources/python/Python-$version.tgz
* If not found, downloads https://www.python.org/ftp/python/$version/Python-$version.tgz
* Compiles python sources
* Install python modules \<\<buildpack\>\>/resources/modules/*.tar.gz
* Caches python build to cache folder
* Tries to install dependencies described in \<\<app folder\>\>/requirements.txt using pip
* If it fails, tries to install modules from \<\<app folder\>\>/vendor 

# Offline mode 
This buildpack can work in offline mode i.e. with no internet connection.
All supported python runtimes must be provided as .tgz files in buildpack folder/resources/python folder. So you basically git clone this buildpack, then you download the supported python versions in the resources/python folder and then create the buildpack in CF or in XS

# Online mode
In this case no changes are required to this buildpack, the python version will be downloaded in the compile phase.

# Application prerequisites
Expected files in app folder:
* server.py 
* runtime.txt with sample content "python-3.4.4" or "python-3.5.5"

`cat 'python-3.4.4' >runtime.txt`
* Offline mode: vendor folder containing all dependent modules

Sample commands to download modules:

`python -m pip download -d \<\<app folder\>\>/vendor pyhdb`

`python -m pip install -d \<\<app folder\>\>/vendor -r \<\<app folder\>\>/requirements.txt`
* Online mode: requirements.txt in the app folder


# Limitations
* Hardcoded sap corporate proxy (Removed by Andrew Lunde I830671 for public Internet use.)
* Tested on OS: Ubuntu, Suse linux
* Tested with python versions: 3.4.4  3.5.0
EOFREADMEMD

cd ${buildpack_dir}/resources/modules

echo "Getting...PIP from $pipurl"

wget ${pipzip}

echo "Done..."

echo "Getting...setuptools from $setuptoolsurl"

wget ${setuptoolszip}

echo "Done..."

cd ../..

echo "Finished creating a new python buildpack in ${buildpack_dir}\n"
echo ""
echo "Install the buildpack with: (use an unused position number if 99 is occupied)"
echo ""
echo "xs create-buildpack my_python_buildpack ${buildpack_dir} 99"
echo ""
