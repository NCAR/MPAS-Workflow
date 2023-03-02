#!/bin/csh -f

## load the workflow settings

# experiment provides mainScriptDir
source config/auto/experiment.csh

setenv mainAppDir ${mainScriptDir}/applications
mkdir -p ${mainAppDir}

set configParts = ( \
  applications \
  config \
  getCycleVars.csh \
  include \
  scenarios \
  suites \
  test \
  tools \
)
foreach part ($configParts)
  cp -rP $part ${mainScriptDir}/
end

exit 0
