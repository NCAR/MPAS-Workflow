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
  fix_float2int \
  memberDir \
  nSpaces \
  substituteEnsembleBMembers \
  substituteEnsembleBTemplate \
  substituteEnsembleBTemplate_4d \
  substituteEnsembleBTemplate_4d_7slots \
  TimeFmtChange \
  update_sensorScanPosition \
  updateXTIME \
  concatenate \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end
