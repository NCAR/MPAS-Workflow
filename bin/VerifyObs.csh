#!/bin/csh -f

date

# Process arguments
# =================
## args
# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: str, where to run
set ArgWorkDir = "$2"

# ArgObsFeedbackDir: directory of model state input
set ArgObsFeedbackDir = "$3"

# ArgNMembers: int, set > 1 to activate ensemble spread diagnostics
set ArgNMembers = "$4"

# ArgAppType: str, type of application being verified (hofx or variational)
set ArgAppType = "$5"

## arg checks
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

if ("$ArgAppType" != hofx && "$ArgAppType" != variational) then
  echo "$0 (ERROR): ArgAppType must be hofx or variational, not $ArgAppType"
  exit 1
endif

# Setup environment
# =================
source config/tools.csh
source config/auto/observations.csh
source config/auto/workflow.csh
source config/auto/$ArgAppType.csh
source config/auto/verifyobs.csh
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

set ObsFeedbackDir = ${ExperimentDirectory}/`echo "$ArgObsFeedbackDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `

setenv HDF5_DISABLE_VERSION_CHECK 1
setenv NUMEXPR_MAX_THREADS 1

# ================================================================================================

# collect obs-space diagnostic statistics into DB files
# =====================================================
set mainScript="DiagnoseObsStatistics"
ln -fs ${scriptDirectory}/*.py ./
ln -fs ${scriptDirectory}/${mainScript}.py ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

set success = 1
while ( $success != 0 )

  mv log.${mainScript} log.${mainScript}_LAST
  setenv baseCommand "python ${mainScript}.py -n ${NUMPROC} -p ${ObsFeedbackDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} -app $ArgAppType"
if ("$ArgAppType" == variational) then
  setenv baseCommand "$baseCommand -nout $nOuterIterations"
endif

  if ($ArgNMembers > 1) then
    #Note: this only works for BG verifcation, not extended ensemble forecasts
    echo "${baseCommand} -m $ArgNMembers -e ${VerifyObsWorkDir}/${backgroundSubDir}${flowMemFmt}/${thisCycleDate}/${OutDBDir}" | tee ./myCommand
    ${baseCommand} -m $ArgNMembers -e "${VerifyObsWorkDir}/${backgroundSubDir}${flowMemFmt}/${thisCycleDate}/${OutDBDir}" >& log.${mainScript}
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
