#!/bin/csh -f

if ( $?config_config ) exit 0
set config_config = 1

## config tools
set wd = `pwd`
set pyDir = $wd/tools
setenv getYAMLKey "python ${pyDir}/getYAMLKey.py"
setenv getConfig "$wd/config/getConfig.csh"
setenv setConfig "$wd/config/setConfig.csh"
