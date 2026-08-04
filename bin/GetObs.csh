#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Get observations for a cold start experiment
# from the NCEP FTP BUFR/PrepBUFR files or GDEX archived NCEP BUFR files

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
source config/auto/workflow.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`

source ./bin/getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set ccyy = `echo ${thisValidDate} | cut -c 1-4`
set hh = `echo ${thisValidDate} | cut -c 9-10`

set self_WorkDir = "${ExperimentDirectory}/"`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# ================================================================================================

set dataRoot = /glade/campaign/collections
set defaultBUFRDirectory = $dataRoot/rda/data/d735000
set satwndBUFRDirectory = $dataRoot/rda/data/d351000
set PrepBUFRDirectory = $dataRoot/rda/data/d337000

foreach inst ( ${convertToIODAObservations} )
  if ( ${inst} == gnssaro ) then
    # ARO (airborne GNSS-RO) is always fetched from the UCSD/SIO AGS near-real-time
    # archive, regardless of ${observations__resource}, so it can be combined with
    # BUFR-sourced obs types pulled from GDEXOnline/NCEPFTPOnline in the same experiment.
    echo "Getting ${inst} from AGS (UCSD/SIO airborne GNSS-RO archive), source=${AROSource} format=${AROFormat}"
    set AGSBaseURL = https://agsweb.ucsd.edu/gnss-aro

    if ( "${AROFormat}" == bufr ) then
      set aroPrefix = bfrPrf
      set aroExt = _bufr
    else
      set aroPrefix = atmPrf
      set aroExt = _nc
    endif

    # assimilation window kept for this cycle: [thisValidDate-half, thisValidDate+half]
    @ aroHalfWindowHR = ${AROWindowHours} / 2

    # download search span: pad by a full extra day on each side beyond the kept
    # window, so an adjacent IOP/flight dated a day off from its actual profile
    # timestamps (e.g. a mission that started/ended near a day boundary) still gets
    # fetched. This only widens what GetObs.csh downloads; organize_data.py still
    # only *keeps* profiles strictly inside +/-AROWindowHours/2, so cycles never
    # overlap in what's actually processed.
    @ aroSearchMarginHR = ${aroHalfWindowHR} + 24
    set aroSearchPrevDate = `$advanceCYMDH ${thisValidDate} -${aroSearchMarginHR}`
    set aroSearchNextDate = `$advanceCYMDH ${thisValidDate} ${aroSearchMarginHR}`
    set aroPrevDay = `echo ${aroSearchPrevDate} | cut -c 1-8`
    set aroNextDay = `echo ${aroSearchNextDate} | cut -c 1-8`

    set aroStageDir = aro_staging
    rm -rf ${aroStageDir}
    mkdir -p ${aroStageDir}

    if ( "${AROSource}" == postProc ) then
      # postProc: a fixed, dated re-processed release (CODE final GNSS clocks; see
      # https://agsweb.ucsd.edu/gnss-aro/ar<ccyy>/readme.txt), organized as one tarball
      # per flight/aircraft/version under AROPostProcRelease (e.g. ar2026/postProc_20260528
      # -- note the flights inside can predate 2026, the release directory name is fixed
      # and not derived from each profile's own date). Two retrieval versions coexist
      # (AROVersion); NRT below is only ever published as 0027.0004.
      set aroDirURL = ${AGSBaseURL}/${AROPostProcRelease}
      set aroDay = ${aroPrevDay}
      while ( 1 )
        set aroCCYY = `echo ${aroDay} | cut -c 1-4`
        set aroDDD = `date -d ${aroDay} +%j`
        echo "Fetching ARO postProc tarballs for ${aroDay} (day ${aroDDD}) from ${aroDirURL}"
        # Fetch the directory listing once and pull matching hrefs directly instead of
        # letting 'wget -r' crawl it: this directory has 500+ entries, and recursive
        # crawling proved non-deterministic against it (observed runs that silently
        # found zero matches despite the real files being present -- reproduced by
        # running the identical 'wget -r' command back-to-back with different outcomes).
        set aroPattern = "${aroPrefix}_postProc_${aroCCYY}\.${aroDDD}_[A-Za-z0-9_]*_${AROVersion}\.tar\.gz"
        foreach aroHref ( `wget -q -O - ${aroDirURL}/ | grep -oE "${aroPattern}" | sort -u` )
          wget -q ${aroDirURL}/${aroHref} -P ${aroStageDir} >>&! log_getARO_${aroDay}
        end

        if ( "${aroDay}" == "${aroNextDay}" ) break
        set aroDay = `$advanceCYMDH ${aroDay}00 24 | cut -c 1-8`
      end

      # nonomatch has to stay set through the '-e' check below too, since testing '-e'
      # on the literal unexpanded pattern (when zero tarballs were downloaded) would
      # otherwise re-trigger glob expansion and abort the script
      set nonomatch
      foreach aroTar ( ${aroStageDir}/${aroPrefix}_postProc_*.tar.gz )
        if ( -e ${aroTar} ) tar -x -f ${aroTar} -C ${aroStageDir}
      end
      unset nonomatch
    else
      # nrt: fetch individual profile files directly from AGS's per-day level2 listing.
      # This is the actual current NRT distribution -- ar<ccyy>/nrt/*.tar.gz tarball
      # bundles exist too but lag behind and are not the authoritative source. Files
      # arrive already extracted, so no tar step is needed here.
      set aroDay = ${aroPrevDay}
      while ( 1 )
        set aroCCYY = `echo ${aroDay} | cut -c 1-4`
        set aroDDD = `date -d ${aroDay} +%j`
        set aroDirURL = ${AGSBaseURL}/${aroCCYY}/nrt/level2/${aroCCYY}.${aroDDD}
        echo "Fetching ARO profiles for ${aroDay} (day ${aroDDD}) from ${aroDirURL}"
        # same non-recursive listing-then-direct-fetch approach as the postProc branch
        # above, for the same reliability reason
        set aroPattern = "${aroPrefix}_[A-Za-z0-9_.]*${aroExt}"
        foreach aroHref ( `wget -q -O - ${aroDirURL}/ | grep -oE "${aroPattern}" | sort -u` )
          wget -q ${aroDirURL}/${aroHref} -P ${aroStageDir} >>&! log_getARO_${aroDay}
        end

        if ( "${aroDay}" == "${aroNextDay}" ) break
        set aroDay = `$advanceCYMDH ${aroDay}00 24 | cut -c 1-8`
      end
    endif

    # organize_data.py creates its per-cycle output directory relative to its own
    # CWD (not relative to -dataD), so run it from inside aroStageDir to land the
    # output at ${aroStageDir}/${thisValidDate}/ as expected below. It only keeps
    # profiles within +/-AROWindowHours/2 of this cycle (see aroSearchMarginHR above
    # for why we downloaded a wider span than that).
    cd ${aroStageDir}
    $organize_data -dataD . -d ${thisValidDate} -w ${AROWindowHours} --format ${AROFormat}
    cd ..

    if ( -d ${aroStageDir}/${thisValidDate} ) then
      mv ${aroStageDir}/${thisValidDate}/${aroPrefix}_*${aroExt} . |& grep -v "No match"
    else
      echo "$0 (WARNING): no ARO profiles found for ${thisValidDate} +/- ${aroHalfWindowHR}h"
    endif
    rm -rf ${aroStageDir}
  else if ( "${observations__resource}" == "GDEXOnline" ) then
    echo "Getting ${inst} from GDEX"
    # for satwnd observations
    if ( ${inst} == satwnd ) then
       setenv THIS_FILE gdas.${inst}.t${hh}z.${ccyymmdd}.bufr
       if ( ! -e ${THIS_FILE}) then
          echo "Source file: ${satwndBUFRDirectory}/bufr/${ccyy}/${THIS_FILE}"
          cp -p ${satwndBUFRDirectory}/bufr/${ccyy}/${THIS_FILE} .
       endif
    # for prepbufr observations
    else if ( ${inst} == prepbufr ) then
       setenv THIS_FILE prepbufr.gdas.${ccyymmdd}.t${hh}z.nr.48h
       if ( ! -e ${THIS_FILE}) then
          if ( -e ${PrepBUFRDirectory}/prep48h/${ccyy}/${THIS_FILE} ) then
             echo "Source file: ${PrepBUFRDirectory}/prep48h/${ccyy}/${THIS_FILE}"
             cp -p ${PrepBUFRDirectory}/prep48h/${ccyy}/${THIS_FILE} .
          else
             setenv THIS_FILE prepbufr.gdas.${thisValidDate}.nr
             echo "Source file: ${PrepBUFRDirectory}/prepnr/${ccyy}/${THIS_FILE}"
             cp -p ${PrepBUFRDirectory}/prepnr/${ccyy}/${THIS_FILE} .
          endif
       endif
    # for all other observations
    else
       # set the specific file to be extracted from the tar file
       setenv THIS_FILE gdas.${inst}.t${hh}z.${ccyymmdd}.bufr
       if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
          # cris file name became crisf4 since 2021
          setenv THIS_FILE gdas.${inst}f4.t${hh}z.${ccyymmdd}.bufr
       endif
       set THIS_TAR_FILE = ${defaultBUFRDirectory}/${inst}/${ccyy}/${inst}.${ccyymmdd}.tar.gz
       if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
          # cris file name became crisf4 since 2021
          set THIS_TAR_FILE = ${defaultBUFRDirectory}/${inst}/${ccyy}/${inst}f4.${ccyymmdd}.tar.gz
       endif
       # if the observation file does not exist, untar it
       # whether in the sub-directory or current directory
       if ( ! -e ${THIS_FILE}) then
          # some tar files contain sub-directory
          set THIS_TAR_DIR = ${ccyymmdd}.${inst}
          tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}
          if ( $status == 0 ) then
             echo "Source file: tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}"
             set got_file = true
             set SUB_DIR = true
          else #if ( $status != 0 ) then
             # try no sub-directory
             tar -x -f ${THIS_TAR_FILE} ${THIS_FILE}
             if ( $status == 0 ) then
                echo "Source file: tar -x -f ${THIS_TAR_FILE} ${THIS_FILE}"
                set SUB_DIR = false
                set got_file = true
             else
                set got_file = false
             endif
          endif
          # if the file was not untarred and if airs observations
          if ( ${got_file} == false && ${inst} == airsev ) then
             # try again with another dir name
             # typo in the archived directory name
             set THIS_TAR_DIR = ${ccyymmdd}.airssev
             tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}
             if ( $status == 0 ) then
                set SUB_DIR = true
                echo "Source file: tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}"
                set got_file = true
             endif
          endif
          # if the file was untarred and the sub-directory exists,
          # remove the sub-directory
          if ( ${got_file} == true ) then
             if (  ${SUB_DIR} == true ) then
                mv ${THIS_TAR_DIR}/${THIS_FILE} .
                rmdir ${THIS_TAR_DIR}
             endif
          endif
       endif # others
    endif # satwnd, prepbufr or others
  else if ( "${observations__resource}" == "NCEPFTPOnline" ) then
    echo "Getting ${inst} from the NCEP FTP"
    # url for GDAS data
    set gdas_ftp = https://nomads.ncep.noaa.gov/pub/data/nccf/com/obsproc/prod/gdas.${ccyymmdd}
    # set name for the observation type
    if ( ${inst} == prepbufr ) then
      set THIS_FILE = gdas.t${hh}z.${inst}.nr
    else if ( ${inst} == gpsro ) then
      set THIS_FILE = gdas.t${hh}z.${inst}.tm00.bufr_d.nr
    else
      set THIS_FILE = gdas.t${hh}z.${inst}.tm00.bufr_d
    endif

    # check if the observation file is available
    if ( ! -e ${THIS_FILE}) then
      set ftp_file = ${gdas_ftp}/${THIS_FILE}
      wget -S --spider $ftp_file >&! log_check_${inst}
      grep "HTTP/1.1 200 OK" log_check_${inst}
      # if the file exists then download it
      # otherwise, exit with failure
      if ( $status == 0 ) then
       echo "Downloading $ftp_file ..."
       wget -r -np -nd $ftp_file
      else
       echo "$ftp_file not available yet -- exiting"
       exit 1
      endif
    endif
  else if ( "${observations__resource}" == "PANDACArchive" ) then
    echo "$0 (INFO): ${observations__resource} must be stored locally and fully described in the YAML"
    echo "$0 (INFO): File retrieval is not supported; exiting with success"
    exit 0
  else
    echo "$0 (ERROR): ${observations__resource} is not supported; exiting with failure"
    exit 1
  endif
end

date

exit 0
