# PawPaw

[![Build Status](https://travis-ci.org/DISTRHO/PawPaw.png)](https://travis-ci.org/DISTRHO/PawPaw)

PawPaw is a Cross-Platform build scripts setup for static libraries and audio plugins

It was created out of the need of many open-source developers to easily build their stuff for macOS and Windows,  
where usually dependencies are involved which need to be built manually.

In order to make audio plugins self-contained, these dependencies/libraries need to be built statically,  
which most packaging projects do not do.

Also, most open-source audio plugin projects do not have binaries for macOS or Windows,  
making it very difficult for users in these platforms to enjoy them.

PawPaw has the following goals:

 - Single script to build most common plugin dependencies statically, both natively and cross-compiling
 - Clean and simple code, easy to maintain and add new libraries to build
 - Statically build LV2 plugins for (at least) macOS and Windows
 - Define each plugin project in its own file, to make it easy to support new plugins via pull-request
 - Package the entire collection as an installer

Additonally, PawPaw will be used to build library dependencies for
[Carla](https://github.com/falkTX/Carla) and
[JACK2](https://github.com/jackaudio/jack2).
