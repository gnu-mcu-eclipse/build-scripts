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
- Develop and test new build-scripts.

The following command line options are used to override the defaults:
- Git Development User (user with write access to git repo)
- Git Development Build User (if the logged in user = db user, development build)
- Git Project Branch (Broject branch name for release and development)
- Git Development URL (writeable clone)
- Git Release URL (read/only clone)
- Build Scripts URL (Location of build-scripts)
- Work Folder (User specified Work Folder location)
