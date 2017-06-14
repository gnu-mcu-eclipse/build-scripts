#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is -x.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

# Script to build the GNU MCU Eclipse RISC-V GCC distribution packages.
#
# Developed on OS X 10.12 Sierra.
# Also tested on:
#   GNU/Linux Arch (Manjaro 16.08)
#
# The Windows and GNU/Linux packages are build using Docker containers.
# The build is structured in 2 steps, one running on the host machine
# and one running inside the Docker container.
#
# At first run, Docker will download/build 3 relatively large
# images (1-2GB) from Docker Hub.
#
# Prerequisites:
#
#   Docker
#   curl, git, automake, patch, tar, unzip, zip
#
# When running on OS X, a custom Homebrew is required to provide the 
# missing libraries and TeX binaries.
#

# Mandatory definition.
APP_NAME="RISC-V Embedded GCC"

# Used as part of file/folder paths.
APP_UC_NAME="GNU RISC-V Embedded GCC"
APP_LC_NAME="riscv-eabi-gcc"

# On Parallels virtual machines, prefer host Work folder.
# Second choice are Work folders on secondary disks.
# Final choice is a Work folder in HOME.
if [ -d /media/psf/Home/Work ]
then
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"/media/psf/Home/Work/${APP_LC_NAME}"}
elif [ -d /media/${USER}/Work ]
then
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"/media/${USER}/Work/${APP_LC_NAME}"}
elif [ -d /media/Work ]
then
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"/media/Work/${APP_LC_NAME}"}
else
  # Final choice, a Work folder in HOME.
  WORK_FOLDER_PATH=${WORK_FOLDER_PATH:-"${HOME}/Work/${APP_LC_NAME}"}
fi

BUILD_FOLDER="${WORK_FOLDER_PATH}/build"

PROJECT_GIT_FOLDER_NAME="riscv-gcc-build.git"
PROJECT_GIT_FOLDER_PATH="${WORK_FOLDER_PATH}/${PROJECT_GIT_FOLDER_NAME}"
PROEJCT_GIT_URL="https://github.com/gnu-mcu-eclipse/${PROJECT_GIT_FOLDER_NAME}"

# ----- Create Work folder. -----

echo
echo "Work folder: \"${WORK_FOLDER_PATH}\"."

mkdir -p "${WORK_FOLDER_PATH}"

# ----- Parse actions and command line options. -----

ACTION=""
DO_BUILD_WIN32=""
DO_BUILD_WIN64=""
DO_BUILD_DEB32=""
DO_BUILD_DEB64=""
DO_BUILD_OSX=""
helper_script_path=""
do_no_strip=""

while [ $# -gt 0 ]
do
  case "$1" in

    clean|cleanall|pull|checkout-dev|checkout-stable|build-images|preload-images|bootstrap)
      ACTION="$1"
      shift
      ;;

    --win32|--window32)
      DO_BUILD_WIN32="y"
      shift
      ;;
    --win64|--windows64)
      DO_BUILD_WIN64="y"
      shift
      ;;
    --deb32|--debian32)
      DO_BUILD_DEB32="y"
      shift
      ;;
    --deb64|--debian64)
      DO_BUILD_DEB64="y"
      shift
      ;;
    --osx)
      DO_BUILD_OSX="y"
      shift
      ;;

    --all)
      DO_BUILD_WIN32="y"
      DO_BUILD_WIN64="y"
      DO_BUILD_DEB32="y"
      DO_BUILD_DEB64="y"
      DO_BUILD_OSX="y"
      shift
      ;;

    --helper-script)
      helper_script_path=$2
      shift 2
      ;;

    --no-strip)
      do_no_strip="y"
      shift
      ;;

    --help)
      echo "Build the GNU MCU Eclipse ${APP_NAME} distributions."
      echo "Usage:"
      echo "    bash $0 helper_script [--win32] [--win64] [--deb32] [--deb64] [--osx] [--all] [clean|cleanall|pull|checkout-dev|checkout-stable|build-images] [--help]"
      echo
      exit 1
      ;;

    *)
      echo "Unknown action/option $1"
      exit 1
      ;;
  esac

done

# ----- Prepare build scripts. -----

build_script=$0
if [[ "${build_script}" != /* ]]
then
  # Make relative path absolute.
  build_script=$(pwd)/$0
fi

# Copy the current script to Work area, to later copy it into the install folder.
mkdir -p "${WORK_FOLDER_PATH}/scripts"
cp "${build_script}" "${WORK_FOLDER_PATH}/scripts/build-${APP_LC_NAME}.sh"

# ----- Build helper. -----

if [ -z "${helper_script_path}" ]
then
  script_folder_path="$(dirname ${build_script})"
  script_folder_name="$(basename ${script_folder_path})"
  if [ \( "${script_folder_name}" == "scripts" \) \
    -a \( -f "${script_folder_path}/build-helper.sh" \) ]
  then
    helper_script_path="${script_folder_path}/build-helper.sh"
  elif [ ! -f "${WORK_FOLDER_PATH}/scripts/build-helper.sh" ]
  then
    # Download helper script from GitHub git.
    echo "Downloading helper script..."
    curl -L "https://github.com/gnu-mcu-eclipse/build-scripts/raw/master/scripts/build-helper.sh" \
      --output "${WORK_FOLDER_PATH}/scripts/build-helper.sh"
    helper_script_path="${WORK_FOLDER_PATH}/scripts/build-helper.sh"
  else
    helper_script_path="${WORK_FOLDER_PATH}/scripts/build-helper.sh"
  fi
else
  if [[ "${helper_script_path}" != /* ]]
  then
    # Make relative path absolute.
    helper_script_path="$(pwd)/${helper_script_path}"
  fi
fi

# Copy the current helper script to Work area, to later copy it into the install folder.
mkdir -p "${WORK_FOLDER_PATH}/scripts"
if [ "${helper_script_path}" != "${WORK_FOLDER_PATH}/scripts/build-helper.sh" ]
then
  cp "${helper_script_path}" "${WORK_FOLDER_PATH}/scripts/build-helper.sh"
fi

echo "Helper script: \"${helper_script_path}\"."
source "${helper_script_path}"

# ----- Libraries sources. -----

# For updates, please check the corresponding pages.

GCC_FOLDER_NAME="gcc.git"
GCC_GIT_URL="https://github.com/gnu-mcu-eclipse/riscv-gcc.git"
GCC_GIT_BRANCH="riscv-next"
GCC_GIT_COMMIT="HEAD"

BINUTILS_FOLDER_NAME="binutils.git"
BINUTILS_GIT_URL="https://github.com/gnu-mcu-eclipse/riscv-binutils-gdb.git"
BINUTILS_GIT_BRANCH="riscv-next"
BINUTILS_GIT_COMMIT="3f21b5c9675db61ef5462442b6a068d4a3da8aaf"

NEWLIB_FOLDER_NAME="newlib.git"
NEWLIB_GIT_URL="https://github.com/gnu-mcu-eclipse/riscv-newlib.git"
NEWLIB_GIT_BRANCH="riscv-newlib-2.5.0"
NEWLIB_GIT_COMMIT="HEAD"

# ----- Define build constants. -----

DOWNLOAD_FOLDER="${WORK_FOLDER_PATH}/download"

# ----- Process actions. -----

if [ \( "${ACTION}" == "clean" \) -o \( "${ACTION}" == "cleanall" \) ]
then
  # Remove most build and temporary folders.
  echo
  if [ "${ACTION}" == "cleanall" ]
  then
    echo "Remove all the build folders..."
  else
    echo "Remove most of the build folders (except output)..."
  fi

  rm -rf "${BUILD_FOLDER}"
  rm -rf "${WORK_FOLDER_PATH}/install"

  rm -rf "${WORK_FOLDER_PATH}/scripts"

  if [ "${ACTION}" == "cleanall" ]
  then
    rm -rf "${PROJECT_GIT_FOLDER_PATH}"
    rm -rf "${WORK_FOLDER_PATH}/output"
  fi

  echo
  echo "Clean completed. Proceed with a regular build."

  exit 0
fi

# ----- Start build. -----

do_host_start_timer

do_host_detect

# ----- Prepare prerequisites. -----

do_host_prepare_prerequisites_riscv

# ----- Process "preload-images" action. -----

if [ "${ACTION}" == "preload-images" ]
then
  do_host_prepare_docker

  echo
  echo "Check/Preload Docker images..."

  echo
  docker run --interactive --tty ilegeul/debian32:8-gnuarm-gcc-x11-v3 \
  lsb_release --description --short

  echo
  docker run --interactive --tty ilegeul/debian:8-gnuarm-gcc-x11-v3 \
  lsb_release --description --short

  echo
  docker run --interactive --tty ilegeul/debian:8-gnuarm-mingw \
  lsb_release --description --short

  echo
  docker images

  do_host_stop_timer

  exit 0
fi

do_host_bootstrap() {

  return

  # Prepare autotools.
  echo
  echo "bootstrap..."

  cd "${PROJECT_GIT_FOLDER_PATH}"
  rm -f aclocal.m4
  ./bootstrap

}

if [ \( "${ACTION}" == "bootstrap" \) ]
then

  do_host_bootstrap

  do_host_stop_timer

  exit 0

fi

# ----- Process "build-images" action. -----

if [ "${ACTION}" == "build-images" ]
then
  do_host_prepare_docker

  # Remove most build and temporary folders.
  echo
  echo "Build Docker images..."

  # Be sure it will not crash on errors, in case the images are already there.
  set +e

  docker build --tag "ilegeul/debian32:8-gnuarm-gcc-x11-v3" \
  https://github.com/ilg-ul/docker/raw/master/debian32/8-gnuarm-gcc-x11-v3/Dockerfile

  docker build --tag "ilegeul/debian:8-gnuarm-gcc-x11-v3" \
  https://github.com/ilg-ul/docker/raw/master/debian/8-gnuarm-gcc-x11-v3/Dockerfile

  docker build --tag "ilegeul/debian:8-gnuarm-mingw" \
  https://github.com/ilg-ul/docker/raw/master/debian/8-gnuarm-mingw/Dockerfile

  docker images

  do_host_stop_timer

  exit 0
fi

# ----- Prepare Docker, if needed. -----

if [ -n "${DO_BUILD_WIN32}${DO_BUILD_WIN64}${DO_BUILD_DEB32}${DO_BUILD_DEB64}" ]
then
  do_host_prepare_docker
fi

# ----- Check some more prerequisites. -----

if false
then

echo
echo "Checking host automake..."
automake --version 2>/dev/null | grep automake

echo
echo "Checking host patch..."
patch --version | grep patch

fi

echo
echo "Checking host tar..."
tar --version

echo
echo "Checking host unzip..."
unzip | grep UnZip

if false
then

echo
echo "Checking host makeinfo..."
makeinfo --version | grep 'GNU texinfo'
makeinfo_ver=$(makeinfo --version | grep 'GNU texinfo' | sed -e 's/.*) //' -e 's/\..*//')
if [ "${makeinfo_ver}" -lt "6" ]
then
  echo "makeinfo too old, abort."
  exit 1
fi

if which libtoolize > /dev/null; then
    libtoolize="libtoolize"
elif which glibtoolize >/dev/null; then
    libtoolize="glibtoolize"
else
    echo "$0: Error: libtool is required" >&2
    exit 1
fi

fi

# ----- Get the GNU MCU Eclipse RISC-V GCC git repository. -----

# The custom RISC-V GCC branch is available from the dedicated Git repository
# which is part of the GNU MCU Eclipse project hosted on GitHub.
# Generally this branch follows the official RISC-V GCC master branch,
# with updates after every RISC-V GCC public release.

if [ ! -d "${PROJECT_GIT_FOLDER_PATH}" ]
then

  cd "${WORK_FOLDER_PATH}"

  echo "If asked, enter ${USER} GitHub password for git clone"
  git clone "${PROEJCT_GIT_URL}" "${PROJECT_GIT_FOLDER_PATH}"

  # do_host_bootstrap

fi

# ----- Process "pull|checkout-dev|checkout-stable" actions. -----

do_repo_action() {

  # $1 = action (pull, checkout-dev, checkout-stable)

  # Update current branch and prepare autotools.
  echo
  if [ "${ACTION}" == "pull" ]
  then
    echo "Running git pull..."
  elif [ "${ACTION}" == "checkout-dev" ]
  then
    echo "Running git checkout gnu-mcu-eclipse-dev & pull..."
  elif [ "${ACTION}" == "checkout-stable" ]
  then
    echo "Running git checkout gnu-mcu-eclipse & pull..."
  fi

  if [ -d "${PROJECT_GIT_FOLDER_PATH}" ]
  then
    echo
    if [ "${USER}" == "ilg" ]
    then
      echo "If asked, enter ${USER} GitHub password for git pull"
    fi

    cd "${PROJECT_GIT_FOLDER_PATH}"

    if [ "${ACTION}" == "checkout-dev" ]
    then
      git checkout gnu-mcu-eclipse-dev
    elif [ "${ACTION}" == "checkout-stable" ]
    then
      git checkout gnu-mcu-eclipse
    fi

    if false
    then

    git pull --recurse-submodules
    git submodule update --init --recursive --remote

    git branch

    do_host_bootstrap

    rm -rf "${BUILD_FOLDER}/${APP_LC_NAME}"

    echo
    if [ "${ACTION}" == "pull" ]
    then
      echo "Pull completed. Proceed with a regular build."
    else
      echo "Checkout completed. Proceed with a regular build."
    fi

    else

      echo "Not implemented."
      exit 1
      
    fi

    exit 0
  else
	echo "No git folder."
    exit 1
  fi

}

# For this to work, the following settings are required:
# git branch --set-upstream-to=origin/gnu-mcu-eclipse-dev gnu-mcu-eclipse-dev
# git branch --set-upstream-to=origin/gnu-mcu-eclipse gnu-mcu-eclipse

case "${ACTION}" in
  pull|checkout-dev|checkout-stable)
    do_repo_action "${ACTION}"
    ;;
esac

# Get the current Git branch name, to know if we are building the stable or
# the development release.
do_host_get_git_head

# ----- Get current date. -----

# Use the UTC date as version in the name of the distribution file.
do_host_get_current_date

# ----- Get BINUTILS & GDB. -----

if [ ! -d "${WORK_FOLDER_PATH}/${BINUTILS_FOLDER_NAME}" ]
then
  cd "${WORK_FOLDER_PATH}"
  echo "Cloning \'${BINUTILS_GIT_URL}\'..."
  git clone --branch "${BINUTILS_GIT_BRANCH}" "${BINUTILS_GIT_URL}" "${BINUTILS_FOLDER_NAME}"
  cd "${BINUTILS_FOLDER_NAME}"
  git checkout -qf "${BINUTILS_GIT_COMMIT}"
fi

# ----- Get GCC. -----

if [ ! -d "${WORK_FOLDER_PATH}/${GCC_FOLDER_NAME}" ]
then
  cd "${WORK_FOLDER_PATH}"
  echo "Cloning \'${GCC_GIT_URL}\'..."
  git clone --branch "${GCC_GIT_BRANCH}" "${GCC_GIT_URL}" "${GCC_FOLDER_NAME}"
  cd "${GCC_FOLDER_NAME}"
  git checkout -qf "${GCC_GIT_COMMIT}"
fi

# ----- Get NEWLIB. -----

if [ ! -d "${WORK_FOLDER_PATH}/${NEWLIB_FOLDER_NAME}" ]
then
  cd "${WORK_FOLDER_PATH}"
  echo "Cloning \'${NEWLIB_GIT_URL}\'..."
  git clone --branch "${NEWLIB_GIT_BRANCH}" "${NEWLIB_GIT_URL}" "${NEWLIB_FOLDER_NAME}"
  cd "${NEWLIB_FOLDER_NAME}"
  git checkout -qf "${NEWLIB_GIT_COMMIT}"
fi

# v===========================================================================v
# Create the build script (needs to be separate for Docker).

script_name="build.sh"
script_file="${WORK_FOLDER_PATH}/scripts/${script_name}"

rm -f "${script_file}"
mkdir -p "$(dirname ${script_file})"
touch "${script_file}"

# Note: EOF is quoted to prevent substitutions here.
cat <<'EOF' >> "${script_file}"
#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set -x # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

EOF
# The above marker must start in the first column.

# Note: EOF is not quoted to allow local substitutions.
cat <<EOF >> "${script_file}"

APP_NAME="${APP_NAME}"
APP_LC_NAME="${APP_LC_NAME}"
APP_UC_NAME="${APP_UC_NAME}"
GIT_HEAD="${GIT_HEAD}"
DISTRIBUTION_FILE_DATE="${DISTRIBUTION_FILE_DATE}"
PROJECT_GIT_FOLDER_NAME="${PROJECT_GIT_FOLDER_NAME}"
BINUTILS_FOLDER_NAME="${BINUTILS_FOLDER_NAME}"
GCC_FOLDER_NAME="${GCC_FOLDER_NAME}"
NEWLIB_FOLDER_NAME="${NEWLIB_FOLDER_NAME}"

do_no_strip="${do_no_strip}"

EOF
# The above marker must start in the first column.

# Propagate DEBUG to guest.
set +u
if [[ ! -z ${DEBUG} ]]
then
  echo "DEBUG=${DEBUG}" "${script_file}"
  echo
fi
set -u

# Note: EOF is quoted to prevent substitutions here.
cat <<'EOF' >> "${script_file}"

PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-""}

# For just in case.
export LC_ALL="C"
export CONFIG_SHELL="/bin/bash"

script_name="$(basename "$0")"
args="$@"
docker_container_name=""

while [ $# -gt 0 ]
do
  case "$1" in
    --build-folder)
      build_folder_path="$2"
      shift 2
      ;;
    --docker-container-name)
      docker_container_name="$2"
      shift 2
      ;;
    --target-name)
      target_name="$2"
      shift 2
      ;;
    --target-bits)
      target_bits="$2"
      shift 2
      ;;
    --work-folder)
      work_folder_path="$2"
      shift 2
      ;;
    --output-folder)
      output_folder_path="$2"
      shift 2
      ;;
    --distribution-folder)
      distribution_folder="$2"
      shift 2
      ;;
    --install-folder)
      install_folder="$2"
      shift 2
      ;;
    --download-folder)
      download_folder="$2"
      shift 2
      ;;
    --helper-script)
      helper_script_path="$2"
      shift 2
      ;;
    --group-id)
      group_id="$2"
      shift 2
      ;;
    --user-id)
      user_id="$2"
      shift 2
      ;;
    --host-uname)
      host_uname="$2"
      shift 2
      ;;
    *)
      echo "Unknown option $1, exit."
      exit 1
  esac
done

git_folder_path="${work_folder_path}/${PROJECT_GIT_FOLDER_NAME}"

echo
uname -a

# Run the helper script in this shell, to get the support functions.
source "${helper_script_path}"

target_folder=${target_name}${target_bits:-""}

if [ "${target_name}" == "win" ]
then

  # For Windows targets, decide which cross toolchain to use.
  if [ ${target_bits} == "32" ]
  then
    cross_compile_prefix="i686-w64-mingw32"
  elif [ ${target_bits} == "64" ]
  then
    cross_compile_prefix="x86_64-w64-mingw32"
  fi

elif [ "${target_name}" == "osx" ]
then

  target_bits="64"

fi

mkdir -p ${build_folder_path}
cd ${build_folder_path}

# ----- Test if various tools are present -----

if false
then

echo
echo "Checking automake..."
automake --version 2>/dev/null | grep automake

echo "Checking cmake..."
cmake --version | grep cmake

echo "Checking pkg-config..."
pkg-config --version

fi

if [ "${target_name}" != "osx" ]
then
  echo "Checking readelf..."
  readelf --version | grep readelf
fi

if [ "${target_name}" == "win" ]
then
  echo "Checking ${cross_compile_prefix}-gcc..."
  ${cross_compile_prefix}-gcc --version 2>/dev/null | egrep -e 'gcc|clang'

  echo "Checking unix2dos..."
  unix2dos --version 2>&1 | grep unix2dos

  echo "Checking makensis..."
  echo "makensis $(makensis -VERSION)"

  apt-get --yes install zip

  echo "Checking zip..."
  zip -v | grep "This is Zip"
else
  echo "Checking gcc..."
  gcc --version 2>/dev/null | egrep -e 'gcc|clang'
fi

if [ "${target_name}" == "debian" ]
then
  echo "Checking patchelf..."
  patchelf --version
fi

echo "Checking shasum..."
shasum --version

# ----- Remove and recreate the output folder. -----

rm -rf "${output_folder_path}"
mkdir -p "${output_folder_path}"

# ----- Build BINUTILS. -----

binutils_folder="binutils"
binutils_stamp_file="${build_folder_path}/${binutils_folder}/stamp-install-completed"

gcc_target="riscv64-unknown-elf"

if [ ! -f "${binutils_stamp_file}" ]
then

  rm -rfv "${build_folder_path}/${binutils_folder}"
  mkdir -p "${build_folder_path}/${binutils_folder}"

  echo
  echo "Running configure binutils..."

  cd "${build_folder_path}/${binutils_folder}"

  mkdir -p "${install_folder}/${APP_LC_NAME}"

  if [ "${target_name}" == "win" ]
  then
    
    CFLAGS="-Wno-unknown-warning-option -Wno-extended-offsetof -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers -Wno-implicit-function-declaration -Wno-parentheses -Wno-format-nonliteral -Wno-shift-count-overflow -Wno-constant-logical-operand -Wno-shift-negative-value -Wno-format -m${target_bits} -pipe" \
    CXXFLAGS="-Wno-format-nonliteral -Wno-format-security -Wno-deprecated -Wno-unknown-warning-option -Wno-c++11-narrowing -m${target_bits} -pipe" \
    "${work_folder_path}/${BINUTILS_FOLDER_NAME}/configure" \
      --host="${cross_compile_prefix}" \
      --prefix="${install_folder}/${APP_LC_NAME}" \
      --target="${gcc_target}" \
      --disable-werror \
      --disable-build-warnings \
      --disable-gdb-build-warnings \
      --without-system-zlib \
    | tee "configure-output.txt"

  elif [ "${target_name}" == "osx" ]
  then

    CFLAGS="-Wno-unknown-warning-option -Wno-extended-offsetof -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers -Wno-implicit-function-declaration -Wno-parentheses -Wno-format-nonliteral -Wno-shift-count-overflow -Wno-constant-logical-operand -Wno-shift-negative-value -Wno-format -m${target_bits} -pipe" \
    CXXFLAGS="-Wno-format-nonliteral -Wno-format-security -Wno-deprecated -Wno-unknown-warning-option -Wno-c++11-narrowing -m${target_bits} -pipe" \
    "${work_folder_path}/${BINUTILS_FOLDER_NAME}/configure" \
      --prefix="${install_folder}/${APP_LC_NAME}" \
      --target="${gcc_target}" \
      --disable-werror \
      --disable-build-warnings \
      --disable-gdb-build-warnings \
      --without-system-zlib \
    | tee "configure-output.txt"

  elif [ "${target_name}" == "debian" ]
  then

    CFLAGS="-Wno-unknown-warning-option -Wno-extended-offsetof -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers -Wno-implicit-function-declaration -Wno-parentheses -Wno-format-nonliteral -Wno-shift-count-overflow -Wno-constant-logical-operand -Wno-shift-negative-value -Wno-format -m${target_bits} -pipe" \
    CXXFLAGS="-Wno-format-nonliteral -Wno-format-security -Wno-deprecated -Wno-unknown-warning-option -Wno-c++11-narrowing -m${target_bits} -pipe" \
    "${work_folder_path}/${BINUTILS_FOLDER_NAME}/configure" \
      --prefix="${install_folder}/${APP_LC_NAME}" \
      --target="${gcc_target}" \
      --disable-werror \
      --disable-build-warnings \
      --disable-gdb-build-warnings \
      --without-system-zlib \
    | tee "configure-output.txt"

  fi

  echo
  echo "Running make binutils..."
  make clean
  make -j 6
  make install
  touch "${binutils_stamp_file}"

fi

# ----- Build GCC. -----

gcc_folder="gcc"
newlib_folder="newlib"

if false
then

if [ ! -f "${build_folder_path}/${APP_LC_NAME}/config.h" ]
then

  echo
  echo "Running configure RISC-V GCC..."

  if [ "${target_name}" == "win" ]
  then

    cd "${build_folder_path}/openocd"

    # --enable-minidriver-dummy -> configure error
    # --enable-buspirate -> not supported on mingw
    # --enable-zy1000 -> netinet/tcp.h: No such file or directory
    # --enable-sysfsgpio -> available only on Linux

    # --enable-openjtag_ftdi -> --enable-openjtag
    # --enable-presto_libftdi -> --enable-presto
    # --enable-usb_blaster_libftdi -> --enable-usb_blaster

    # All variables below are passed on the command line before 'configure'.
    # Be sure all these lines end in '\' to ensure lines are concatenated.
    OUTPUT_DIR="${build_folder_path}" \
    \
    CPPFLAGS="-Werror -m${target_bits} -pipe" \
    PKG_CONFIG="${git_folder_path}/gnu-mcu-eclipse/scripts/cross-pkg-config" \
    PKG_CONFIG_LIBDIR="${install_folder}/lib/pkgconfig" \
    PKG_CONFIG_PREFIX="${install_folder}" \
    \
    bash "${git_folder_path}/configure" \
    --build="$(uname -m)-linux-gnu" \
    --host="${cross_compile_prefix}" \
    --prefix="${install_folder}/openocd"  \
    --datarootdir="${install_folder}" \
    --infodir="${install_folder}/${APP_LC_NAME}/info"  \
    --localedir="${install_folder}/${APP_LC_NAME}/locale"  \
    --mandir="${install_folder}/${APP_LC_NAME}/man"  \
    --docdir="${install_folder}/${APP_LC_NAME}/doc"  \
    --disable-wextra \
    --disable-werror \
    --enable-dependency-tracking \
    \
    --enable-branding="GNU MCU Eclipse" \
    \
    --enable-aice \
    --enable-amtjtagaccel \
    --enable-armjtagew \
    --enable-at91rm9200 \
    --enable-bcm2835gpio \
    --disable-buspirate \
    --enable-cmsis-dap \
    --enable-dummy \
    --enable-ep93xx \
    --enable-ftdi \
    --enable-gw16012 \
    --disable-ioutil \
    --enable-jlink \
    --enable-jtag_vpi \
    --disable-minidriver-dummy \
    --disable-oocd_trace \
    --enable-opendous \
    --enable-openjtag \
    --enable-osbdm \
    --enable-parport \
    --disable-parport-ppdev \
    --enable-parport-giveio \
    --enable-presto \
    --enable-remote-bitbang \
    --enable-riscv \
    --enable-rlink \
    --enable-stlink \
    --disable-sysfsgpio \
    --enable-ti-icdi \
    --enable-ulink \
    --enable-usb_blaster \
    --enable-usb-blaster-2 \
    --enable-usbprog \
    --enable-vsllink \
    --disable-zy1000-master \
    --disable-zy1000 \
    | tee "${output_folder_path}/configure-output.txt"
    # Note: don't forget to update the INFO.txt file after changing these.

  elif [ "${target_name}" == "debian" ]
  then

    LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-""}

    cd "${build_folder_path}/openocd"

    # --enable-minidriver-dummy -> configure error

    # --enable-openjtag_ftdi -> --enable-openjtag
    # --enable-presto_libftdi -> --enable-presto
    # --enable-usb_blaster_libftdi -> --enable-usb_blaster

    # All variables below are passed on the command line before 'configure'.
    # Be sure all these lines end in '\' to ensure lines are concatenated.
    # On some machines libftdi ends in lib64, so we refer both lib & lib64
    CPPFLAGS="-m${target_bits} -pipe" \
    LDFLAGS='-Wl,-lpthread' \
    \
    PKG_CONFIG_LIBDIR="${install_folder}/lib/pkgconfig":"${install_folder}/lib64/pkgconfig" \
    \
    LD_LIBRARY_PATH="${install_folder}/lib":"${install_folder}/lib64":"${LD_LIBRARY_PATH}" \
    \
    bash "${git_folder_path}/configure" \
    --prefix="${install_folder}/openocd"  \
    --datarootdir="${install_folder}" \
    --infodir="${install_folder}/${APP_LC_NAME}/info"  \
    --localedir="${install_folder}/${APP_LC_NAME}/locale"  \
    --mandir="${install_folder}/${APP_LC_NAME}/man"  \
    --docdir="${install_folder}/${APP_LC_NAME}/doc"  \
    --disable-wextra \
    --disable-werror \
    --enable-dependency-tracking \
    \
    --enable-branding="GNU MCU Eclipse" \
    \
    --enable-aice \
    --enable-amtjtagaccel \
    --enable-armjtagew \
    --enable-at91rm9200 \
    --enable-bcm2835gpio \
    --enable-buspirate \
    --enable-cmsis-dap \
    --enable-dummy \
    --enable-ep93xx \
    --enable-ftdi \
    --enable-gw16012 \
    --disable-ioutil \
    --enable-jlink \
    --enable-jtag_vpi \
    --disable-minidriver-dummy \
    --disable-oocd_trace \
    --enable-opendous \
    --enable-openjtag \
    --enable-osbdm \
    --enable-parport \
    --disable-parport-ppdev \
    --enable-parport-giveio \
    --enable-presto \
    --enable-remote-bitbang \
    --enable-riscv \
    --enable-rlink \
    --enable-stlink \
    --enable-sysfsgpio \
    --enable-ti-icdi \
    --enable-ulink \
    --enable-usb_blaster \
    --enable-usb-blaster-2 \
    --enable-usbprog \
    --enable-vsllink \
    --disable-zy1000-master \
    --disable-zy1000 \
    | tee "${output_folder_path}/configure-output.txt"
    # Note: don't forget to update the INFO.txt file after changing these.

  elif [ "${target_name}" == "osx" ]
  then

    DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH:-""}

    cd "${build_folder_path}/${APP_LC_NAME}"

    # All variables below are passed on the command line before 'configure'.
    # Be sure all these lines end in '\' to ensure lines are concatenated.
    CPPFLAGS="-Werror -m${target_bits} -pipe" \
    \
    PKG_CONFIG_LIBDIR="${install_folder}/lib/pkgconfig":"${install_folder}/lib64/pkgconfig" \
    \
    DYLD_LIBRARY_PATH="${install_folder}/lib":"${DYLD_LIBRARY_PATH}" \
    \
    bash "${git_folder_path}/configure" \
    --prefix="${install_folder}/${APP_LC_NAME}"  \
    \
    | tee "${output_folder_path}/configure-output.txt"
    # Note: don't forget to update the INFO.txt file after changing these.

  fi

fi

fi


# ----- Full build, with documentation. -----

if false
then

if [ ! \( -f "${build_folder_path}/${APP_LC_NAME}/src/openocd" \) -a \
     ! \( -f "${build_folder_path}/${APP_LC_NAME}/src/openocd.exe" \) ]
then

  # The bindir and pkgdatadir are required to configure bin and scripts folders
  # at the same level in the hierarchy.

  echo
  echo "Running make all..."

  cd "${build_folder_path}/${APP_LC_NAME}"
  make bindir="bin" pkgdatadir="" all pdf html \
  | tee "${output_folder_path}/make-all-output.txt"

fi

# ----- Full install, including documentation. -----

echo
echo "Running make install..."

rm -rf "${install_folder}/${APP_LC_NAME}"
mkdir -p "${install_folder}/${APP_LC_NAME}"

cd "${build_folder_path}/${APP_LC_NAME}"

make install install-pdf install-html install-man \
| tee "${output_folder_path}/make-install-output.txt"

fi

# ----- Copy dynamic libraries to the install bin folder. -----

if [ "${target_name}" == "win" ]
then

  if [ -z "${do_no_strip}" ]
  then
    ${cross_compile_prefix}-strip \
      "${install_folder}/${APP_LC_NAME}/bin"/*.exe
  fi

  echo
  echo "Copying DLLs..."

  # Identify the current cross gcc version, to locate the specific dll folder.
  CROSS_GCC_VERSION=$(${cross_compile_prefix}-gcc --version | grep 'gcc' | sed -e 's/.*\s\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\).*/\1.\2.\3/')
  CROSS_GCC_VERSION_SHORT=$(echo $CROSS_GCC_VERSION | sed -e 's/\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\).*/\1.\2/')
  SUBLOCATION="-win32"

  echo "${CROSS_GCC_VERSION}" "${CROSS_GCC_VERSION_SHORT}" "${SUBLOCATION}"

  if [ "${target_bits}" == "32" ]
  then
    do_container_win_copy_gcc_dll "libgcc_s_sjlj-1.dll"
  elif [ "${target_bits}" == "64" ]
  then
    do_container_win_copy_gcc_dll "libgcc_s_seh-1.dll"
  fi

  do_container_win_copy_libwinpthread_dll

  if [ -z "${do_no_strip}" ]
  then
    ${cross_compile_prefix}-strip "${install_folder}/${APP_LC_NAME}/bin/"*.dll
  fi

elif [ "${target_name}" == "debian" ]
then

  if [ -z "${do_no_strip}" ]
  then
    strip "${install_folder}/${APP_LC_NAME}/bin"/*
  fi

  # This is a very important detail: 'patchelf' sets "runpath"
  # in the ELF file to $ORIGIN, telling the loader to search
  # for the libraries first in LD_LIBRARY_PATH (if set) and, if not found there,
  # to look in the same folder where the executable is located -- where
  # this build script installs the required libraries. 
  # Note: LD_LIBRARY_PATH can be set by a developer when testing alternate 
  # versions of the openocd libraries without removing or overwriting 
  # the installed library files -- not done by the typical user. 
  # Note: patchelf changes the original "rpath" in the executable (a path 
  # in the docker container) to "runpath" with the value "$ORIGIN". rpath 
  # instead or runpath could be set to $ORIGIN but rpath is searched before
  # LD_LIBRARY_PATH which requires an installed library be deleted or
  # overwritten to test or use an alternate version. In addition, the usage of
  # rpath is deprecated. See man ld.so for more info.  
  # Also, runpath is added to the installed library files using patchelf, with 
  # value $ORIGIN, in the same way. See patchelf usage in build-helper.sh.
  #
  find "${install_folder}/${APP_LC_NAME}/bin" -type f -executable \
    -exec patchelf --debug --set-rpath '$ORIGIN' "{}" \;

  echo
  echo "Copying shared libs..."

  if [ "${target_bits}" == "64" ]
  then
    distro_machine="x86_64"
  elif [ "${target_bits}" == "32" ]
  then
    distro_machine="i386"
  fi

if false
then

  do_container_linux_copy_user_so libusb-1.0
  do_container_linux_copy_user_so libusb-0.1
  do_container_linux_copy_user_so libftdi1
  do_container_linux_copy_user_so libhidapi-hidraw

  do_container_linux_copy_system_so libudev
  do_container_linux_copy_librt_so

fi

elif [ "${target_name}" == "osx" ]
then

  if [ -z "${do_no_strip}" ]
  then
    strip "${install_folder}/${APP_LC_NAME}/bin"/*
  fi

  echo
  echo "Copying dynamic libs..."

  # Post-process dynamic libraries paths to be relative to executable folder.

  # ILIB=openocd
  otool -L "${install_folder}/${APP_LC_NAME}/bin/riscv64-unknown-elf-gdb"

if false
then

  install_name_tool -change "libftdi1.2.dylib" "@executable_path/libftdi1.2.dylib" \
    "${install_folder}/${APP_LC_NAME}/bin/openocd"
  do_container_mac_change_built_lib libusb-1.0.0.dylib
  do_container_mac_change_built_lib libusb-0.1.4.dylib
  do_container_mac_change_built_lib libhidapi.0.dylib
  do_container_mac_check_lib

  do_container_mac_copy_built_lib libftdi1.2.dylib
  do_container_mac_change_built_lib libusb-1.0.0.dylib
  do_container_mac_check_lib

  do_container_mac_copy_built_lib libusb-0.1.4.dylib
  do_container_mac_change_built_lib libusb-1.0.0.dylib
  do_container_mac_check_lib

  do_container_mac_copy_built_lib libusb-1.0.0.dylib
  do_container_mac_check_lib

  do_container_mac_copy_built_lib libhidapi.0.dylib
  do_container_mac_check_lib

fi

fi

# ----- Copy the license files. -----

echo
echo "Copying license files..."

do_container_copy_license "${work_folder_path}/${BINUTILS_FOLDER_NAME}" "${binutils_folder}"
do_container_copy_license "${work_folder_path}/${GCC_FOLDER_NAME}" "${gcc_folder}"
do_container_copy_license "${work_folder_path}/${NEWLIB_FOLDER_NAME}" "${newlib_folder}"

if [ "${target_name}" == "win" ]
then
  # For Windows, process cr lf
  find "${install_folder}/${APP_LC_NAME}/license" -type f \
    -exec unix2dos {} \;
fi

# ----- Copy the GNU MCU Eclipse info files. -----

do_container_copy_info

/usr/bin/install -cv -m 644 \
  "${build_folder_path}/${binutils_folder}/configure-output.txt" \
  "${install_folder}/${APP_LC_NAME}/gnu-mcu-eclipse/binutils-configure-output.txt"
do_unix2dos "${install_folder}/${APP_LC_NAME}/gnu-mcu-eclipse/binutils-configure-output.txt"

# ----- Create the distribution package. -----

mkdir -p "${output_folder_path}"

distribution_file_version=$(cat "${git_folder_path}/gnu-mcu-eclipse/VERSION")-${DISTRIBUTION_FILE_DATE}

distribution_executable_name="riscv64-unknown-elf-gdb"

do_container_create_distribution

# Requires ${distribution_file} and ${result}
do_container_completed

exit 0

EOF
# The above marker must start in the first column.
# ^===========================================================================^


# ----- Build the OS X distribution. -----

if [ "${HOST_UNAME}" == "Darwin" ]
then
  if [ "${DO_BUILD_OSX}" == "y" ]
  then
    do_host_build_target "Creating OS X package..." \
      --target-name osx
  fi
fi

# ----- Build the Windows 64-bits distribution. -----

if [ "${DO_BUILD_WIN64}" == "y" ]
then
  do_host_build_target "Creating Windows 64-bits setup..." \
    --target-name win \
    --target-bits 64 \
    --docker-image "ilegeul/debian:8-gnuarm-mingw-v2"
fi

# ----- Build the Windows 32-bits distribution. -----

if [ "${DO_BUILD_WIN32}" == "y" ]
then
  do_host_build_target "Creating Windows 32-bits setup..." \
    --target-name win \
    --target-bits 32 \
    --docker-image "ilegeul/debian:8-gnuarm-mingw-v2"
fi

# ----- Build the Debian 64-bits distribution. -----

if [ "${DO_BUILD_DEB64}" == "y" ]
then
  do_host_build_target "Creating Debian 64-bits archive..." \
    --target-name debian \
    --target-bits 64 \
    --docker-image "ilegeul/debian:8-gnuarm-gcc-x11-v4"
fi

# ----- Build the Debian 32-bits distribution. -----

if [ "${DO_BUILD_DEB32}" == "y" ]
then
  do_host_build_target "Creating Debian 32-bits archive..." \
    --target-name debian \
    --target-bits 32 \
    --docker-image "ilegeul/debian32:8-gnuarm-gcc-x11-v4"
fi

do_host_show_sha

do_host_stop_timer

# ----- Done. -----
exit 0
