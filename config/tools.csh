#!/bin/csh -f

if ( $?config_tools ) exit 0
set config_tools = 1

## workflow tools
set wd = `pwd`
set pyDir = $wd/tools
set pyTools = ( \
  advanceCYMDH \
  checkMissingChannels \
  create_amb_in_nc \
  dateList \
  memberDir \
  nSpaces \
  substituteEnsembleBMembers \
  substituteEnsembleBTemplate \
  TimeFmtChange \
  updateXTIME \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end
