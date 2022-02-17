#!/bin/csh -f

source config/filestructure.csh

## workflow tools
set pyDir = ${mainScriptDir}/tools
set pyTools = ( \
  memberDir \
  advanceCYMDH \
  create_amb_in_nc \
  nSpaces \
  updateXTIME \
  substituteEnsembleB \
  TimeFmtChange \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end
