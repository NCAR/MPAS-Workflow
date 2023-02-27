#!/bin/csh -f
#Convert CISL RDA archived NCEP BUFR files to IODA-v2 format based on Jamie Bresch (NCAR/MMM) script rda_obs2ioda.csh

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
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/observations.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`

source ./getCycleVars.csh

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
   set inst = `echo "$gdasfile" | cut -d'.' -f2`

   set log = logs/log-converter_${inst}
   rm $log

   if ( ${gdasfile} =~ *"mtiasi"* ) then
     ./${obs2iodaEXE} ${SPLIThourly} ${gdasfile} >&! $log
   else if ( ${gdasfile} =~ *"prepbufr"* ) then
     set inst = `echo "$gdasfile" | cut -d'.' -f1`
     # run obs2ioda for preburf with additional QC as in GSI
     ./${obs2iodaEXE} ${gdasfile} >&! $log
     # for surface obs, run obs2ioda for prepbufr without additional QC
     mkdir -p sfc
     cd sfc
     ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXE} ./
     ./${obs2iodaEXE} ${noGSIQCFilters} ../${gdasfile} >&! logs/log-converter_sfc
     # replace surface obs file with file created without additional QC
     mv sfc_obs_${thisCycleDate}.h5 ../sfc_obs_${thisCycleDate}.h5
     cd ..
     rm -rf sfc
   else
     ./${obs2iodaEXE} ${gdasfile} >&! $log
   endif
   # Check status
   # ============
   grep "all done!" $log
   if ( $status != 0 ) then
     echo "$0 (ERROR): Pre-processing observations to IODA-v2 failed" > ./FAIL-converter_${inst}
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
  foreach exec ($iodaUpgradeEXE1 $iodaUpgradeEXE2)
    rm ./${exec}
    ln -sfv ${iodaUpgradeBuildDir}/${exec} ./
  end

  # upgrade from IODA v1 to v2
  set V1toV2 = ( \
    aircraft \
    gnssro \
    satwind \
    satwnd \
    sfc \
    sondes \
    ascat \
    profiler \
  )
  foreach ty ( ${V1toV2} )
    if ( -f ${ty}_obs_${thisValidDate}.h5 ) then
      set ty_obs = ${ty}_obs_${thisValidDate}.h5
      set ty_obs_base = `echo "$ty_obs" | cut -d'.' -f1`

      set ii = 1
      set log = logs/log-upgrade${ii}_${ty}
      rm $log
      ./$iodaUpgradeEXE1 ${ty_obs} ${ty_obs_base}_tmp.h5 >&! $log
      rm -rf $ty_obs
      mv ${ty_obs_base}_tmp.h5 $ty_obs

      # Check status
      # ============
      grep "Success!" $log
      if ( $status != 0 ) then
        echo "$0 (ERROR): ${exec} failed for $ty" > ./FAIL-upgrade${ii}_${ty}
        exit 1
      endif
    endif
  end

  # upgrade from IODA v2 to v3
  set V2toV3 = ( $V1toV2 \
    amsua_n15 \
    amsua_n18 \
    amsua_n19 \
    amsua_aqua \
    amsua_metop-a \
    amsua_metop-b \
    amsua_metop-c \
    gnssro \
    mhs_n18 \
    mhs_n19 \
    mhs_metop-a \
    mhs_metop-b \
    mhs_metop-c \
    iasi_metop-a \
    iasi_metop-b \
    iasi_metop-c \
  )
  set iodaUpgradeV3Config = ${ConfigDir}/jedi/obsProc/ObsSpaceV2-to-V3.yaml
  foreach ty ( ${V2toV3} )
    if ( -f ${ty}_obs_${thisValidDate}.h5 ) then
      set ty_obs = ${ty}_obs_${thisValidDate}.h5
      set ty_obs_base = `echo "$ty_obs" | cut -d'.' -f1`

      set ii = 2
      set log = logs/log-upgrade${ii}_${ty}
      rm $log
      ./$iodaUpgradeEXE2 ${ty_obs} ${ty_obs_base}_tmp.h5 $iodaUpgradeV3Config >&! $log
      rm -rf $ty_obs
      mv ${ty_obs_base}_tmp.h5 $ty_obs

      # Check status
      # ============
      grep "Success!" $log
      if ( $status != 0 ) then
        echo "$0 (ERROR): ${exec} failed for $ty" > ./FAIL-upgrade${ii}_${ty}
        exit 1
      endif

    endif
  end
endif

date

touch CONVERTSUCCESS

exit 0
