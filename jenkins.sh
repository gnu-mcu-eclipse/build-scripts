# Packages to build.
[ -n "${BUILDOPTS}" ] || BUILDOPTS=--all

# For standalone script outside of jenkins.
[ -n "${HOME}" ] || HOME=$(pwd)
[ -n "${WORKSPACE}" ] || WORKSPACE=$(pwd)
[ -n "${USER}" ] || USER=$(whoami)

# windows install folder blank for default.
[ -n "${win_install_folder}" ] || win_install_folder="C:\\AmbiqMicro\\OpenOCD"
# Git Development URL
[ -n "${git_dev_url}" ] || git_dev_url=ssh://git@192.168.29.73/utilities/openocd.git
# Git Release URL
[ -n "${git_rel_url}" ] || git_rel_url=ssh://git@192.168.29.73/utilities/openocd.git
# Git project (dev/rel)
[ -n "${git_project_branch}" ] || git_project_branch=gnuarmeclipse
# Git development user
[ -n "${git_dev_user}" ] || git_dev_user=${USER}
# Git development build user.
[ -n "${git_devbuild_user}" ] || git_devbuild_user=${USER}
# Location of build-scripts.
[ -n "${build_scripts_url}" ] || build_scripts_url="https://github.com/rickfoosusa/build-scripts/raw/master"

# Clean old git checkout
sudo rm -rf ${WORKSPACE}/Work/openocd/gnuarmeclipse-openocd.git

# Clean old build
sudo rm -rf ${WORKSPACE}/Work/openocd/build

# Clean old output directories.
# jenkins-slave ALL = NOPASSWD: /bin/rm -rf */output
sudo rm -rf ${WORKSPACE}/Work/openocd/output

# Script must be launched with bash.

# Launch the docker script.
# Jenkins clone is only for polling and changes.
# Work/openocd/gnuarmeclipse.git is what is built.
# Default location of Work area is HOME, for Jenkins use Workspace.
set -x
bash build-scripts/scripts/build-openocd.sh ${BUILDOPTS} \
--win-install-folder "${win_install_folder}" \
--git-dev-url "${git_dev_url}" \
--git-rel-url "${git_rel_url}" \
--git-project-branch "${git_project_branch}" \
--git-dev-user "${git_dev_user}" \
--git-devbuild-user "${git_devbuild_user}" \
--build-scripts-url "${build_scripts_url}" \
--work-folder "${WORKSPACE}" $@
