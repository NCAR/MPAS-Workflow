#!/bin/csh -f

#TODO: move this script functionality and relevent control's to python + maybe yaml

# Perform preparation for the enkf application
# + background ensemble
# + localization

date

# Process arguments
# =================
## args

# None

# Setup environment
# =================
source config/tools.csh
source config/auto/experiment.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/observations.csh
source config/auto/staticstream.csh
source config/auto/enkf.csh
source config/auto/workflow.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# other static variables
set self_WindowHR = ${CyclingWindowHR}
set self_StateDirs = ($prevCyclingFCDirs)
set self_StatePrefix = ${FCFilePrefix}

# Remove old netcdf lock files
rm *.nc*.lock

# Remove old static fields in case this directory was used previously
rm ${localStaticFieldsPrefix}*.nc*

# ==================================================================================================

# ========================================
# Member-dependent Observation Directories
# ========================================
#TODO: enable behavior to use member-specific directories?
set member = 1
while ( $member <= ${nMembers} )
  set memDir = `${memberDir} $nMembers $member`
  mkdir -p ${OutDBDir}${memDir}
  @ member++
end


# ============================
# EnKF YAML preparation
# ============================

echo "Starting YAML preparation stage"

# Rename appyaml generated by a previous preparation script
# =========================================================
rm prevPrep.yaml
cp $appyaml prevPrep.yaml
set prevYAML = $appyaml

# Analysis directory
# ==================
sed -i 's@{{anStatePrefix}}@'${ANFilePrefix}'@g' $prevYAML
sed -i 's@{{anStateDir}}@'${self_WorkDir}'/'${analysisSubDir}'@g' $prevYAML

# Solver
# ==================
sed -i 's@{{localEnsembleDASolver}}@'${solver}'@g' $prevYAML

# TODO:
# Ensemble background members
# ===========================
set yamlFiles = enkfs.txt
echo $appyaml > $yamlFiles
## yaml indentation
set nEnsIndent = 2

## members: 'background.members from template'

# performs sed substitution for EnsembleMembers
set enspbmemsed = EnsembleMembers

@ dateOffset = ${self_WindowHR} + ${ensPbOffsetHR}
set prevDateTime = `$advanceCYMDH ${thisValidDate} -${dateOffset}`

# substitutions
# + previous forecast initilization date-time
# + ExperimentDirectory for EDA applications that use their own ensemble
set dir0 = `echo "${ensPbDir0}" \
            | sed 's@{{prevDateTime}}@'${prevDateTime}'@' \
            | sed 's@{{ExperimentDirectory}}@'${ExperimentDirectory}'@' \
           `
set dir1 = `echo "${ensPbDir1}" \
            | sed 's@{{prevDateTime}}@'${prevDateTime}'@'\
           `

#set dir0 = "`echo "${dir0}" | sed 's@{{ExperimentDirectory}}@'${ExperimentDirectory}'@'`"

# substitute Jb members
setenv myCommand "${substituteEnsembleBTemplate} ${dir0} ${dir1} ${ensPbMemPrefix} ${ensPbFilePrefix}.${thisMPASFileDate}.nc ${ensPbMemNDigits} ${ensPbNMembers} $yamlFiles ${enspbmemsed} ${nEnsIndent} False"

echo "$myCommand"
#${substituteEnsembleBTemplate} "${ensPbDir0}" "${ensPbDir1}" ${ensPbMemPrefix} ${ensPbFilePrefix}.${thisMPASFileDate}.nc ${ensPbMemNDigits} ${ensPbNMembers} $yamlFiles ${enspbmemsed} ${nEnsIndent} $SelfExclusion

${myCommand}

rm $yamlFiles

if ($status != 0) then
  echo "$0 (ERROR): failed to substitute ${enspbmemsed}" > ./FAIL
  exit 1
endif

# ObsLocalization
# ===============
sed -i 's@{{horizontalLocalizationMethod}}@'"${horizontalLocalizationMethod}"'@' $prevYAML
sed -i 's@{{horizontalLocalizationLengthscale}}@'${horizontalLocalizationLengthscale}'@' $prevYAML
sed -i 's@{{verticalLocalizationFunction}}@'"${verticalLocalizationFunction}"'@' $prevYAML
sed -i 's@{{verticalLocalizationLengthscale}}@'${verticalLocalizationLengthscale}'@' $prevYAML

# Jo term (member dependence)
# ===========================

# eliminate member-specific file output directory substitutions
sed -i 's@{{MemberDir}}@@g' $prevYAML

echo "Completed YAML preparation stage"

date

echo "Starting model state preparation stage"


# TODO: modify below, do not loop over members, no memSuffix needed

# ====================================
# Input/Output model state preparation
# ====================================

set member = 1
while ( $member <= ${nMembers} )
  # TODO(JJG): centralize this directory name construction (cycle.csh?)
  set other = $self_StateDirs[$member]
  set bg = $CyclingDAInDirs[$member]
  mkdir -p ${bg}

  # Link bg from StateDirs
  # ======================
  set bgFileOther = ${other}/${self_StatePrefix}.$thisMPASFileDate.nc
  set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc

  rm ${bgFile}${OrigFileSuffix} ${bgFile}
  ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
  ln -sfv ${bgFileOther} ${bgFile}

  # determine analysis output precision
  ncdump -h ${bgFile} | grep uReconstruct | grep double
  if ($status == 0) then
    set analysisPrecision=double
  else
    ncdump -h ${bgFile} | grep uReconstruct | grep float
    if ($status == 0) then
      set analysisPrecision=single
    else
      echo "ERROR in $0 : cannot determine analysis precision" > ./FAIL
      exit 1
    endif
  endif

  # Remove existing analysis file, make full copy from bg file
  # ==========================================================
  set an = $CyclingDAOutDirs[$member]
  mkdir -p ${an}
  set anFile = ${an}/${ANFilePrefix}.$thisMPASFileDate.nc
  rm ${anFile}
  cp -v ${bgFile} ${anFile}

  @ member++
end

# get source static fields
set StaticFieldsDirList = ($StaticFieldsDirOuter)
set StaticFieldsFileList = ($StaticFieldsFileOuter)

set member = 1
while ( $member <= 1 )
  set memSuffix = ""

  ## copy static fields
  # unique StaticFieldsDir and StaticFieldsFile for each ensemble member
  # + ensures independent ivgtyp, isltyp, etc...
  # + avoids concurrent reading of StaticFieldsFile by all members
  set iMesh = 0
  foreach localStaticFieldsFile ($localStaticFieldsFileList)
    @ iMesh++

    set localStatic = ${localStaticFieldsFile}${memSuffix}
    rm ${localStatic}

    set staticMemDir = `${memberDir} 1 $member "${staticMemFmt}"`
    set memberStaticFieldsFile = $StaticFieldsDirList[$iMesh]${staticMemDir}/$StaticFieldsFileList[$iMesh]
    ln -sfv ${memberStaticFieldsFile} ${localStatic}
  end

  # use the 1st member background as the TemplateFieldsFileOuter
  set bg = $CyclingDAInDirs[$member]
  set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc

  rm ${TemplateFieldsFileOuter}${memSuffix}
  ln -sfv ${bgFile} ${TemplateFieldsFileOuter}${memSuffix}

  foreach StreamsFile_ ($StreamsFileList)
    if (${memSuffix} != "") then
      cp ${StreamsFile_} ${StreamsFile_}${memSuffix}
    endif
    sed -i 's@{{TemplateFieldsMember}}@'${memSuffix}'@' ${StreamsFile_}${memSuffix}
    sed -i 's@{{analysisPRECISION}}@'${analysisPrecision}'@' ${StreamsFile_}${memSuffix}
  end
  sed -i 's@{{StreamsFileMember}}@'${memSuffix}'@' $appyaml

  @ member++
end

echo "Completed model state preparation stage"

date

exit 0
