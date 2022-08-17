#!/bin/csh -f
#Convert CISL RDA archived NCEP BUFR files to IODA-v2 format based on Jamie Bresch (NCAR/MMM) script rda_obs2ioda.csh

# Process arguments
# =================
## args
# ArgWorkDir: my location
set ArgWorkDir = "$1"

date

# Setup environment
# =================
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set ccyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c1-4`
set mmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c5-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

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

# write out hourly files for IASI
setenv SPLIThourly "-split"

# flag to de-activate additional QC for conventional
# observations as in GSI
setenv noGSIQCFilters "-noqc"

foreach gdasfile ( *"gdas"* )
   echo "Running ${obs2iodaEXE} for ${gdasfile}"
   # link SpcCoeff files for converting IR radiances to brightness temperature
   if ( ${gdasfile} =~ *"cris"* && ${ccyy} >= '2021' ) then
     ln -sf ${CRTMTABLES}/cris-fsr431_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/cris-fsr431_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
   else if ( ${gdasfile} =~ *"cris"* && ${ccyy} < '2021' ) then
     ln -sf ${CRTMTABLES}/cris399_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/cris399_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
   else if ( ${gdasfile} =~ *"mtiasi"* ) then
     ln -sf ${CRTMTABLES}/iasi616_metop-a.SpcCoeff.bin  ./iasi_metop-a.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/iasi616_metop-b.SpcCoeff.bin  ./iasi_metop-b.SpcCoeff.bin
     ln -sf ${CRTMTABLES}/iasi616_metop-c.SpcCoeff.bin  ./iasi_metop-c.SpcCoeff.bin
   endif

   # Run the obs2ioda executable to convert files from BUFR to IODA-v2
   # ==================
   rm ./${obs2iodaEXE}
   ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXE} ./
   if ( ${gdasfile} =~ *"mtiasi"* ) then
     ./${obs2iodaEXE} ${SPLIThourly} ${gdasfile} >&! log_${gdasfile}
   else if ( ${gdasfile} =~ *"prepbufr"* ) then
     # run obs2ioda for preburf with additional QC as in GSI
     ./${obs2iodaEXE} ${gdasfile} >&! log_${gdasfile}
     # for surface obs, run obs2ioda for prepbufr without additional QC
     mkdir -p sfc
     cd sfc
     ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXE} ./
     ./${obs2iodaEXE} ${noGSIQCFilters} ../${gdasfile} >&! log_sfc
     # replace surface obs file with file created without additional QC
     mv sfc_obs_${thisCycleDate}.h5 ../sfc_obs_${thisCycleDate}.h5
     cd ..
     rm -rf sfc
   else
     ./${obs2iodaEXE} ${gdasfile} >&! log_${gdasfile}
   endif
   # Check status
   # ============
   grep "all done!" log_${gdasfile}
   if ( $status != 0 ) then
     echo "$0 (ERROR): Pre-processing observations to IODA-v2 failed" > ./FAIL-converter
     exit 1
   endif
  # remove BURF/PrepBUFR files
  rm -rf $gdasfile
end # gdasfile loop

if ( "${convertToIODAObservations}" =~ *"prepbufr"* || "${convertToIODAObservations}" =~ *"satwnd"* ) then
  # Run the ioda-upgrade executable to upgrade to get string station_id and string variable_names
  # ==================
  # need to change to mainScriptDir in order for environmentJEDI.csh to be sourced
  cd ${mainScriptDir}
  source config/environmentJEDI.csh
  cd -
  rm ./${iodaupgradeEXE}
  ln -sfv ${iodaupgradeBuildDir}/${iodaupgradeEXE} ./
  set types = ( aircraft ascat profiler satwind sfc sondes satwnd )
  foreach ty ( ${types} )
    if ( -f ${ty}_obs_${thisValidDate}.h5 ) then
      set ty_obs = ${ty}_obs_${thisValidDate}.h5
      set ty_obs_base = `echo "$ty_obs" | cut -d'.' -f1`
      ./${iodaupgradeEXE} ${ty_obs} ${ty_obs_base}_tmp.h5 >&! log_${ty}_upgrade
      rm -rf $ty_obs
      mv ${ty_obs_base}_tmp.h5 $ty_obs
      # Check status
      # ============
      grep "Success!" log_${ty}_upgrade
      if ( $status != 0 ) then
        echo "$0 (ERROR): ioda-upgrade failed for $ty" > ./FAIL-${ty}_upgrade
        exit 1
      endif
    endif
  end
endif

date

exit 0
