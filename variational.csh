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

# ================================================================================================

## copy static fields
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set StaticFieldsDirList = ($StaticFieldsDirOuter $StaticFieldsDirInner)
set StaticFieldsFileList = ($StaticFieldsFileOuter $StaticFieldsFileInner)
set iMesh = 0
foreach localStaticFieldsFile ($variationallocalStaticFieldsFileList)
  @ iMesh++
  rm ${localStaticFieldsFile}

  #TODO: StaticFieldsDir needs to be unique for each ensemble member (ivgtyp, isltyp, etc...)
  set StaticMemDir = `${memberDir} ens 1 "${staticMemFmt}"`
  set memberStaticFieldsFile = $StaticFieldsDirList[$iMesh]${StaticMemDir}/$StaticFieldsFileList[$iMesh]
  ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
  cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}
end

# Link/copy bg from StateDirs + ensure that MPASJEDIDiagVariables are present
# ===========================================================================
set member = 1
while ( $member <= ${nEnsDAMembers} )
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
    ncdump -h ${bgFileOther} | grep -q $var
    if ( $status != 0 ) then
      @ copyDiags++
      echo "Copying MPASJEDIDiagVariables to background state"
    endif 
  end
  if ( $copyDiags > 0 ) then
    set diagFile = ${other}/${DIAGFilePrefix}.$fileDate.nc
    ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${bgFile}
    rm ${bgFile}${OrigFileSuffix}
    cp ${bgFile} ${bgFile}${OrigFileSuffix}
  endif

  # use this background as the TemplateFieldsFileOuter for this member
  set memSuffix = `${memberDir} $DAType $member "${flowMemFileFmt}"`
  rm ${TemplateFieldsFileOuter}${memSuffix}
  ln -sfv ${bgFile} ${TemplateFieldsFileOuter}${memSuffix}
  if (${memSuffix} == "") then
    foreach StreamsFile_ ($StreamsFileList)
      sed -i 's@TemplateFieldsMember@@' ${StreamsFile_}
    end
    sed -i 's@StreamsFileMember@@' $appyaml
  else
    # NOTE: only works for single-mesh, i.e., same between inner/outer loops
    cp $OuterStreamsFile $OuterStreamsFile${memSuffix}
    sed -i 's@TemplateFieldsMember@'${memSuffix}'@' $OuterStreamsFile${memSuffix}
    sed -i 's@StreamsFileMember@'${memSuffix}'@' member_${member}.yaml
  endif

  @ member++
end

# use localStaticFieldsFileInner as the TemplateFieldsFileInner
# NOTE: does not work for EDA
if ($MPASnCellsOuter != $MPASnCellsInner) then
  rm ${TemplateFieldsFileInner}
  ln -sfv ${localStaticFieldsFileInner} ${TemplateFieldsFileInner}
endif

# Run the executable
# ==================
ln -sfv ${VariationalBuildDir}/${VariationalEXE} ./
mpiexec ./${VariationalEXE} $appyaml ./jedi.log >& jedi.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ./${VariationalEXE} $appyaml ./jedi.log


# Check status
# ============
#grep "Finished running the atmosphere core" log.atmosphere.0000.out
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  touch ./FAIL
  echo "ERROR in $0 : jedi application failed" >> ./FAIL
  exit 1
endif

## change static fields to a link, keeping for transparency
set iMesh = 0
foreach localStaticFieldsFile ($variationallocalStaticFieldsFileList)
  @ iMesh++
  rm ${localStaticFieldsFile}
  rm ${localStaticFieldsFile}${OrigFileSuffix}
  set StaticMemDir = `${memberDir} ens 1 "${staticMemFmt}"`
  set memberStaticFieldsFile = $StaticFieldsDirList[$iMesh]${StaticMemDir}/$StaticFieldsFileList[$iMesh]
  ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}
end

date

exit 0
