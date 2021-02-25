#!/bin/csh

date

## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

# ArgStateType: str, FC if this is a forecasted state, activates ArgDT in directory naming
set ArgStateType = "$3"

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

#
# Setup environment:
# =============================================
source ./control.csh
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
cd ${self_WorkDir}

# other templated variables
set self_StateDir = $inStateDirsTEMPLATE[$ArgMember]
set self_StatePrefix = inStatePrefixTEMPLATE

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

rm ${bgFile}
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
  echo "Copy diagnostic variables used in OMM to bg"
  # ===============================================
  set diagFile = ${self_StateDir}/${DIAGFilePrefix}.$fileDate.nc
  rm ${bgFile}${OrigFileSuffix}
  mv ${bgFile} ${bgFile}${OrigFileSuffix}
  cp -v ${bgFile}${OrigFileSuffix} ${bgFile}
  ncks -A -v ${MPASDiagVariables} ${diagFile} ${bgFile}
endif

# use the background as the localTemplateFieldsFile
ln -sf ${bgFile} ${localTemplateFieldsFile}## copy static fieldsset staticMemDir = `${memberDir} ens $ArgMember "${staticMemFmt}"`

## copy static fields:
set staticMemDir = `${memberDir} ens $ArgMember "${staticMemFmt}"`
set memberStaticFieldsFile = ${staticFieldsDir}${staticMemDir}/${staticFieldsFile}
rm ${localStaticFieldsFile}
ln -sf ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

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

## change static fields to a link:
rm ${localStaticFieldsFile}
rm ${localStaticFieldsFile}${OrigFileSuffix}
ln -sf ${memberStaticFieldsFile} ${localStaticFieldsFile}

date

exit 0
