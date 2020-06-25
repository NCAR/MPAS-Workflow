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
#PBS -o jedi.log.job.out 
#PBS -e jedi.log.job.err

date

#
#set environment:
# =============================================
source ./setup.csh

setenv DATE     CDATE

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

# Copy specific diagnostic variables used in DA to bg
# ===================================================
if ( BGFROMCYCLEDIR ) then
  # Use when copying BG from analysis directory
  ln -sf ./${RST_FILE_PREFIX}.$FILE_DATE.nc_orig ./${RST_FILE_PREFIX}.$FILE_DATE.nc
else
  # Use when copying BG from forecast directory
  cp ./${RST_FILE_PREFIX}.$FILE_DATE.nc_orig ./${RST_FILE_PREFIX}.$FILE_DATE.nc
  ncks -A -v cldfrac diag.$FILE_DATE.nc ${RST_FILE_PREFIX}.$FILE_DATE.nc
endif

# Ensure analysis file is not present
# ===================================
rm analysis.${FILE_DATE}.nc

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
grep 'Run: Finishing oops::.*<MPAS> with status = 0' jedi.log
if ( $status != 0 ) then
    touch ./FAIL
    echo "ERROR in $0 : mpas-jedi failed" >> ./FAIL
    exit 1
endif

# Remove garbage analysis file
# ============================
rm analysis.${FILE_DATE}.nc

date

exit 0
