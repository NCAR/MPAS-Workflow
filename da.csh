#!/bin/csh

date

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

set self_WorkDir = $CyclingDADir
set self_StateDirs = ($inStateDirsArg)
set self_StatePrefix = inStatePrefixArg

echo "WorkDir = ${self_WorkDir}"

cd ${self_WorkDir}

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
  ln -fsv ${bgFileOther} ${bgFile}${OrigFileSuffix}
  cp -v ${bgFileOther} ${bgFile}

  # Remove existing analysis file, then link to bg file
  # ===================================================
  set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
  rm ${anFile}
  ln -sf ${bgFile} ${anFile}

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

# use one of the backgrounds as the localTemplateFieldsFile (see jediPrep)
#TODO: create link until gridfname is used
ln -sf ${bgFile} ${localTemplateFieldsFile}

## copy static fields:
rm ${localStaticFieldsFile}
ln -sf ${staticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${staticFieldsFile} ${localStaticFieldsFile}

# ===================
# ===================
# Run the executable:
# ===================
# ===================
ln -sf ${DABuildDir}/${DAEXE} ./
mpiexec ./${DAEXE} $appyaml ./jedi.log >& jedi.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ./${DAEXE} $appyaml ./jedi.log

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
ln -sf ${staticFieldsFile} ${localStaticFieldsFile}

date

exit 0
