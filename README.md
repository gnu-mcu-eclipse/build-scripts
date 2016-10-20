# The GNU ARM Eclipse build scripts

These are the scripts used to build the GNU ARM Eclipse tools.

The project is available from [GitHub](https://github.com/gnuarmeclipse/build-scripts).

All scripts use a common helper (`build-helper.sh`) to perform common tasks.

To use the scripts, clone the project to `Downloads` and start the desired script with `bash`.

```
$ git clone https://github.com/gnuarmeclipse/build-scripts.git ~/Downloads/build-scripts.git
$ bash ~/Downloads/build-scripts.git/scripts/build-windows-build-tools.sh --all
```

Each script will further download the project repository, libraries, and all components required to perform the build.

The scripts generate:
- a Windows setup 
- an macOS install package
- a GNU/Linux compressed archive

For more details regarding each project build, see:
- [Wndows Build Tools](http://gnuarmeclipse.github.io/windows-build-tools/build-procedure/)
- [OpenOCD](http://gnuarmeclipse.github.io/openocd/build-procedure/)
- [QEMU](http://gnuarmeclipse.github.io/qemu/build-procedure/)
