#!/bin/csh -f

date

# Setup environment
# =================
source config/filestructure.csh
source config/tools.csh
source config/variational.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADirs[1]
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# ================================================================================================

# Remove obs-database output files
# ================================
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $DAType $member`
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.h5
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4
  @ member++
end

# Remove netcdf lock files
rm *.nc*.lock

# Remove copies of templated fields files for inner loop
if ("${TemplateFieldsFileInner}" != "${TemplateFieldsFileOuter}") then
  rm ${TemplateFieldsFileInner}*
endif

date

exit 0
