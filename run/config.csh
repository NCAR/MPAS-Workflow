#!/bin/csh -f

if ( $?run_config ) exit 0
set run_config = 1

## ArgWorkflowDir
# directory where tools are located
# most often this is either the git repository directory (MPAS-Workflow) or
# the experiment-specific mainScriptDir
set ArgWorkflowDir = $1

set ArgDefaults = $2

## workflow tools
set pyDir = $ArgWorkflowDir/tools
setenv getYAMLKey "python ${pyDir}/getYAMLKey.py $ArgWorkflowDir/$ArgDefaults"

setenv getConfig "$ArgWorkflowDir/config/getConfig.csh"
setenv setConfig "$ArgWorkflowDir/config/setConfig.csh"
