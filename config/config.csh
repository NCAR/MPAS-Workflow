#!/bin/csh -f

# defines helper functions for parsing YAML in c-shell

if ( $?config_config ) exit 0
setenv config_config 1

## config tools
set wd = `pwd`
set pyDir = $wd/tools
setenv getYAMLNode "python ${pyDir}/getYAMLNode.py"
setenv setConfig "$wd/config/setConfig.csh"
setenv setNestedConfig "$wd/config/setNestedConfig.csh"
setenv getConfigOrNone "$wd/config/getConfigOrNone.csh"
