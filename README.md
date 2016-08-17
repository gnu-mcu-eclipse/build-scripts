# The GNU ARM Eclipse build scripts

These are the scripts used to build the GNU ARM Eclipse tools.

The project is available from [GitHub](https://github.com/gnuarmeclipse/build-scripts).

All scripts use a common helper (`build-helper.sh`) to perform common tasks.

To use the scripts, get them to `Downloads` and start them with `bash`.

Each script will further download the helper script, the project repository, libraries, and all components required to perform the build.

The result is a Windows setup, OS X install package, or GNU/Linux compressed archive.

The following options can be used to:
- Create multiple release/development projects.
- Allow patch releases with containing locally developed changes.
- Develop and test new features until they are ready for upstreaming.


The following options allow a gnuarmeclipse build of OpenOCD and patch releases
prior to review and approval by the main OpenOCD project. 

The --git-dev-url and --git-rel-url options allows you to switch from the sourceforge gnuarmeclipse openocd repo to a local repo for development and patch releases.

- Git Development User (user with write access to git repo)
- Git Development Build User (if the logged in user = db user, development build)
- Git Project Branch (Broject branch name for release and development)
- Git Development URL (writeable clone)
- Git Release URL (read/only clone)
- Build Scripts URL (Location of build-scripts)

