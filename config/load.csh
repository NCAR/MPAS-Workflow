#!/bin/csh -f

## must be run from 

## loader tools
set pyDir = tools
set pyTools = ( \
  getConfig \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end

set configs = ( \
  experiment \
)


