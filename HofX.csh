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
source config/modeldata.csh
source config/mpas/variables.csh
source config/builds.csh
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
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${HofXBuildDir}
set myEXE = ${HofXEXE}
set myYAML = ${self_WorkDir}/$appyaml

# other templated variables
set self_StateDir = $inStateDirsTEMPLATE[$ArgMember]
set self_StatePrefix = inStatePrefixTEMPLATE

# Remove old logs
rm jedi.log*

# Remove old netcdf lock files
rm *.nc*.lock

# Remove old static fields in case this directory was used previously
rm ${localStaticFieldsPrefix}*.nc*

# ==================================================================================================

# =============================
# Input model state preparation
# =============================

## copy static fields
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
set StaticMemDir = `${memberDir} ensemble $ArgMember "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

# Link/copy bg from other directory + ensure that MPASJEDIDiagVariables are present
# =================================================================================
set bg = ./${bgDir}
mkdir -p ${bg}

set bgFileOther = ${self_StateDir}/${self_StatePrefix}.$thisMPASFileDate.nc
set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc

rm ${bgFile}${OrigFileSuffix} ${bgFile}
ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
ln -sfv ${bgFileOther} ${bgFile}

set copyDiags = 0
foreach var ({$MPASJEDIDiagVariables})
  echo "Checking for presence of variable ($var) in ${bgFile}"
  ncdump -h ${bgFile} | grep $var
  if ( $status != 0 ) then
    @ copyDiags++
    echo "variable ($var) not present"
  endif
end
if ( $copyDiags > 0 ) then
  echo "Copy diagnostic variables used in HofX to bg: $MPASJEDIDiagVariables"
  rm ${bgFile}
  cp -v ${bgFileOther} ${bgFile}
  set diagFile = ${self_StateDir}/${DIAGFilePrefix}.$thisMPASFileDate.nc
  ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${bgFile}
endif

# use the background as the TemplateFieldsFileOuter
ln -sfv ${bgFile} ${TemplateFieldsFileOuter}

# Run the executable
# ==================
ln -sfv ${myBuildDir}/${myEXE} ./
mpiexec ./${myEXE} $myYAML ./jedi.log >& jedi.log.all


# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
endif

## change static fields to a link, keeping for transparency
rm ${localStaticFieldsFile}
mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}

# Remove netcdf lock files
rm *.nc*.lock

date

exit 0
