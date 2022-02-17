#!/bin/csh -f

## workflow tools
set pyDir = tools
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
