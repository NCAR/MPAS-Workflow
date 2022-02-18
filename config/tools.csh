#!/bin/csh -f

if ( $?config_tools ) exit 0
setenv config_tools 1

## ArgToolsDir
# directory where tools are located
# most often this is either the git repository directory (MPAS-Workflow) or
# the experiment-specific mainScriptDir
set ArgToolsDir = $1

## workflow tools
set pyDir = $ArgToolsDir/tools
set pyTools = ( \
  advanceCYMDH \
  getYAMLKey \
  memberDir \
  nSpaces \
  substituteEnsembleB \
  updateXTIME \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end

setenv getConfig "config/getConfig.csh"
setenv setConfig "config/setConfig.csh"
