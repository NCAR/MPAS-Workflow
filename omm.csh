#!/bin/csh

date

set ArgMember = "$1"
set ArgDT = "$2"
set ArgStateType = "$3"

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

set test = `echo $ArgMember | grep '^[0-9]*$'`
set isInt = (! $status)
if ( $isInt && "$ArgMember" != "0") then
  set self_WorkDir = $WorkDirsArg[$ArgMember]
  set self_StateDir = $inStateDirsArg[$ArgMember]
else
  set self_WorkDir = $WorkDirsArg
  set self_StateDir = $inStateDirsArg
endif
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isInt = (! $status)
if ( ! $isInt) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif
set self_StatePrefix = inStatePrefixArg

echo "WorkDir = ${self_WorkDir}"

cd ${self_WorkDir}

# Remove old logs
rm jedi.log*

# Link/copy bg from other directory and ensure that MPASDiagVariables are present
# =========================================================================
set bg = ./${bgDir}
set an = ./${anDir}
mkdir -p ${bg}
mkdir -p ${an}

set bgFileOther = ${self_StateDir}/${self_StatePrefix}.$fileDate.nc
set bgFile = ${bg}/${BGFilePrefix}.$fileDate.nc

ln -fsv ${bgFileOther} ${bgFile}

# Remove existing analysis file, then link to bg file
# ===================================================
set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
rm ${anFile}

set copyDiags = 0
foreach var ({$MPASDiagVariables})
  ncdump -h ${bgFileOther} | grep $var
  if ( $status != 0 ) then
    @ copyDiags++
  endif 
end
if ( $copyDiags > 0 ) then
  # Copy diagnostic variables used in DA to bg
  # ==========================================
  set diagFile = ${self_StateDir}/${DIAGFilePrefix}.$fileDate.nc
  mv ${bgFile} ${bgFile}${OrigFileSuffix}
  cp -v ${bgFile}${OrigFileSuffix} ${bgFile}
  ncks -A -v ${MPASDiagVariables} ${diagFile} ${bgFile}
endif

# use the background as the localMeshFile (see jediPrep)
ln -sf ${bgFile} ${localMeshFile}

# ===================
# ===================
# Run the executable:
# ===================
# ===================
ln -sf ${OMMBuildDir}/${OMMEXE} ./
mpiexec ./${OMMEXE} $appyaml ./jedi.log >& jedi.log.all

#
# Check status:
# =============================================
#grep "Finished running the atmosphere core" log.atmosphere.0000.out
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  touch ./FAIL
  echo "ERROR in $0 : jedi application failed" >> ./FAIL
  exit 1
endif

# Remove garbage analysis file
# ============================
rm ${anFile}

date

exit 0
