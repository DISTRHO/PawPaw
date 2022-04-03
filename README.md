# PawPaw

[![Build Status](https://travis-ci.org/DISTRHO/PawPaw.png)](https://travis-ci.org/DISTRHO/PawPaw)

PawPaw is a Cross-Platform build scripts setup for static libraries and audio plugins

It was created out of the need of many open-source developers to easily build their stuff for macOS and Windows,  
where usually dependencies are involved which need to be built manually.

In order to make audio plugins self-contained, these dependencies/libraries need to be built statically,  
which most packaging projects do not do.

Also, most open-source audio plugin projects do not have binaries for macOS or Windows,  
making it very difficult for users in these platforms to enjoy them.

This project was created as a way to do automated macOS and Windows builds of such projects and libraries,  
so we can finally have a good collection of LV2 plugins on these system.  
The same automated setup can then be re-used/extended to support other projects and applications.

## Goals

PawPaw has the following goals:

 - Single script to build most common plugin dependencies statically, both natively and cross-compiling
 - Clean and simple code, easy to maintain and add new libraries to build
 - Statically build LV2 plugins for (at least) macOS and Windows
 - Define each plugin project in its own file, to make it easy to support new plugins via pull-request
 - Package the entire collection as an installer

Additionally, PawPaw is used to build library dependencies for
[Carla](https://github.com/falkTX/Carla) and
[JACK2](https://github.com/jackaudio/jack2).

## For developers

Proper documentation on how to setup PawPaw for your own project will come at a later date.  
But roughly all that is needed is something like:

```bash
# change dir to PawPaw root folder
cd /path/to/PawPaw
# build plugin dependencies for win64 target (only needed once)
./bootstrap-plugins win64
# set up environment variables for win64 builds with PawPaw static libs
source local.env win64
# change dir to your own project
cd /path/to/my/project
# build as usual
make # or whatever other build system applies
```
