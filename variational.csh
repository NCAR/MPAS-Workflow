#!/bin/csh -f

date

# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/mpas/variables.csh
source config/builds.csh
source config/environment.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADirs[1]
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# templated variables
set self_StateDirs = ($inStateDirsTEMPLATE)
set self_StatePrefix = inStatePrefixTEMPLATE
set StreamsFileList = (${variationalStreamsFileList})

# Remove old logs
rm jedi.log*

# Remove old netcdf lock files
rm *.nc*.lock

# Remove old static fields in case this directory was used previously
rm ${localStaticFieldsPrefix}*.nc*

# ================================================================================================

set StaticFieldsDirList = ($StaticFieldsDirOuter $StaticFieldsDirInner)
set StaticFieldsFileList = ($StaticFieldsFileOuter $StaticFieldsFileInner)

# Link/copy bg from StateDirs + ensure that MPASJEDIDiagVariables are present
# ===========================================================================
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memSuffix = `${memberDir} $DAType $member "${flowMemFileFmt}"`

  ## copy static fields
  # unique StaticFieldsDir and StaticFieldsFile for each ensemble member
  # + ensures independent ivgtyp, isltyp, etc...
  # + avoids concurrent reading of StaticFieldsFile by all members
  set iMesh = 0
  foreach localStaticFieldsFile ($variationallocalStaticFieldsFileList)
    @ iMesh++

    set StaticFieldsFile = ${localStaticFieldsFile}${memSuffix}
    rm ${StaticFieldsFile}

    set StaticMemDir = `${memberDir} ens $member "${staticMemFmt}"`
    set memberStaticFieldsFile = $StaticFieldsDirList[$iMesh]${StaticMemDir}/$StaticFieldsFileList[$iMesh]
    ln -sfv ${memberStaticFieldsFile} ${StaticFieldsFile}${OrigFileSuffix}
    cp -v ${memberStaticFieldsFile} ${StaticFieldsFile}
  end

  # TODO(JJG): centralize this directory name construction (cycle.csh?)
  set other = $self_StateDirs[$member]
  set bg = $CyclingDAInDirs[$member]
  set an = $CyclingDAOutDirs[$member]
  mkdir -p ${bg}
  mkdir -p ${an}

  set bgFileOther = ${other}/${self_StatePrefix}.$fileDate.nc
  set bgFile = ${bg}/${BGFilePrefix}.$fileDate.nc

  rm ${bgFile}${OrigFileSuffix} ${bgFile}
  ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
  cp -v ${bgFileOther} ${bgFile}

  # Remove existing analysis file, then link to bg file
  # ===================================================
  set anFile = ${an}/${ANFilePrefix}.$fileDate.nc
  rm ${anFile}
  ln -sfv ${bgFile} ${anFile}

  # Copy diagnostic variables used in DA to bg (if needed)
  # ======================================================
  set copyDiags = 0
  foreach var ({$MPASJEDIDiagVariables})
    echo "Checking for presence of variable ($var) in ${bgFileOther}"
    ncdump -h ${bgFileOther} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
      echo "variable ($var) not present"
    endif
  end
  if ( $copyDiags > 0 ) then
    rm ${bgFile}${OrigFileSuffix}
    cp ${bgFile} ${bgFile}${OrigFileSuffix}
    set diagFile = ${other}/${DIAGFilePrefix}.$fileDate.nc
    ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${bgFile}
  endif

  # use this background as the TemplateFieldsFileOuter for this member
  rm ${TemplateFieldsFileOuter}${memSuffix}
  ln -sfv ${bgFile} ${TemplateFieldsFileOuter}${memSuffix}

  # use localStaticFieldsFileInner as the TemplateFieldsFileInner
  # NOTE: not perfect for EDA if static fields differ between members,
  #       but dual-res EDA not working yet anyway
  if ($MPASnCellsOuter != $MPASnCellsInner) then
    set tFile = ${TemplateFieldsFileInner}${memSuffix}
    rm $tFile

    #modify "Inner" initial forecast file
    # TODO: capture the naming convention for FirstCyclingFCDir somewhere else
    set memDir = `${memberDir} $DAType 1`
    set FirstCyclingFCDir = ${CyclingFCWorkDir}/${prevFirstCycleDate}${memDir}/Inner
    cp -v ${FirstCyclingFCDir}/${self_StatePrefix}.${FirstFileDate}.nc $tFile

    # modify xtime
    echo "${updateXTIME} $tFile ${thisCycleDate}"
    ${updateXTIME} $tFile ${thisCycleDate}
  endif

  if (${memSuffix} == "") then
    foreach StreamsFile_ ($StreamsFileList)
      sed -i 's@TemplateFieldsMember@@' ${StreamsFile_}
    end
    sed -i 's@StreamsFileMember@@' $appyaml
  else
    foreach StreamsFile_ ($StreamsFileList)
      cp ${StreamsFile_} ${StreamsFile_}${memSuffix}
      sed -i 's@TemplateFieldsMember@'${memSuffix}'@' ${StreamsFile_}${memSuffix}
    end
    sed -i 's@StreamsFileMember@'${memSuffix}'@' member_${member}.yaml
  endif

  @ member++
end


# Run the executable
# ==================
ln -sfv ${VariationalBuildDir}/${VariationalEXE} ./
mpiexec ./${VariationalEXE} $appyaml ./jedi.log >& jedi.log.all

#rm ${TemplateFieldsFileInner}

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ./${VariationalEXE} $appyaml ./jedi.log


# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
endif

set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memSuffix = `${memberDir} $DAType $member "${flowMemFileFmt}"`

  ## remove hard static fields file(s)
  set iMesh = 0
  foreach localStaticFieldsFile ($variationallocalStaticFieldsFileList)
    @ iMesh++
    set StaticFieldsFile = ${localStaticFieldsFile}${memSuffix}
    rm ${StaticFieldsFile}
  end

  ## mv linked static fields file to previously deleted hard file location
  # note: must be in separate loop from above to avoid deletion in single-mesh DA
  foreach localStaticFieldsFile ($variationallocalStaticFieldsFileList)
    @ iMesh++
    set StaticFieldsFile = ${localStaticFieldsFile}${memSuffix}
    mv ${StaticFieldsFile}${OrigFileSuffix} ${StaticFieldsFile}
  end

  @ member++
end

# Remove netcdf lock files
rm *.nc*.lock

date

exit 0
