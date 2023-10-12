#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

source config/auto/firstbackground.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/workflow.csh

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
      ln -sfv ${InitialMemberFC}/${firstbackground__filePrefixOuter}.${nextFirstFileDate}.nc ${fcFile}${OrigFileSuffix}
      ncdump -h ${fcFile}${OrigFileSuffix} | grep uReconstruct | grep float
      if ($status == 0) then  # Double 
         ncpdq -5 --pck_map=dbl_flt ${fcFile}${OrigFileSuffix} ${fcFile}
      else
         cp ${fcFile}${OrigFileSuffix} ${fcFile}
      endif

      # Inner loop mesh
      if ($nCellsOuter != $nCellsInner) then
        echo ""
        set innerFCDir = $CyclingFCDirs[$member]/Inner
        mkdir -p ${innerFCDir}
        set fcFile = $innerFCDir/${FCFilePrefix}.${nextFirstFileDate}.nc
        set InitialMemberFC = "$firstbackground__directoryInner"`${memberDir} 2 $member "${firstbackground__memberFormatInner}"`
        ln -sfv ${InitialMemberFC}/${firstbackground__filePrefixInner}.${nextFirstFileDate}.nc ${fcFile}${OrigFileSuffix}
        # rm ${fcFile}
        cp ${fcFile}${OrigFileSuffix} ${fcFile}
      endif

  @ member++
end

exit 0
