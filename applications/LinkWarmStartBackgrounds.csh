#!/bin/csh -f

source config/experiment.csh
source config/auto/firstbackground.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/workflow.csh

set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source ./getCycleVars.csh

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
      set directoryOuter = `echo "${firstbackground__directoryOuter}" \
        | sed 's@{{FirstCycleDate}}@'$FirstCycleDate'@' \
        `
      set fcFile = $CyclingFCDirs[$member]/${FCFilePrefix}.${nextFirstFileDate}.nc
      set InitialMemberFC = "$directoryOuter"`${memberDir} 2 $member "${firstbackground__memberFormatOuter}"`
      ln -sfv ${InitialMemberFC}/${firstbackground__filePrefixOuter}.${nextFirstFileDate}.nc ${fcFile}${OrigFileSuffix}
      # rm ${fcFile}
      cp ${fcFile}${OrigFileSuffix} ${fcFile}

      # Inner loop mesh
      if ($nCellsOuter != $nCellsInner) then
        echo ""
        set innerFCDir = $CyclingFCDirs[$member]/Inner
        mkdir -p ${innerFCDir}
        set directoryInner = `echo "${firstbackground__directoryInner}" \
          | sed 's@{{FirstCycleDate}}@'$FirstCycleDate'@' \
          `
        set fcFile = $innerFCDir/${FCFilePrefix}.${nextFirstFileDate}.nc
        set InitialMemberFC = "$directoryInner"`${memberDir} 2 $member "${firstbackground__memberFormatInner}"`
        ln -sfv ${InitialMemberFC}/${firstbackground__filePrefixInner}.${nextFirstFileDate}.nc ${fcFile}${OrigFileSuffix}
        # rm ${fcFile}
        cp ${fcFile}${OrigFileSuffix} ${fcFile}
      endif

  @ member++
end

exit 0
