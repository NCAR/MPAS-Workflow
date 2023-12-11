#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Perform preparation for the variational application
# + iterations
# + ensemble Jb term
# + static Jb term

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
# note: not currently used, but will be for independent EDA members
set ArgMember = "$1"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

# Setup environment
# =================
source config/tools.csh
source config/auto/experiment.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/observations.csh
source config/auto/staticstream.csh
source config/auto/variational.csh
source config/auto/workflow.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# other static variables
set self_WindowHR = ${CyclingWindowHR}
set self_StateDirs = ($prevCyclingFCDirs)
set self_StatePrefix = ${FCFilePrefix}

# Remove old static fields in case this directory was used previously
rm ${localStaticFieldsPrefix}*.nc*

# ==================================================================================================

# ========================================
# Member-dependent Observation Directories
# ========================================
#TODO: Change behavior to always using member-specific directories
#      instead of only for EDA.  Will make EDA omb/oma verification easier.
set member = 1
while ( $member <= ${nMembers} )
  set memDir = `${memberDir} $nMembers $member`
  mkdir -p ${OutDBDir}${memDir}
  @ member++
end


# ============================
# Variational YAML preparation
# ============================

echo "Starting YAML preparation stage"

# Rename appyaml generated by a previous preparation script
# =========================================================
rm prevPrep.yaml
mv $appyaml prevPrep.yaml
set prevYAML = prevPrep.yaml

# Outer iterations configuration elements
# ===========================================
# performs sed substitution for VariationalIterations
set sedstring = VariationalIterations
set thisSEDF = ${sedstring}SEDF.yaml
cat >! ${thisSEDF} << EOF
/${sedstring}/c\
EOF

set nIterationsIndent = 2
set indent = "`${nSpaces} $nIterationsIndent`"
set iOuter = 0
foreach nInner ($nInnerIterations)
  @ iOuter++
  set nn = ${nInner}
cat >>! ${thisSEDF} << EOF
${indent}- <<: *iterationConfig\
EOF

  if ( $iOuter == 1 ) then
cat >>! ${thisSEDF} << EOF
${indent}  diagnostics:\
${indent}    departures: ombg\
EOF

  endif
  if ( $iOuter < $nOuterIterations ) then
    set nn = $nn\\
  endif
cat >>! ${thisSEDF} << EOF
${indent}  ninner: ${nn}
EOF

end

set thisYAML = insert${sedstring}.yaml
sed -f ${thisSEDF} $prevYAML >! $thisYAML
rm ${thisSEDF}
set prevYAML = $thisYAML


# Minimization algorithm configuration element
# ================================================
# performs sed substitution for VariationalMinimizer
set sedstring = VariationalMinimizer
set thisSEDF = ${sedstring}SEDF.yaml
cat >! ${thisSEDF} << EOF
/${sedstring}/c\
EOF

set nAlgorithmIndent = 4
set indent = "`${nSpaces} $nAlgorithmIndent`"
if ($MinimizerAlgorithm == $BlockEDA) then
cat >>! ${thisSEDF} << EOF
${indent}algorithm: $MinimizerAlgorithm\
${indent}members: $EDASize
EOF

else
cat >>! ${thisSEDF} << EOF
${indent}algorithm: $MinimizerAlgorithm
EOF

endif

set thisYAML = insert${sedstring}.yaml
sed -f ${thisSEDF} $prevYAML >! $thisYAML
rm ${thisSEDF}
set prevYAML = $thisYAML


# Analysis directory
# ==================
sed -i 's@{{anStatePrefix}}@'${ANFilePrefix}'@g' $prevYAML
sed -i 's@{{anStateDir}}@'${self_WorkDir}'/'${analysisSubDir}'@g' $prevYAML


# Hybrid Jb weights
# =================
if ( "$DAType" == "3dhybrid" ) then
  sed -i 's@{{staticCovarianceWeight}}@'${staticCovarianceWeight}'@' $prevYAML
  sed -i 's@{{ensembleCovarianceWeight}}@'${ensembleCovarianceWeight}'@' $prevYAML
endif

if ( "$DAType" == "3dhybrid-allsky" ) then
  sed -i 's@{{hybridCoefficientsDir}}@'${hybridCoefficientsDir}'@' $prevYAML
endif

# Static Jb term
# ==============
if ( "$DAType" == "3dvar" || "$DAType" =~ *"3dhybrid"* ) then
  # bumpCovControlVariables
  set Variables = ($bumpCovControlVariables)
#TODO: turn on hydrometeors in static B when applicable by uncommenting below
# This requires the bumpCov* files to include hydrometeors
#  # if any CRTM yaml section includes the *cloudyCRTMObsOperator alias, then hydrometeors
#  # must be included in both the Analysis and State variables
#  grep '*cloudyCRTMObsOperator' $prevYAML
#  if ( $status == 0 ) then
#    foreach hydro ($MPASHydroStateVariables)
#      set Variables = ($Variables $hydro)
#    end
#  endif
  set VarSub = ""
  foreach var ($Variables)
    set VarSub = "$VarSub$var,"
  end
  # remove trailing comma
  set VarSub = `echo "$VarSub" | sed 's/.$//'`
  sed -i 's@{{bumpCovControlVariables}}@'$VarSub'@' $prevYAML

  # substitute bumpCov* file descriptors
  sed -i 's@{{bumpCovPrefix}}@'${bumpCovPrefix}'@' $prevYAML
  sed -i 's@{{bumpCovDir}}@'${bumpCovDir}'@' $prevYAML
  sed -i 's@{{bumpCovStdDevFile}}@'${bumpCovStdDevFile}'@' $prevYAML
  sed -i 's@{{bumpCovVBalPrefix}}@'${bumpCovVBalPrefix}'@' $prevYAML
  sed -i 's@{{bumpCovVBalDir}}@'${bumpCovVBalDir}'@' $prevYAML
endif # 3dvar || *"3dhybrid"*


# Ensemble Jb term
# ================

if ( "$DAType" == "3denvar" || "$DAType" =~ *"3dhybrid"* || "$DAType" == "4denvar" ) then
  ## yaml indentation
  if ( "$DAType" == "3denvar" ) then
    set nEnsPbIndent = 4
  else if ( "$DAType" =~ *"3dhybrid"* ) then
    set nEnsPbIndent = 8
  else if ( "$DAType" == "4denvar" ) then
    set nEnsPbIndent = 4
  endif
  set indentPb = "`${nSpaces} $nEnsPbIndent`"

  ## localization
  sed -i 's@{{bumpLocDir}}@'${bumpLocDir}'@g' $prevYAML
  sed -i 's@{{bumpLocPrefix}}@'${bumpLocPrefix}'@g' $prevYAML

  ## inflation
  # performs sed substitution for EnsemblePbInflation
  set sedstring = EnsemblePbInflation
  set thisSEDF = ${sedstring}SEDF.yaml
  set removeInflation = 0
  if ( ${ABEInflation} == True ) then
    set inflationFields = ${CyclingABEInflationDir}/BT${ABEIChannel}_ABEIlambda.nc
    find ${inflationFields} -mindepth 0 -maxdepth 0
    if ($? > 0) then
      ## inflation file not generated because all instruments (abi, ahi?) missing at this cylce date
      #TODO: use last valid inflation factors?
      set removeInflation = 1
    else
      set thisYAML = insert${sedstring}.yaml
  #NOTE: 'stream name: control' allows for spechum and temperature inflation values to be read
  #      read directly from inflationFields without a variable transform. Also requires spechum and
  #      temperature to be in stream_list.atmosphere.control.

  cat >! ${thisSEDF} << EOF
/{{${sedstring}}}/c\
${indentPb}inflation field:\
${indentPb}  date: *analysisDate\
${indentPb}  filename: ${inflationFields}\
${indentPb}  stream name: control
EOF

      sed -f ${thisSEDF} $prevYAML >! $thisYAML
      set prevYAML = $thisYAML
    endif
  else
    set removeInflation = 1
  endif
  if ($removeInflation > 0) then
    # delete the line containing $sedstring
    sed -i '/^{{'${sedstring}'}}/d' $prevYAML
  endif
endif


# Generate individual background member yamls
# ===========================================

# Note: all yaml prep before this point must be common across EDA members

set yamlFiles = variationals.txt
set yamlFileList = ()

rm $yamlFiles
set member = 1
while ( $member <= ${nMembers} )
  set memberyaml = ${YAMLPrefix}${member}.yaml
  echo $memberyaml >> $yamlFiles
  set yamlFileList = ($yamlFileList $memberyaml)
  cp $prevYAML $memberyaml

  @ member++
end


# Ensemble Jb term (member dependent)
# ===================================

if ( "$DAType" == "3denvar" || "$DAType" =~ *"3dhybrid"* ) then
  ## members
  # + pure envar: 'background error.members from template'
  # + hybrid envar: 'background error.components[iEnsemble].covariance.members from template'
  #   where iEnsemble is the ensemble component index of the hybrid B

  # performs sed substitution for EnsemblePbMembers
  set enspbmemsed = EnsemblePbMembers

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
  setenv myCommand "${substituteEnsembleBTemplate} ${dir0} ${dir1} ${ensPbMemPrefix} ${ensPbFilePrefix}.${thisMPASFileDate}.nc ${ensPbMemNDigits} ${ensPbNMembers} $yamlFiles ${enspbmemsed} ${nEnsPbIndent} $SelfExclusion"

  echo "$myCommand"
  #${substituteEnsembleBTemplate} "${ensPbDir0}" "${ensPbDir1}" ${ensPbMemPrefix} ${ensPbFilePrefix}.${thisMPASFileDate}.nc ${ensPbMemNDigits} ${ensPbNMembers} $yamlFiles ${enspbmemsed} ${nEnsPbIndent} $SelfExclusion

  ${myCommand}

  if ($status != 0) then
    echo "$0 (ERROR): failed to substitute ${enspbmemsed}" > ./FAIL
    exit 1
  endif

endif # envar || hybrid

if ("$DAType" == "4denvar") then
  ## members
  # + pure envar: 'background error.members from template'
  # + hybrid envar: 'background error.components[iEnsemble].covariance.members from template'
  #   where iEnsemble is the ensemble component index of the hybrid B

  # performs sed substitution for EnsemblePbMembers
  set enspbmemsed = EnsemblePbMembers

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

  # substitute Jb members for 4d
  if ("$subwindow" == "3") then
    setenv myCommand "${substituteEnsembleBTemplate_4d} ${dir0} ${dir1} ${ensPbMemPrefix} ${ensPbFilePrefix}.${thisMPASFileDate1}.nc ${thisISO8601Date1} ${ensPbFilePrefix}.${thisMPASFileDate}.nc ${thisISO8601Date} ${ensPbFilePrefix}.${thisMPASFileDate3}.nc ${thisISO8601Date3} ${ensPbMemNDigits} ${ensPbNMembers} $yamlFiles ${enspbmemsed} ${nEnsPbIndent} $SelfExclusion"
  endif

  if ("$subwindow" == "1") then 
    setenv myCommand "${substituteEnsembleBTemplate_4d_7slots} ${dir0} ${dir1} ${ensPbMemPrefix} ${ensPbFilePrefix}.${thisMPASFileDate1}.nc ${thisISO8601Date1} ${ensPbFilePrefix}.${thisMPASFileDate2}.nc ${thisISO8601Date2} ${ensPbFilePrefix}.${thisMPASFileDate3}.nc ${thisISO8601Date3} ${ensPbFilePrefix}.${thisMPASFileDate}.nc ${thisISO8601Date} ${ensPbFilePrefix}.${thisMPASFileDate5}.nc ${thisISO8601Date5} ${ensPbFilePrefix}.${thisMPASFileDate6}.nc ${thisISO8601Date6} ${ensPbFilePrefix}.${thisMPASFileDate7}.nc ${thisISO8601Date7} ${ensPbMemNDigits} ${ensPbNMembers} $yamlFiles ${enspbmemsed} ${nEnsPbIndent} $SelfExclusion"
  endif

  echo "$myCommand" > ./substitute_command

  ${myCommand}

  if ($status != 0) then
    echo "$0 (ERROR): failed to substitute ${enspbmemsed}" > ./FAIL
    exit 1
  endif

endif #4denvar

rm $yamlFiles


# Jo term (member dependent)
# ==========================

set member = 1
while ( $member <= ${nMembers} )
  set memberyaml = $yamlFileList[$member]

  # member-specific state I/O and observation file output directory
  set memDir = `${memberDir} $nMembers $member`
  sed -i 's@{{MemberDir}}@'${memDir}'@g' $memberyaml

  # deterministic EnVar does not perturb observations
  if ($nMembers == 1) then
    sed -i 's@{{ObsPerturbations}}@false@g' $memberyaml
  else
    sed -i 's@{{ObsPerturbations}}@true@g' $memberyaml
  endif

  sed -i 's@{{MemberNumber}}@'$member'@g' $memberyaml
  sed -i 's@{{TotalMemberCount}}@'${nMembers}'@g' $memberyaml

  @ member++
end

echo "Completed YAML preparation stage"

date

echo "Starting model state preparation stage"

# ====================================
# Input/Output model state preparation
# ====================================

# get source static fields
set StaticFieldsDirList = ($StaticFieldsDirOuter $StaticFieldsDirInner)
set StaticFieldsFileList = ($StaticFieldsFileOuter $StaticFieldsFileInner)

set member = 1
while ( $member <= ${nMembers} )
  set memSuffix = `${memberDir} $nMembers $member "${flowMemFileFmt}"`

  ## copy static fields
  # unique StaticFieldsDir and StaticFieldsFile for each ensemble member
  # + ensures independent ivgtyp, isltyp, etc...
  # + avoids concurrent reading of StaticFieldsFile by all members
  set iMesh = 0
  foreach localStaticFieldsFile ($localStaticFieldsFileList)
    @ iMesh++

    set localStatic = ${localStaticFieldsFile}${memSuffix}
    rm ${localStatic}

    set staticMemDir = `${memberDir} 2 $member "${staticMemFmt}"`
    set memberStaticFieldsFile = $StaticFieldsDirList[$iMesh]${staticMemDir}/$StaticFieldsFileList[$iMesh]
    ln -sfv ${memberStaticFieldsFile} ${localStatic}
  end

  # TODO(JJG): centralize this directory name construction (cycle.csh?)
  set other = $self_StateDirs[$member]
  set bg = $CyclingDAInDirs[$member]
  mkdir -p ${bg}

  # Link bg from StateDirs
  # ======================
  set bgFileOther = ${other}/${self_StatePrefix}.${thisMPASFileDate}.nc
  if ( "$DAType" == "4denvar" ) then
    set bgFileOther = ${other}/${self_StatePrefix}.*.nc
  endif
  set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc

  rm ${bgFile}${OrigFileSuffix} ${bgFile}
  ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
  ln -sfv ${bgFileOther} ${bgFile}

  if ( "$DAType" == "4denvar" ) then
    # Loop over background files
    foreach bgFile ( `ls -d $bgFileOther`)
      set temp_file = `echo $bgFile | sed 's:.*/::'`
      set bgFileDate = `echo ${temp_file} | cut -c 9-27`
      ln -sfv $bgFile ${bg}/${BGFilePrefix}.${bgFileDate}.nc
    end

    set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc
  endif

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

  # use the member-specific background as the TemplateFieldsFileOuter for this member
  rm ${TemplateFieldsFileOuter}${memSuffix}
  ln -sfv ${bgFile} templateFields.${nCellsOuter}.${thisMPASFileDate}.nc${memSuffix}

  if ( "$DAType" == "4denvar" ) then
    # Loop over background files and set as the TemplateFieldsFileOuter for this member for each time
    foreach bgFile (`ls -d ${bg}/*.nc`)
      set temp_file = `echo $bgFile | sed 's:.*/::'`
      set bgFileDate = `echo ${temp_file} | cut -c 4-22`
      ln -sfv ${bgFile} templateFields.${nCellsOuter}.${bgFileDate}.nc${memSuffix}
    end
    set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc
  endif

  if ($nCellsOuter != $nCellsInner) then
    set tFile = templateFields.${nCellsInner}.${thisMPASFileDate}.nc${memSuffix}
    rm $tFile

    # use localStaticFieldsFileInner as the TemplateFieldsFileInner
    # NOTE: not perfect for EDA if static fields differ between members,
    #       but dual-res EDA not working yet anyway
    cp -v ${localStaticFieldsFileInner}${memSuffix} $tFile

    if ( "$DAType" == "4denvar" ) then
      # Loop over times and set as the TemplateFieldsFileInner for this member for each time
      foreach bgFile (`ls -d ${bg}/*.nc`)
        set temp_file = `echo $bgFile | sed 's:.*/::'`
        set bgFileDate = `echo ${temp_file} | cut -c 4-22`
        cp -v ${localStaticFieldsFileInner} templateFields.${nCellsInner}.${bgFileDate}.nc${memSuffix}
      end
      set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc
    endif 

    # modify xtime
    # TODO: handle errors from python executions, e.g.:
    # '''
    #     import netCDF4 as nc
    # ImportError: No module named netCDF4
    # '''
    # loop over times
    echo "${updateXTIME} $tFile ${thisCycleDate}"
    ${updateXTIME} $tFile ${thisCycleDate}
    if ( "$DAType" == "4denvar" ) then
      foreach tFile (`ls -d templateFields.${nCellsInner}.*.nc`)
        set temp_file = `echo $tFile | sed 's:.*/::'`
        set tFileDate = `echo ${temp_file} | cut -c 23-41`
        set tyyyy = `echo ${tFileDate}| cut -c 1-4`
        set tmm = `echo ${tFileDate}| cut -c 6-7`
        set tdd = `echo ${tFileDate}| cut -c 9-10`
        set thh = `echo ${tFileDate}| cut -c 12-13`
        echo "${updateXTIME} ${tFile} ${tyyyy}${tmm}${tdd}${thh}"
        ${updateXTIME} $tFile ${tyyyy}${tmm}${tdd}${thh}
      end
    endif
  endif

  if ($nCellsOuter != $nCellsEnsemble && $nCellsInner != $nCellsEnsemble) then
    set tFile = ${TemplateFieldsFileEnsemble}${memSuffix}
    rm $tFile

    # use localStaticFieldsFileInner as the TemplateFieldsFileInner
    cp -v ${localStaticFieldsFileInner}${memSuffix} $tFile

    # modify xtime
    # TODO: handle errors from python executions, e.g.:
    # '''
    #     import netCDF4 as nc
    # ImportError: No module named netCDF4
    # '''
    echo "${updateXTIME} $tFile ${thisCycleDate}"
    ${updateXTIME} $tFile ${thisCycleDate}
  endif

  foreach StreamsFile_ ($StreamsFileList)
    if (${memSuffix} != "") then
      cp ${StreamsFile_} ${StreamsFile_}${memSuffix}
    endif
    sed -i 's@{{TemplateFieldsMember}}@'${memSuffix}'@' ${StreamsFile_}${memSuffix}
    sed -i 's@{{analysisPRECISION}}@'${analysisPrecision}'@' ${StreamsFile_}${memSuffix}
  end
  sed -i 's@{{StreamsFileMember}}@'${memSuffix}'@' $yamlFileList[$member]

  # Remove existing analysis file, make full copy from bg file
  # ==========================================================
  set an = $CyclingDAOutDirs[$member]
  mkdir -p ${an}
  set anFile = ${an}/${ANFilePrefix}.$thisMPASFileDate.nc
  rm ${anFile}
  cp -v ${bgFile} ${anFile}

  @ member++
end

echo "Completed model state preparation stage"

date

exit 0
