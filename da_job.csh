#!/bin/csh
#PBS -N daCDATE_EXPNAME
#PBS -A ACCOUNTNUM
#PBS -q QUEUENAME
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

setenv DATE            CDATE
setenv DA_TYPE         DATYPESUB
setenv BG_STATE_DIR    BGDIR
setenv BG_STATE_PREFIX BGSTATEPREFIX

#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${DATE} | cut -c 1-4`
set mm = `echo ${DATE} | cut -c 5-6`
set dd = `echo ${DATE} | cut -c 7-8`
set hh = `echo ${DATE} | cut -c 9-10`

set FILE_DATE  = ${yy}-${mm}-${dd}_${hh}.00.00

# Remove old logs
rm jedi.log*

##############################################################################
# EVERYTHING BEYOND HERE MUST HAPPEN AFTER THE PREVIOUS FORECAST IS COMPLETED
##############################################################################

set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $DA_TYPE $member`
  set other = ${BG_STATE_DIR}${memDir}
  set bg = ./${bgDir}${memDir}
  set an = ./${anDir}${memDir}
  mkdir -p ${bg}
  mkdir -p ${an}

  # Link/copy bg from other directory and ensure that MPASDiagVars are present
  # =========================================================================
  set bgFileOther = ${other}/${BG_STATE_PREFIX}.$FILE_DATE.nc
  set bgFileDA = ${bg}/${BG_FILE_PREFIX}.$FILE_DATE.nc

  set copyDiags = 0
  foreach var ({$MPASDiagVars})
    ncdump -h ${bgFileOther} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
    endif 
  end
  if ( $copyDiags > 0 ) then
    ln -fsv ${bgFileOther} ${bgFileDA}_orig
    set diagFile = ${other}/${DIAG_FILE_PREFIX}.$FILE_DATE.nc
    cp ${bgFileDA}_orig ${bgFileDA}

    # Copy diagnostic variables used in DA to bg
    # ==========================================
    ncks -A -v ${MPASDiagVars} ${diagFile} ${bgFileDA}
  else
    ln -fsv ${bgFileOther} ${bgFileDA}
  endif

  # Remove existing analysis file, if any
  # =====================================
  rm ${an}/analysis.${FILE_DATE}.nc

  @ member++
end

# link one of the backgrounds to a local RST file
# used to initialize the MPAS mesh
ln -sf ${bgFileDA} ./${BG_FILE_PREFIX}.$FILE_DATE.nc


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

#
# Update analyzed variables:
# =============================================
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $DA_TYPE $member`

  set bg = ./${bgDir}${memDir}
  set an = ./${anDir}${memDir}

  ## copy background to analysis
  set bgFile = ${bg}/${BG_FILE_PREFIX}.$FILE_DATE.nc
  set anFile = ${an}/${AN_FILE_PREFIX}.$FILE_DATE.nc
  cp ${bgFile} ${anFile}

  ## replace ANVars with output analysis values
  set anFileDA = ${an}/analysis.$FILE_DATE.nc
  ncks -A -v ${MPASANVars} ${anFileDA} ${anFile}
  rm ${anFileDA}

  @ member++
end

#cp ${BG_FILE_PREFIX}.${FILE_DATE}.nc ${AN_FILE_PREFIX}.${FILE_DATE}.nc
#ncks -A -v theta,rho,u,qv,uReconstructZonal,uReconstructMeridional analysis.${FILE_DATE}.nc ${AN_FILE_PREFIX}.${FILE_DATE}.nc

date

exit 0
