#!/bin/csh

date

#
# Setup environment:
# =============================================
pwd
echo "da"
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

set self_WorkDir = $WorkDirsArg
set self_StateDirs = ($inStateDirsArg)
set self_StatePrefix = inStatePrefixArg

echo "WorkDir = ${self_WorkDir}"

cd ${self_WorkDir}

set meshFile = ./${BGFilePrefix}.${fileDate}.nc

# Remove old logs
rm jedi.log*

set member = 1
while ( $member <= ${nEnsDAMembers} )
  # TODO(JJG): centralize this directory name construction (cycle.csh?)
  set other = $self_StateDirs[$member]
  set bg = $CyclingDAInDirs[$member]
  set an = $CyclingDAOutDirs[$member]
  mkdir -p ${bg}
  mkdir -p ${an}

  # Link/copy bg from other directory and ensure that MPASDiagVars are present
  # =========================================================================
  set bgFileOther = ${other}/${self_StatePrefix}.$fileDate.nc
  set bgFileDA = ${bg}/${BGFilePrefix}.$fileDate.nc

  set copyDiags = 0
  foreach var ({$MPASDiagVars})
    ncdump -h ${bgFileOther} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
    endif 
  end
  if ( $copyDiags > 0 ) then
    ln -fsv ${bgFileOther} ${bgFileDA}_orig
    set diagFile = ${other}/${DIAGFilePrefix}.$fileDate.nc
    cp ${bgFileDA}_orig ${bgFileDA}

    # Copy diagnostic variables used in DA to bg
    # ==========================================
    ncks -A -v ${MPASDiagVars} ${diagFile} ${bgFileDA}
  else
    ln -fsv ${bgFileOther} ${bgFileDA}
  endif

  # Remove existing analysis file, if any
  # =====================================
  rm ${an}/${anStatePrefix}.${fileDate}.nc

  @ member++
end

# use one of the backgrounds as the meshFile (see jediPrep)
ln -sf ${bgFileDA} ${meshFile}


# ===================
# ===================
# Run the executable:
# ===================
# ===================
ln -sf ${JEDIBUILDDIR}/bin/${DAEXE} ./
mpiexec ./${DAEXE} ./jedi.yaml ./jedi.log >& jedi.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ${JEDIBUILDDIR}/bin/${DAEXE}  ./jedi.yaml ./jedi.log

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

## add hydrometeors to update variables (if needed)
set UpdateHydrometeors = 0
foreach obs ($DAObsList)
  ## determine if hydrometeor analysis variables are needed
  if ( "$obs" =~ "all"* ) then
    set UpdateHydrometeors = 1
  endif
end
set MPASANVars = $MPASStandardANVars
if ( $UpdateHydrometeors == 1 ) then
  foreach hydro ($MPASHydroANVars)
    set MPASANVars = $MPASANVars,$hydro
  end
endif

#
# Update analyzed variables:
# =============================================
#rm outList${thisValidDate}
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set bg = $CyclingDAInDirs[$member]
  set an = $CyclingDAOutDirs[$member]

  ## copy background to analysis
  set bgFile = ${bg}/${BGFilePrefix}.$fileDate.nc
  set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
  cp ${bgFile} ${anFile}

  ## replace ANVars with output analysis values
  set anFileDA = ${an}/${anStatePrefix}.$fileDate.nc
  ncks -A -v ${MPASANVars} ${anFileDA} ${anFile}
  rm ${anFileDA}

#  echo `pwd`"/${anFile}" >> outList${thisValidDate}

  @ member++
end

date

exit 0
