#!/bin/csh

date

#
# Setup environment:
# =============================================
source config/experiment.csh
source config/data.csh
source config/mpas/variables.csh
source config/build.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADirs[1]
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# templated variables
set self_StateDirs = ($inStateDirsTEMPLATE)
set self_StatePrefix = inStatePrefixTEMPLATE

# Remove old logs
rm jedi.log*

# Link/copy bg from StateDirs and ensure that MPASDiagVariables are present
# ====================================================================
set member = 1
while ( $member <= ${nEnsDAMembers} )
  # TODO(JJG): centralize this directory name construction (cycle.csh?)
  set other = $self_StateDirs[$member]
  set bg = $CyclingDAInDirs[$member]
  set an = $CyclingDAOutDirs[$member]
  mkdir -p ${bg}
  mkdir -p ${an}

  set bgFileOther = ${other}/${self_StatePrefix}.$fileDate.nc
  set bgFile = ${bg}/${BGFilePrefix}.$fileDate.nc

  rm ${bgFile}${OrigFileSuffix} ${bgFile}
  ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
  cp -v ${bgFileOther} ${bgFile}

  # Remove existing analysis file, then link to bg file
  # ===================================================
  set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
  rm ${anFile}
  ln -sfv ${bgFile} ${anFile}

  # Copy diagnostic variables used in DA to bg (if needed)
  # ======================================================
  set copyDiags = 0
  foreach var ({$MPASDiagVariables})
    ncdump -h ${bgFileOther} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
    endif 
  end
  if ( $copyDiags > 0 ) then
    set diagFile = ${other}/${DIAGFilePrefix}.$fileDate.nc
    ncks -A -v ${MPASDiagVariables} ${diagFile} ${bgFile}
    rm ${bgFile}${OrigFileSuffix}
    cp ${bgFile} ${bgFile}${OrigFileSuffix}
  endif

  @ member++
end

# use one of the backgrounds as the localTemplateFieldsFile
ln -sfv ${bgFile} ${localTemplateFieldsFile}

## copy static fields:
#TODO: staticFieldsDir needs to be unique for each ensemble member (ivgtyp, isltyp, etc...)
set staticMemDir = `${memberDir} ens 1 "${staticMemFmt}"`
set memberStaticFieldsFile = ${staticFieldsDir}${staticMemDir}/${staticFieldsFile}
rm ${localStaticFieldsFile}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

# ===================
# ===================
# Run the executable:
# ===================
# ===================
ln -sfv ${VariationalBuildDir}/${VariationalEXE} ./
mpiexec ./${VariationalEXE} $appyaml ./jedi.log >& jedi.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ./${VariationalEXE} $appyaml ./jedi.log

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
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}

date

exit 0
