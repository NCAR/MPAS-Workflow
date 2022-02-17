#!/bin/csh -f

source config/filestructure.csh

## workflow tools
set pyDir = ${mainScriptDir}/tools
set pyTools = ( \
  advanceCYMDH \
  getConfig \
  memberDir \
  nSpaces \
  substituteEnsembleB \
  updateXTIME \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end
