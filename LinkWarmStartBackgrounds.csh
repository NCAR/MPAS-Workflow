#!/bin/csh -f
source config/model.csh
source config/workflow.csh
source config/experiment.csh

source config/firstbackground.csh

set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source ./getCycleVars.csh

## next date from which first background is initialized
set nextFirstCycleDate = `$advanceCYMDH ${FirstCycleDate} +${CyclingWindowHR}`
setenv nextFirstCycleDate ${nextFirstCycleDate}
set Nyy = `echo ${nextFirstCycleDate} | cut -c 1-4`
set Nmm = `echo ${nextFirstCycleDate} | cut -c 5-6`
set Ndd = `echo ${nextFirstCycleDate} | cut -c 7-8`
set Nhh = `echo ${nextFirstCycleDate} | cut -c 9-10`
set nextFirstFileDate = ${Nyy}-${Nmm}-${Ndd}_${Nhh}.00.00

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