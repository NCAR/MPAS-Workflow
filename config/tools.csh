#!/bin/csh -f

if ( $?config_tools ) exit 0
set config_tools = 1

## workflow tools
set wd = `pwd`
set pyDir = $wd/tools
set pyTools = ( \
  advanceCYMDH \
  memberDir \
  nSpaces \
  substituteEnsembleB \
  updateXTIME \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end
