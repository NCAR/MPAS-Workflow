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

set meshFile = ./${BGFilePrefix}.${fileDate}.nc

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

  ln -fsv ${bgFileOther} ${bgFile}_orig
  cp ${bgFile}_orig ${bgFile}

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
  endif

  @ member++
end

# use one of the backgrounds as the meshFile (see jediPrep)
#TODO: create link until gridfname is used
ln -sf ${bgFile} ${meshFile}


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
#ddt --connect ${DABuildDir}/bin/${DAEXE} $appyaml ./jedi.log

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

### add hydrometeors to update variables (if needed)
#set UpdateHydrometeors = 0
#foreach obs ($DAObsList)
#  ## determine if hydrometeor analysis variables are needed
#  if ( "$obs" =~ "all"* ) then
#    set UpdateHydrometeors = 1
#  endif
#end
#set MPASANVariables = $MPASStandardANVariables
#if ( $UpdateHydrometeors == 1 ) then
#  foreach hydro ($MPASHydroANVariables)
#    set MPASANVariables = $MPASANVariables,$hydro
#  end
#endif
#
##
## Update analyzed variables:
## =============================================
##TODO: do this in a separate post-processing script
##      either in parallel or using only single processor
##      instead of full set of job processors
#set member = 1
#while ( $member <= ${nEnsDAMembers} )
#  set bg = $CyclingDAInDirs[$member]
#  set an = $CyclingDAOutDirs[$member]
#
#  ## copy background to analysis
#  set bgFile = ${bg}/${BGFilePrefix}.$fileDate.nc
#  set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
#  cp ${bgFile} ${anFile}
#
#  ## replace ANVariables with output analysis values
#  set anFileDA = ${an}/${anStatePrefix}.$fileDate.nc
#  ncks -A -v ${MPASANVariables} ${anFileDA} ${anFile}
#  rm ${anFileDA}
#
#  @ member++
#end

date

exit 0
