#!/bin/csh -f

if ( $?config_environment ) exit 0
setenv config_environment 1

# jedi build/run environment
source config/builds.csh
source config/environmentForJedi.csh ${BuildCompiler}

module list
