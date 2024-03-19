#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

source config/auto/firstbackground.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/workflow.csh
source config/auto/build.csh

set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source ./bin/getCycleVars.csh

set member = 1
while ( $member <= $nMembers )
  echo ""
  echo ""
      find $CyclingFCDirs[$member] -mindepth 0 -maxdepth 0 > /dev/null
      if ($? == 0) then
        rm -r $CyclingFCDirs[$member]
      endif
      mkdir -p $CyclingFCDirs[$member]

      # Outer loop mesh
      set fcFile = $CyclingFCDirs[$member]/${FCFilePrefix}.${nextFirstFileDate}.nc
      set InitialMemberFC = "$firstbackground__directoryOuter"`${memberDir} 2 $member "${firstbackground__memberFormatOuter}"`
      ln -sfv ${InitialMemberFC}/${firstbackground__filePrefixOuter}.*.nc $CyclingFCDirs[$member]/.
      # Handling double/single precision files
      foreach file ($CyclingFCDirs[$member]/*.nc)
        set varinfo = `ncdump -h ${file} | grep surface_pressure`
        if ( "$varinfo" =~ "*double*" ) then
           if ( "$bundlePrecision" == "single" ) then
              mv ${file} ${file}${OrigFileSuffix}
              ncpdq -5 --pck_map=dbl_flt ${file}${OrigFileSuffix} ${file}
           endif
        else if ( "$varinfo" =~ "*float*" ) then
           if ( "$bundlePrecision" == "double" ) then
              mv ${file} ${file}${OrigFileSuffix}
              ncpdq -5 --pck_map=flt_dbl ${file}${OrigFileSuffix} ${file}
           endif
        else
           echo "netCDF file Error: ${fcFile}${OrigFileSuffix}"
        endif
      end

      # Inner loop mesh
      if ($nCellsOuter != $nCellsInner) then
        echo ""
        set innerFCDir = $CyclingFCDirs[$member]/Inner
        mkdir -p ${innerFCDir}
        set fcFile = $innerFCDir/${FCFilePrefix}.${nextFirstFileDate}.nc
        set InitialMemberFC = "$firstbackground__directoryInner"`${memberDir} 2 $member "${firstbackground__memberFormatInner}"`
        ln -sfv ${InitialMemberFC}/${firstbackground__filePrefixInner}.${nextFirstFileDate}.nc ${fcFile}${OrigFileSuffix}
        set varinfo = `ncdump -h ${fcFile}${OrigFileSuffix} | grep surface_pressure`
        if ( "$varinfo" =~ "*double*" ) then
           if ( "$bundlePrecision" == "single" ) then
              ncpdq -5 --pck_map=dbl_flt ${fcFile}${OrigFileSuffix} ${fcFile}
           else
              mv ${fcFile}${OrigFileSuffix} ${fcFile}
           endif
        else if ( "$varinfo" =~ "*float*" ) then
           if ( "$bundlePrecision" == "double" ) then
              ncpdq -5 --pck_map=flt_dbl ${fcFile}${OrigFileSuffix} ${fcFile}
           else
              mv ${fcFile}${OrigFileSuffix} ${fcFile}
           endif
        else
           echo "netCDF file Error: ${fcFile}${OrigFileSuffix}"
        endif
      endif

  @ member++
end

exit 0
