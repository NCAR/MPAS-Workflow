#!/bin/csh
#PBS -N OMMTYPECDATE_EXPNAME
#PBS -l select=2:ncpus=18:mpiprocs=18:mem=109GB

## 30km
#   #PBS -l walltime=0:20:00

## 120km
#PBS -l walltime=0:06:00

#PBS -q QUEUENAME
#PBS -A ACCOUNTNUM
#PBS -m ae
#PBS -k eod
#PBS -o log.job.out
#PBS -e log.job.err

date

#
#set environment:
# =============================================
source ./setup.csh

setenv DATE            CDATE
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

#################################################################
# EVERYTHING BEYOND HERE MUST HAPPEN AFTER OMM STATE IS AVAILABLE
#################################################################

# Link/copy bg from other directory and ensure that MPASDiagVars are present
# =========================================================================
set bgFileOther = ${BG_STATE_DIR}/${BG_STATE_PREFIX}.$FILE_DATE.nc
set bgFileDA = ./${BG_FILE_PREFIX}.$FILE_DATE.nc

set copyDiags = 0
foreach var ({$MPASDiagVars})
  ncdump -h ${bgFileOther} | grep $var
  if ( $status != 0 ) then
    @ copyDiags++
  endif 
end
if ( $copyDiags > 0 ) then
  ln -fsv ${bgFileOther} ${bgFileDA}_orig
  set diagFile = ${BG_STATE_DIR}/${DIAG_FILE_PREFIX}.$FILE_DATE.nc
  cp ${bgFileDA}_orig ${bgFileDA}

  # Copy diagnostic variables used in DA to bg
  # ==========================================
  ncks -A -v ${MPASDiagVars} ${diagFile} ${bgFileDA}
else
  ln -fsv ${bgFileOther} ${bgFileDA}
endif

# Remove existing analysis file, if any
# =====================================
rm analysis.${FILE_DATE}.nc

# ===================
# ===================
# Run the executable:
# ===================
# ===================
ln -sf ${JEDIBUILDDIR}/bin/${OMMEXE} ./
mpiexec ./${OMMEXE} ./jedi.yaml ./jedi.log >& jedi.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ${JEDIBUILDDIR}/bin/${OMMEXE}  ./jedi.yaml ./jedi.log

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
rm analysis.${FILE_DATE}.nc

date

exit 0
