# The GNU ARM Eclipse build scripts

These are the scripts used to build the GNU ARM Eclipse tools.

The project is available from [GitHub](https://github.com/gnuarmeclipse/build-scripts).

All scripts use a common helper (`build-helper.sh`) to perform common tasks.

To use the scripts, get them to `Downloads` and start them with `bash`.

Each script will further download the helper script, the project repository, libraries, and all components required to perform the build.

The scripts generate:
- a Windows setup 
- an macOS install package
- a GNU/Linux compressed archive
