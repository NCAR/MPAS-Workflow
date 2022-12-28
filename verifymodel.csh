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
source config/externalanalyses.csh
source config/tools.csh
source config/model.csh
source config/applications/verifymodel.csh
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
setenv self_StatePrefix inStatePrefixTEMPLATE
set self_StateDir = $inStateDirsTEMPLATE[$ArgMember]

setenv HDF5_DISABLE_VERSION_CHECK 1
setenv NUMEXPR_MAX_THREADS 1

# ================================================================================================

# collect model-space diagnostic statistics into DB files
# =======================================================
mkdir -p ${self_WorkDir}/${ModelDiagnosticsDir}
cd ${self_WorkDir}/${ModelDiagnosticsDir}

set other = $self_StateDir
set bgStateOther = ${other}/${self_StatePrefix}.$thisMPASFileDate.nc
ln -sf ${bgStateOther} ../restart.$thisMPASFileDate.nc

set bgDiagnosticsOther = ${other}/${DIAGFilePrefix}.$thisMPASFileDate.nc
ln -sf ${bgDiagnosticsOther} ../${DIAGFilePrefix}.$thisMPASFileDate.nc

ln -fs ${pyVerifyDir}/*.py ./

set mainScript = DiagnoseModelStatistics

ln -fs ${pyVerifyDir}/${mainScript}.py ./
set NUMPROC=`cat $PBS_NODEFILE | wc -l`

set success = 1
while ( $success != 0 )
  mv log.$mainScript log.${mainScript}_LAST
  setenv baseCommand "python ${mainScript}.py ${thisValidDate} -n ${NUMPROC} -r $ExternalAnalysisDirOuter/$externalanalyses__filePrefixOuter -rd /glade/p/mmm/parc/guerrett/pandac/fixed_input/30km/GFSAnaDiagnostics/${thisValidDate}/diag"

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
