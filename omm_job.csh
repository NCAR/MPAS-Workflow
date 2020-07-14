#!/bin/csh
#PBS -N OMMTypeArgDateArg_ExpNameArg
#PBS -l select=2:ncpus=18:mpiprocs=18:mem=109GB
#PBS -A AccountNumArg
#PBS -q QueueNameArg
#PBS -m ae
#PBS -k eod
#PBS -o log.job.out
#PBS -e log.job.err

date

#
#set environment:
# =============================================
source ./setup.csh

setenv self_Date          DateArg
setenv self_bgStateDir    bgStateDirArg
setenv self_bgStatePrefix bgStatePrefixArg

#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${self_Date} | cut -c 1-4`
set mm = `echo ${self_Date} | cut -c 5-6`
set dd = `echo ${self_Date} | cut -c 7-8`
set hh = `echo ${self_Date} | cut -c 9-10`

set fileDate = ${yy}-${mm}-${dd}_${hh}.00.00

# Remove old logs
rm jedi.log*

#################################################################
# EVERYTHING BEYOND HERE MUST HAPPEN AFTER OMM STATE IS AVAILABLE
#################################################################

# Link/copy bg from other directory and ensure that MPASDiagVars are present
# =========================================================================

set memDir = `${memberDir} ${omm} 0`
set other = ${self_bgStateDir}${memDir}
set bgFileOther = ${other}/${self_bgStatePrefix}.$fileDate.nc
set bgFileDA = ./${BGFilePrefix}.$fileDate.nc

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
rm ${anStatePrefix}.${fileDate}.nc

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
rm ${anStatePrefix}.${fileDate}.nc

date

exit 0
