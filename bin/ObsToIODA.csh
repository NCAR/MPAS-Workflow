#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

#Convert GDEX archived NCEP BUFR files to IODA-v3 format based on Jamie Bresch (NCAR/MMM) script rda_obs2ioda.csh

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

set nonomatch
foreach gdasfile ( *"gdas."* )
   # nonomatch leaves gdasfile as the literal unexpanded pattern when there are
   # no gdas.* files at all (e.g. a gnssaro-only convertToIODAObservations list);
   # skip that non-file rather than trying to convert it. nonomatch has to stay
   # set through this check too, since testing '-e' on the literal pattern string
   # re-triggers glob expansion.
   if ( ! -e ${gdasfile} ) continue

   echo "Running ${obs2iodaEXE} for ${gdasfile}"
   # link SpcCoeff files for converting IR radiances to brightness temperature
   if ( ${gdasfile} =~ *"cris"* && ${ccyy} >= '2021' ) then
     ln -sf ${CRTMTABLES}/cris-fsr431_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/cris-fsr431_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/cris-fsr431_n21.SpcCoeff.bin  ./cris_n21.SpcCoeff.bin
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
     ./${obs2iodaEXE} -e h5 ${gdasfile} >&! $log
   else if ( ${gdasfile} =~ *"prepbufr"* ) then
     # use obs errors embedded in prepbufr file
     if ( -e obs_errtable ) then
       rm -f obs_errtable
     endif
     set inst = `echo "$gdasfile" | cut -d'.' -f1`
     # run obs2ioda for preburf with additional QC as in GSI
     ./${obs2iodaEXE} -e h5 ${gdasfile} >&! $log
     # for surface obs, run obs2ioda for prepbufr without additional QC
     mkdir -p sfc
     cd sfc
     ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXE} ./
     ./${obs2iodaEXE} -e h5 ${noGSIQCFilters} ../${gdasfile} >&! ../logs/log-converter_sfc
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
     ./${obs2iodaEXE} -e h5 ${gdasfile} >&! $log
   else
     ./${obs2iodaEXE} -e h5 ${gdasfile} >&! $log
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
unset nonomatch

if ( "${convertToIODAObservations}" =~ *"gnssaro"* ) then
  # AROFormat selects which converter script/file glob to use; both scripts live in
  # the same AROConverterBuildDir (see initialize/framework/Build.py)
  if ( "${AROFormat}" == bufr ) then
    set AROConverterScript = ${AROConverterBuildDir}/gnssaro_bufr2ioda.py
    set aroGlob = bfrPrf_*_bufr
  else
    set AROConverterScript = ${AROConverterBuildDir}/gnssaro_netcdf2ioda.py
    set aroGlob = atmPrf_*_nc
  endif
  if ( $?PYTHONPATH ) then
    setenv PYTHONPATH ${AROPyiodaconvPath}:${PYTHONPATH}
  else
    setenv PYTHONPATH ${AROPyiodaconvPath}
  endif

  # nonomatch has to stay set through the '-e' check below too, since testing '-e'
  # on the literal unexpanded pattern (when there are no matching files) would
  # otherwise re-trigger glob expansion and abort the script
  set nonomatch
  set aroFiles = ( ${aroGlob} )
  # the IODAPrefix for the gnssarobndropp2d obs space is 'gnssaro' (see observations.yaml);
  # PrepJEDI.csh expects the converted file at ${IODAPrefix}_obs_${thisValidDate}.h5
  set aroOut = gnssaro_obs_${thisValidDate}.h5
  set aroLog = logs/log-converter_gnssaro

  if ( -e ${aroFiles[1]} ) then
    echo "Running ${AROConverterScript} for ${#aroFiles} ARO profile file(s)"
    python3 ${AROConverterScript} -i ${aroFiles} -o ${aroOut} -d ${thisValidDate} >&! ${aroLog}
    if ( $status != 0 || ! -e ${aroOut} ) then
      echo "$0 (ERROR): Pre-processing ARO observations to IODA-v3 failed" > ./FAIL-converter_gnssaro
      exit 1
    endif
    rm -f ${aroFiles}
  else
    echo "$0 (INFO): no ARO profile files found for ${thisValidDate}, skipping gnssaro conversion"
  endif
  unset nonomatch
endif

if ( "${convertToIODAObservations}" =~ *"cris"* ) then

# Name update
set NameUpdate = ( \
    cris_npp \
    cris_n20 \
    cris_n21 \
)

foreach ty ( ${NameUpdate} )
  echo 'begin NameUpdate' $ty
  if ( -f ${ty}_obs_${thisValidDate}.h5 ) then
    #if ( ${ty} =~ *"cris"* && ${ccyy} >= 2021 ) then
    if ( ${ccyy} >= 2021 ) then
       if ( ${ty} == "cris_npp" ) set tyy = "cris-fsr_npp"
       if ( ${ty} == "cris_n20" ) set tyy = "cris-fsr_n20"
       if ( ${ty} == "cris_n21" ) set tyy = "cris-fsr_n21"
       mv -f ${ty}_obs_${thisValidDate}.h5 ${tyy}_obs_${thisValidDate}.h5
    endif
  endif
  echo 'end of NameUpdate' $ty
end
endif

date

touch CONVERTSUCCESS

exit 0
