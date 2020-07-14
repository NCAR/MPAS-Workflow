#!/bin/csh
#PBS -N daDateArg_ExpNameArg
#PBS -A AccountNumArg
#PBS -q QueueNameArg
#PBS -l select=NNODE:ncpus=NPE:mpiprocs=NPE:mem=109GB
#PBS -l walltime=0:25:00
#PBS -m ae
#PBS -k eod
#PBS -o log.job.out
#PBS -e log.job.err

date

#
# Setup environment:
# =============================================
source ./setup.csh

setenv self_Date          DateArg
setenv self_DAType        DATypeArg
setenv self_bgStateDir    bgStateDirArg
setenv self_bgStatePrefix bgStatePrefixArg

#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${self_Date} | cut -c 1-4`
set mm = `echo ${self_Date} | cut -c 5-6`
set dd = `echo ${self_Date} | cut -c 7-8`
set hh = `echo ${self_Date} | cut -c 9-10`

set fileDate  = ${yy}-${mm}-${dd}_${hh}.00.00

# Remove old logs
rm jedi.log*

##############################################################################
# EVERYTHING BEYOND HERE MUST HAPPEN AFTER THE PREVIOUS FORECAST IS COMPLETED
##############################################################################

set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $self_DAType $member`
  set other = ${self_bgStateDir}${memDir}
  set bg = ./${bgDir}${memDir}
  set an = ./${anDir}${memDir}
  mkdir -p ${bg}
  mkdir -p ${an}

  # Link/copy bg from other directory and ensure that MPASDiagVars are present
  # =========================================================================
  set bgFileOther = ${other}/${self_bgStatePrefix}.$fileDate.nc
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

# link one of the backgrounds to a local RST file
# used to initialize the MPAS mesh
ln -sf ${bgFileDA} ./${BGFilePrefix}.$fileDate.nc


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
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $self_DAType $member`

  set bg = ./${bgDir}${memDir}
  set an = ./${anDir}${memDir}

  ## copy background to analysis
  set bgFile = ${bg}/${BGFilePrefix}.$fileDate.nc
  set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
  cp ${bgFile} ${anFile}

  ## replace ANVars with output analysis values
  set anFileDA = ${an}/${anStatePrefix}.$fileDate.nc
  ncks -A -v ${MPASANVars} ${anFileDA} ${anFile}
  rm ${anFileDA}

  @ member++
end

date

exit 0
