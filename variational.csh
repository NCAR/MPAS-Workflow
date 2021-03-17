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
    rm ${bgFile}${OrigFileSuffix}
    cp ${bgFile} ${bgFile}${OrigFileSuffix}
    set diagFile = ${other}/${DIAGFilePrefix}.$fileDate.nc
    ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${bgFile}
  endif

  @ member++
end

# use one of the backgrounds as the TemplateFieldsFileOuter
rm ${TemplateFieldsFileOuter}
ln -sfv ${bgFile} ${TemplateFieldsFileOuter}

# use localStaticFieldsFileInner as the TemplateFieldsFileInner
if ($MPASnCellsOuter != $MPASnCellsInner) then
  rm ${TemplateFieldsFileInner}

#  #use static fields directly (wrong date)
#  ln -sfv ${localStaticFieldsFileInner} ${TemplateFieldsFileInner}

#  #modify static fields (missing some variables needed in inner loop?)
#  cp ${localStaticFieldsFileInner} ${TemplateFieldsFileInner}

  #modify "Inner" initial forecast file
  set memDir = `${memberDir} $DAType 1`
  set FirstCyclingFCDir = ${CyclingFCWorkDir}/${prevFirstCycleDate}${memDir}/Inner
  cp -v ${FirstCyclingFCDir}/${self_StatePrefix}.${FirstFileDate}.nc ${TemplateFieldsFileInner}

  # modify xtime
  ${updateXTIME} ${TemplateFieldsFileInner} ${thisCycleDate}
endif

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

## change static fields to a link, keeping for transparency
set iMesh = 0
foreach localStaticFieldsFile ($variationallocalStaticFieldsFileList)
  @ iMesh++
  rm ${localStaticFieldsFile}
  mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}
end

date

exit 0
