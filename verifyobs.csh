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

# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/verification.csh
source config/environment.csh
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

# other templated variables
set self_jediAppName = jediAppNameTEMPLATE
set self_nOuter = nOuterTEMPLATE

# ================================================================================================

# collect obs-space diagnostic statistics into DB files
# =====================================================
mkdir -p ${self_WorkDir}/${ObsDiagnosticsDir}
cd ${self_WorkDir}/${ObsDiagnosticsDir}

set mainScript="DiagnoseObsStatistics"
ln -fs ${pyObsDir}/*.py ./
ln -fs ${pyObsDir}/${mainScript}.py ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

set success = 1
while ( $success != 0 )

  mv log.${mainScript} log.${mainScript}_LAST
  setenv baseCommand "python ${mainScript}.py -n ${NUMPROC} -p ${self_WorkDir}/${OutDBDir} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} -app $self_jediAppName -nout $self_nOuter"

  if ($ArgNMembers > 1) then
    echo "${baseCommand} -m $ArgNMembers -e ${VerificationWorkDir}/${bgDir}${flowMemFmt}/${thisCycleDate}/${OutDBDir}"
    ${baseCommand} -m $ArgNMembers -e "${VerificationWorkDir}/${bgDir}${flowMemFmt}/${thisCycleDate}/${OutDBDir}" >& log.${mainScript}
  else
    echo "${baseCommand}"
    ${baseCommand} >& log.${mainScript}
  endif
  set success = $?
  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh default
    sleep 3
  endif
end
cd -

date

exit
