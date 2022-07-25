#!/bin/csh -f

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

# ArgStateType: str, FC if this is a forecasted state, activates ArgDT in directory naming
set ArgStateType = "$3"

# ArgNMembers: int, set > 1 to activate ensemble spread diagnostics
set ArgNMembers = "$4"

# ArgAppType: str, type of application being verified (hofx or variational)
set ArgAppType = "$5"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

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
source config/experiment.csh
source config/tools.csh
source config/applications/$ArgAppType.csh
source config/applications/verifyobs.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

# templated work directory
set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif
echo "WorkDir = ${self_WorkDir}"

setenv HDF5_DISABLE_VERSION_CHECK 1
setenv NUMEXPR_MAX_THREADS 1

# ================================================================================================

# collect obs-space diagnostic statistics into DB files
# =====================================================
mkdir -p ${self_WorkDir}/${ObsDiagnosticsDir}
cd ${self_WorkDir}/${ObsDiagnosticsDir}

set mainScript="DiagnoseObsStatistics"
ln -fs ${pyVerifyDir}/*.py ./
ln -fs ${pyVerifyDir}/${mainScript}.py ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

set success = 1
while ( $success != 0 )

  mv log.${mainScript} log.${mainScript}_LAST
  setenv baseCommand "python ${mainScript}.py -n ${NUMPROC} -p ${self_WorkDir}/${OutDBDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} -app $ArgAppType"
if ("$ArgAppType" == variational) then
  setenv baseCommand "$baseCommand -nout $nOuterIterations"
endif

  if ($ArgNMembers > 1) then
    #Note: this only works for BG verifcation, not extended ensemble forecasts
    echo "${baseCommand} -m $ArgNMembers -e ${VerificationWorkDir}/${bgDir}${flowMemFmt}/${thisCycleDate}/${OutDBDir}" | tee ./myCommand
    ${baseCommand} -m $ArgNMembers -e "${VerificationWorkDir}/${bgDir}${flowMemFmt}/${thisCycleDate}/${OutDBDir}" >& log.${mainScript}
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
