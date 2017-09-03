Aurora for Linux
================

This script is intended to ease the life of [Aurora](http://aurora2.pentarch.org/) players under linux.

To install Aurora, use the *install* action.
This will automatically build a Wine prefix in this script directory and install all needed
dependencies.
Make sure you don't miss console message displayed in green that will guide you on which action you
need to perform on the various install gui windows that will pop out.

```bash-session
$ ./aurora.sh install
```

Then, to start Aurora

```bash-session
$ ./aurora.sh start
```

And to get a list of available action, use

```bash-session
$ ./aurora.sh help
Usage: aurora.sh ACTION

Available actions are:
  install         build a new installation of aurora
  start           start aurora
  winecfg         open winecfg for the aurora wine prefix
  help            display this

```
