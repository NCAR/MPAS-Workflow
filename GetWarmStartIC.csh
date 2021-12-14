#!/bin/csh -f
source config/filestructure.csh
source config/modeldata.csh
source config/experiment.csh

set thisCycleDate = $FirstCycleDate
set thisValidDate = $thisCycleDate
source ./getCycleVars.csh

set member = 1
while ( $member <= ${nEnsDAMembers} )
  echo ""
  echo ""  
      find $CyclingFCDirs[$member] -mindepth 0 -maxdepth 0 > /dev/null
      if ($? == 0) then
        rm -r $CyclingFCDirs[$member]
      endif
      mkdir -p $CyclingFCDirs[$member]
      
       # Outer loop mesh
      set fcFile = $CyclingFCDirs[$member]/${FCFilePrefix}.${nextFirstFileDate}.nc      
      set InitialMemberFC = "$firstFCDirOuter"`${memberDir} ens $member "${firstFCMemFmt}"`
      ln -sfv ${InitialMemberFC}/${FCFilePrefix}.${nextFirstFileDate}.nc ${fcFile}${OrigFileSuffix}  
      # rm ${fcFile}
      cp ${fcFile}${OrigFileSuffix} ${fcFile}
      
      # Inner loop mesh
      if ($MPASnCellsOuter != $MPASnCellsInner) then
        echo ""
        set innerFCDir = $CyclingFCDirs[$member]/Inner
        mkdir -p ${innerFCDir}
        set fcFile = $innerFCDir/${FCFilePrefix}.${nextFirstFileDate}.nc
        set InitialMemberFC = "$firstFCDirOuter"`${memberDir} ens $member "${firstFCMemFmt}"`
        ln -sfv ${InitialMemberFC}/${firstFCFilePrefix}.${nextFirstFileDate}.nc ${fcFile}${OrigFileSuffix}
        # rm ${fcFile}
        cp ${fcFile}${OrigFileSuffix} ${fcFile}  
      endif
  
  @ member++
end

exit 0
