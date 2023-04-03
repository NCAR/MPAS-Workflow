#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
## args
# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: str, where to run
set ArgWorkDir = "$2"

# ArgStateDir: directory of model state input
set ArgStateDir = "$3"

# ArgStatePrefix: prefix of model state input
set ArgStatePrefix = "$4"

# ArgNMembers: int, set > 1 to activate ensemble spread diagnostics
set ArgNMembers = "$5"

## arg checks
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

# Setup environment
# =================
source config/tools.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/auto/model.csh
source config/auto/verifymodel.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./bin/getCycleVars.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

if ( "$ArgStateDir" =~ "*prevCycleDate*" ) then
  set StateDir = ${ExperimentDirectory}/`echo "$ArgStateDir" \
    | sed 's@{{prevCycleDate}}@'${prevCycleDate}'@' \
    `
else if ( "$ArgStateDir" =~ "*thisCycleDate*" ) then
  set StateDir = ${ExperimentDirectory}/`echo "$ArgStateDir" \
    | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
    `
else
  set StateDir = ${ExperimentDirectory}/$ArgStateDir
endif

setenv HDF5_DISABLE_VERSION_CHECK 1
setenv NUMEXPR_MAX_THREADS 1

# ================================================================================================

# collect model-space diagnostic statistics into DB files
# =======================================================

set other = $StateDir
set bgFileOther = ${other}/${ArgStatePrefix}.$thisMPASFileDate.nc
ln -sf ${bgFileOther} ../restart.$thisMPASFileDate.nc

ln -fs ${scriptDirectory}/*.py ./

set mainScript = DiagnoseModelStatistics

ln -fs ${scriptDirectory}/${mainScript}.py ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

set EADir = ${ExperimentDirectory}/`echo "${ExternalAnalysesDirOuter}" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `

set success = 1
while ( $success != 0 )
  mv log.$mainScript log.${mainScript}_LAST
  setenv baseCommand "python ${mainScript}.py ${thisValidDate} -n ${NUMPROC} -r $EADir/$externalanalyses__filePrefixOuter"

  if ($ArgNMembers > 1) then
    #Note: ensemble diagnostics only work for BG/AN verification, not extended ensemble forecasts
    # legacy file structure (deprecated)
    #echo "${baseCommand} -m $ArgNMembers -a ../../../../../../CyclingInflation/RTPP/YYYYMMDDHH/an0/mem{:03d}/an" | tee ./myCommand
    #${baseCommand} -m $ArgNMembers -a "../../../../../../CyclingInflation/RTPP/YYYYMMDDHH/an0/mem{:03d}/an" >& log.${mainScript}

    # latest file structure
    echo "${baseCommand} -m $ArgNMembers" | tee ./myCommand
    ${baseCommand} -m $ArgNMembers >& log.${mainScript}

  else
    echo "${baseCommand}" | tee ./myCommand
    ${baseCommand} >& log.${mainScript}

  endif
  set success = $?
end

grep "Finished __main__ successfully" log.${mainScript}
if ( $status != 0 ) then
  echo "ERROR in $0 : ${mainScript} failed" > ./FAIL
  exit 1
endif

date

exit
