#!/bin/csh -f

if ( $?config_config ) exit 0
set config_config = 1

## config tools
set wd = `pwd`
set pyDir = $wd/tools
setenv getYAMLNode "python ${pyDir}/getYAMLNode.py"
setenv setConfig "$wd/config/setConfig.csh"
