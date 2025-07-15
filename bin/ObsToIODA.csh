#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

#Convert CISL RDA archived NCEP BUFR files to IODA-v3 format based on Jamie Bresch (NCAR/MMM) script rda_obs2ioda.csh

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: my location
set ArgWorkDir = "$2"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/observations.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`

source ./bin/getCycleVars.csh

set ccyy = `echo ${thisValidDate} | cut -c 1-4`

set self_WorkDir = "${ExperimentDirectory}/"`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# ================================================================================================

if ( "${observations__resource}" == "PANDACArchive" ) then
  echo "$0 (INFO): PANDACArchive observations are already in IODA format, exiting"
  exit 0
endif

if ( -e CONVERTSUCCESS ) then
  echo "$0 (INFO): CONVERTSUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the output files is desired, delete CONVERTSUCCESS"

  date

  exit 0
endif

if ( -d logs ) rm -r logs
mkdir -p logs

# write out hourly files for IASI
setenv SPLIThourly "-split"

# flag to de-activate additional QC for conventional
# observations as in GSI
setenv noGSIQCFilters "-noqc"

foreach gdasfile ( *"gdas."* )
   echo "Running ${obs2iodaEXE} for ${gdasfile}"
   # link SpcCoeff files for converting IR radiances to brightness temperature
   if ( ${gdasfile} =~ *"cris"* && ${ccyy} >= '2021' ) then
     ln -sf ${CRTMTABLES}/cris-fsr431_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/cris-fsr431_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
     #ln -sf ${CRTMTABLES}/cris-fsr431_n21.SpcCoeff.bin  ./cris_n21.SpcCoeff.bin
   else if ( ${gdasfile} =~ *"cris"* && ${ccyy} < '2021' ) then
     ln -sf ${CRTMTABLES}/cris399_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/cris399_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
   else if ( ${gdasfile} =~ *"mtiasi"* ) then
     ln -sf ${CRTMTABLES}/iasi616_metop-a.SpcCoeff.bin  ./iasi_metop-a.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/iasi616_metop-b.SpcCoeff.bin  ./iasi_metop-b.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/iasi616_metop-c.SpcCoeff.bin  ./iasi_metop-c.SpcCoeff.bin
   endif

   # Run the obs2ioda executable to convert files from BUFR to IODA-v3
   # ==================
   rm ./${obs2iodaEXE}
   ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXE} ./
   set inst = `echo "$gdasfile" | cut -d'.' -f2`

   set log = logs/log-converter_${inst}
   rm $log

   if ( ${gdasfile} =~ *"mtiasi"* ) then
     #./${obs2iodaEXE} ${SPLIThourly} ${gdasfile} >&! $log
     ./${obs2iodaEXE} ${gdasfile} >&! $log
   else if ( ${gdasfile} =~ *"prepbufr"* ) then
     # use obs errors embedded in prepbufr file
     if ( -e obs_errtable ) then
       rm -f obs_errtable
     endif
     set inst = `echo "$gdasfile" | cut -d'.' -f1`
     # run obs2ioda for preburf with additional QC as in GSI
     ./${obs2iodaEXE} ${gdasfile} >&! $log
     # for surface obs, run obs2ioda for prepbufr without additional QC
     mkdir -p sfc
     cd sfc
     ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXE} ./
     ./${obs2iodaEXE} ${noGSIQCFilters} ../${gdasfile} >&! ../logs/log-converter_sfc
     # replace surface obs file with file created without additional QC
     mv -f sfc_obs_${thisCycleDate}.h5 ../sfc_obs_${thisCycleDate}.h5
     cd ..
     rm -rf sfc
   else if ( ${gdasfile} =~ *"satwnd"* ) then
     # link the GDAS observation error table
     if ( -e ${GDASObsErrtable} ) then
       ln -sf ${GDASObsErrtable} obs_errtable
     else
       echo "ERROR: ${GDASObsErrtable} does NOT exist" > ./FAIL
       exit 1
     endif
     ./${obs2iodaEXE} ${gdasfile} >&! $log
   else
     ./${obs2iodaEXE} ${gdasfile} >&! $log
   endif

   # Check status
   # ============
   grep "all done!" $log
   if ( $status != 0 ) then
     echo "$0 (ERROR): Pre-processing observations to IODA-v3 failed" > ./FAIL-converter_${inst}
     exit 1
   endif

  # remove BURF/PrepBUFR files
  rm -rf $gdasfile

end # gdasfile loop

date

touch CONVERTSUCCESS

exit 0
