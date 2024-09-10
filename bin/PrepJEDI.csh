#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Prepares a directory for mpas-jedi hofx and variational applications
# + namelist.atmosphere, streams.atmosphere, stream_list.atmosphere.*
# + links observation data
# + copy and pre-populate appyaml
#   - observations
#   - state directories and state prefixes
#   - model variables of interest

date

# Process arguments
# =================
## args
# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgAppType: str, hofx, variational, or enkf
set ArgAppType = "$2"

# ArgWorkDir: str, where to run
set ArgWorkDir = "$3"

# ArgWindowHR: int, window for accepting obs
set ArgWindowHR = "$4"

# ArgMember: int, ensemble member [>= 1]
# used for YAML and model state preparation for variational applications
set ArgMember = "$5"

## arg checks
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "$0 (ERROR): ArgDT must be an integer, not $ArgDT"
  exit 1
endif

if ("$ArgAppType" != hofx && "$ArgAppType" != variational && "$ArgAppType" != enkf) then
  echo "$0 (ERROR): ArgAppType must be hofx, variational, or enkf, not $ArgAppType"
  exit 1
endif

if ("$ArgAppType" == hofx) then
  set AppCategory = hofx
else
  set AppCategory = da
endif

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
source config/mpas/variables.csh
source config/tools.csh
source config/auto/experiment.csh
source config/auto/model.csh
source config/auto/naming.csh
source config/auto/observations.csh
source config/auto/workflow.csh
source config/auto/build.csh
source config/auto/invariantstream.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./bin/getCycleVars.csh

# getObservationsOrNone exposes the observations section of the config for run-time-dependent
# behaviors
source config/auto/scenario.csh observations
setenv getObservationsOrNone "${getLocalOrNone}"

# source auto/$ArgAppType.csh last to apply application-specific behaviors
# for observations
source config/auto/$ArgAppType.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

# Previous time info for yaml entries
# ===================================
set prevValidDate = `$advanceCYMDH ${thisValidDate} -${ArgWindowHR}`
set yy = `echo ${prevValidDate} | cut -c 1-4`
set mm = `echo ${prevValidDate} | cut -c 5-6`
set dd = `echo ${prevValidDate} | cut -c 7-8`
set hh = `echo ${prevValidDate} | cut -c 9-10`

#TODO: HALF STEP ONLY WORKS FOR INTEGER VALUES OF ArgWindowHR
@ HALF_DT_HR = ${ArgWindowHR} / 2
@ ODD_DT = ${ArgWindowHR} % 2
@ HALF_mi_ = ${ODD_DT} * 30
set HALF_mi = $HALF_mi_
if ( $HALF_mi_ < 10 ) then
  set HALF_mi = 0$HALF_mi
endif

#@ HALF_DT_HR_PLUS = ${HALF_DT_HR}
@ HALF_DT_HR_MINUS = ${HALF_DT_HR} + ${ODD_DT}
set halfprevValidDate = `$advanceCYMDH ${thisValidDate} -${HALF_DT_HR_MINUS}`
set yy = `echo ${halfprevValidDate} | cut -c 1-4`
set mm = `echo ${halfprevValidDate} | cut -c 5-6`
set dd = `echo ${halfprevValidDate} | cut -c 7-8`
set hh = `echo ${halfprevValidDate} | cut -c 9-10`
set halfprevISO8601Date = ${yy}-${mm}-${dd}T${hh}:${HALF_mi}:00Z

# =========================================
# =========================================
# Copy/link files: namelist, obs data, yaml
# =========================================
# =========================================

# ====================
# Model-specific files
# ====================
set iRatio = 0
foreach nCells ($nCellsList)
  @ iRatio++
  ln -sfv $GraphInfoDir/x$meshRatioList[$iRatio].${nCells}.graph.info* .
end

## link MPAS-Atmosphere lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

if (${MicrophysicsOuter} == 'mp_thompson' ) then
  ln -svf $MPThompsonTablesDir/* .
endif

## link stream_list configs
foreach staticfile ( \
stream_list.${MPASCore}.background \
stream_list.${MPASCore}.analysis \
stream_list.${MPASCore}.ensemble \
stream_list.${MPASCore}.control \
)
  rm ./$staticfile
  ln -sfv $ModelConfigDir/$ArgAppType/$staticfile .
end

## copy/modify dynamic streams file
set iMesh = 0
foreach StreamsFile_ ($StreamsFileList)
  @ iMesh++
  rm ${StreamsFile_}
  cp -v $ModelConfigDir/$ArgAppType/${StreamsFile} ./${StreamsFile_}
  sed -i 's@{{nCells}}@'$nCellsList[$iMesh]'@' ${StreamsFile_}
  sed -i 's@{{TemplateFieldsPrefix}}@'${WorkDir}'/'${TemplateFieldsPrefix}'@' ${StreamsFile_}
  sed -i 's@{{InvariantFieldsPrefix}}@'${WorkDir}'/'${localInvariantFieldsPrefix}'@' ${StreamsFile_}
  sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile_}
end

## copy/modify dynamic namelist file
set iMesh = 0
foreach NamelistFile_ ($NamelistFileList)
  @ iMesh++
  rm ${NamelistFile_}
  cp -v $ModelConfigDir/$ArgAppType/${NamelistFile} ./${NamelistFile_}
  sed -i 's@startTime@'${thisMPASNamelistDate}'@' ${NamelistFile_}
  sed -i 's@nCells@'$nCellsList[$iMesh]'@' ${NamelistFile_}
  sed -i 's@blockDecompPrefix@'${WorkDir}'/x'$meshRatioList[$iMesh]'.'$nCellsList[$iMesh]'@' ${NamelistFile_}
  sed -i 's@modelDT@'$TimeStepList[$iMesh]'@' ${NamelistFile_}
  sed -i 's@diffusionLengthScale@'$DiffusionLengthScaleList[$iMesh]'@' ${NamelistFile_}

  ## modify namelist physics
  sed -i 's@radtlwInterval@'$RadiationLWIntervalList[$iMesh]'@' $NamelistFile_
  sed -i 's@radtswInterval@'$RadiationSWIntervalList[$iMesh]'@' $NamelistFile_
  sed -i 's@physicsSuite@'$PhysicsSuiteList[$iMesh]'@' $NamelistFile_
  sed -i 's@micropScheme@'$MicrophysicsList[$iMesh]'@' $NamelistFile_
  sed -i 's@convectionScheme@'$ConvectionList[$iMesh]'@' $NamelistFile_
  sed -i 's@pblScheme@'$PBLList[$iMesh]'@' $NamelistFile_
  sed -i 's@gwdoScheme@'$GwdoList[$iMesh]'@' $NamelistFile_
  sed -i 's@radtCldScheme@'$RadiationCloudList[$iMesh]'@' $NamelistFile_
  sed -i 's@radtLWScheme@'$RadiationLWList[$iMesh]'@' $NamelistFile_
  sed -i 's@radtSWScheme@'$RadiationSWList[$iMesh]'@' $NamelistFile_
  sed -i 's@sfcLayerScheme@'$SfcLayerList[$iMesh]'@' $NamelistFile_
  sed -i 's@lsmScheme@'$LSMList[$iMesh]'@' $NamelistFile_
end

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv $ModelConfigDir/$file .
end


# ======================
# Link observations data
# ======================

rm -r ${InDBDir}
mkdir -p ${InDBDir}

rm -r ${OutDBDir}
mkdir -p ${OutDBDir}

date

foreach instrument ($observers)
  echo "Retrieving data for ${instrument} observer"
  # need to change to mainScriptDir for getObservationsOrNone to work
  cd ${mainScriptDir}

  # Check for instrument-specific directory first
  set key = IODADirectory
  set address = "resources.${observations__resource}.${key}.${AppCategory}.${instrument}"
  # TODO: this is somewhat slow with lots of redundant loads of the entire observations.yaml config
  set $key = "`$getObservationsOrNone ${address}`"
  if ("$IODADirectory" == None) then
    # Fall back on "common" directory, if present
    set address_ = "resources.${observations__resource}.${key}.${AppCategory}.common"
    set $key = "`$getObservationsOrNone ${address_}`"
    if ("$IODADirectory" == None) then
      echo "$0 (WARNING): skipping ${instrument} due to missing value at ${address} and ${address_}"
      continue
    endif
  endif
  # substitute $ObservationsWorkDir for {{ObservationsWorkDir}}
  set $key = `echo "$IODADirectory" | sed 's@{{ObservationsWorkDir}}@'$ObservationsWorkDir'@'`

  # prefix
  set key = IODAPrefix
  set address = "resources.${observations__resource}.${key}.${instrument}"
  set $key = "`$getObservationsOrNone ${address}`"
  if ("$IODAPrefix" == None) then
    set IODAPrefix = ${instrument}
  endif
  cd ${WorkDir}

  # link the data
  set obsFile = ${IODADirectory}/${thisValidDate}/${IODAPrefix}_obs_${thisValidDate}.h5
  ln -sfv ${obsFile} ${InDBDir}/${instrument}_obs_${thisValidDate}.h5

  # for radiance observations (iasi for now)
  # check if any channel index is missing (== -999)
  if ( -e ${obsFile} && "${instrument}" =~ *"iasi"* ) then
    set missingChannels = `$checkMissingChannels ${obsFile}`
    if ( ${missingChannels} == True ) then
      # remove the data
      echo "$0 (WARNING): removing ${instrument} due to missing value in channel indices"
      rm ${InDBDir}/${instrument}_obs_${thisValidDate}.h5
    endif
  endif
  date
end

# =========================
# Satellite bias correction
# =========================
# next cycle after FirstCycleDate
if ( ${thisValidDate} == ${nextFirstCycleDate} ) then
  set biasCorrectionDir = $initialVARBCcoeff
else
  set biasCorrectionDir = ${DAWorkDir}/$prevValidDate/dbOut
endif

# =============
# Generate yaml
# =============

# (1) copy jedi/applications yaml
# ===============================

set thisYAML = orig.yaml
set prevYAML = ${thisYAML}

cp -v ${ConfigDir}/jedi/applications/${AppName}.yaml $thisYAML
if ( $status != 0 ) then
  echo "ERROR in $0 : application YAML not available --> ${AppName}.yaml" > ./FAIL
  exit 1
endif

# (2) obs-related substitutions
# =============================

## indentation of observations vector members, specified in config/auto/$ArgAppType.csh
set obsIndent = "`${nSpaces} $nObsIndent`"

## Add selected observations (see config/auto/$ArgAppType.csh)
# (i) combine the observation YAML stubs into single file
set observationsYAML = observations.yaml
rm $observationsYAML
touch $observationsYAML

# parse observations__resource for instruments that allow bias correction
# need to change to mainScriptDir for getObservationsOrNone to work
cd ${mainScriptDir}
set key = instrumentsAllowingBiasCorrection
set $key = (`$getObservationsOrNone resources.${observations__resource}.${key}`)
cd ${WorkDir}

set found = 0
foreach instrument ($observers)
  echo "Preparing YAML for ${instrument} observer"
  set obsFileMissingCount=0
  # check that instrument string matches at least one non-broken observation file link
  find ${InDBDir}/${instrument}_obs_${thisValidDate}.h5 -mindepth 0 -maxdepth 0
  if ($? > 0) then
    @ obsFileMissingCount++
  else
    set brokenLinks=( `find ${InDBDir}/${instrument}_obs_${thisValidDate}.h5 -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
    foreach link ($brokenLinks)
      @ obsFileMissingCount++
    end
  endif

  set allowsBiasCorrection = False
  foreach i ($instrumentsAllowingBiasCorrection)
    if ("$instrument" == "$i") then
      set allowsBiasCorrection = True
      # if no obs file exists, link satbias file from the previous cycle
      if ( ! -f ${InDBDir}/${instrument}_obs_${thisValidDate}.h5 ) then
        ln -sf ${biasCorrectionDir}/satbias_${i}.h5 ${DAWorkDir}/${thisValidDate}/dbOut
        ln -sf ${biasCorrectionDir}/satbias_cov_${i}.h5 ${DAWorkDir}/${thisValidDate}/dbOut
      endif
    endif
  end

  # declare subdirectories for YAML stubs, which depends on whether bias correction is applied
  set AppYamlDirs = (base filters)
  if ($biasCorrection == True && $allowsBiasCorrection == True) then
    set AppYamlDirs = (base bias filtersWithBias)
  endif

  foreach subdir (${AppYamlDirs})
    set SUBYAML=${ConfigDir}/jedi/ObsPlugs/${ArgAppType}/${subdir}/${instrument}
    if ( ! -f ${SUBYAML}.yaml && ! -l ${SUBYAML}.yaml ) then
      set SUBYAML=${ConfigDir}/jedi/ObsPlugs/${AppCategory}/${subdir}/${instrument}
    endif
    if ( "$instrument" =~ *"sondes"* ) then
      #KLUDGE to handle missing qv for sondes at single time
      if ( ${thisValidDate} == 2018043006 ) then
        set SUBYAML=${SUBYAML}-2018043006
      endif
    endif
    if ($obsFileMissingCount == 0) then
      echo "${instrument} data is present and selected; adding ${instrument} to the YAML"
      sed 's@^@'"$obsIndent"'@' ${SUBYAML}.yaml >> $observationsYAML
      @ found++
    else
      echo "${instrument} data is selected, but missing; NOT adding ${instrument} to the YAML"
    endif
  end
end
if ($found == 0) then
  echo "ERROR in $0 : no observation data is available for this date" > ./FAIL
  exit 1
endif

# (ii) insert Observations
set sedstring = Observers
set thisSEDF = ${sedstring}SEDF.yaml
cat >! ${thisSEDF} << EOF
/{{${sedstring}}}/c\
EOF

# substitute with line breaks
sed 's@$@\\@' ${observationsYAML} >> ${thisSEDF}

# insert into prevYAML
set thisYAML = insert${sedstring}.yaml
sed -f ${thisSEDF} $prevYAML >! $thisYAML
rm ${thisSEDF}
set prevYAML = $thisYAML

# (iii) insert re-usable YAML anchors

# anchors that are specific to each application
set appSpecificAnchors = (ObsAnchors)

foreach anchor ($appSpecificAnchors)
  # prepend prevYAML with prependYAML
  set prependYAML = jedi/ObsPlugs/${ArgAppType}/${anchor}.yaml
  set thisYAML = insert${anchor}.yaml
  cat ${ConfigDir}/${prependYAML} > $thisYAML
  cat $prevYAML >> $thisYAML
  set prevYAML = $thisYAML
end

# anchors that are common across all applications
set appAgnosticAnchors = (ObsErrorAnchors)

foreach anchor ($appAgnosticAnchors)
  # prepend prevYAML with prependYAML
  set prependYAML = jedi/ObsPlugs/${anchor}.yaml
  set thisYAML = insert${anchor}.yaml
  cat ${ConfigDir}/${prependYAML} > $thisYAML
  cat $prevYAML >> $thisYAML
  set prevYAML = $thisYAML
end

## QC characteristics
sed -i 's@{{RADTHINDISTANCE}}@'${radianceThinningDistance}'@g' $thisYAML

# need to change to mainScriptDir for getObservationsOrNone to work
cd ${mainScriptDir}
set ABISuperObGrid = "`$getObservationsOrNone resources.${observations__resource}.IODASuperObGrid.abi_g16`"
set AHISuperObGrid = "`$getObservationsOrNone resources.${observations__resource}.IODASuperObGrid.ahi_himawari8`"
cd ${WorkDir}

if ("$ABISuperObGrid" != None) then
  sed -i 's@{{ABISUPEROBGRID}}@'${ABISuperObGrid}'@g' $thisYAML
endif
if ("$AHISuperObGrid" != None) then
  sed -i 's@{{AHISUPEROBGRID}}@'${AHISuperObGrid}'@g' $thisYAML
endif

sed -i 's@{{HofXMeshDescriptor}}@'${outerMesh}'@' $thisYAML


## date-time information
# current date (Date2 or Date4)
sed -i 's@{{thisValidDate}}@'${thisValidDate}'@g' $thisYAML
sed -i 's@{{thisMPASFileDate}}@'${thisMPASFileDate}'@g' $thisYAML
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML
if ("$ArgAppType" == "variational") then
  if ("$DAType" == "4denvar" || "$DAType" == "4dhybrid") then
    if ("$subwindow" == "3") then
      #Date1
      sed -i 's@{{thisISO8601Date1}}@'${thisISO8601Date1}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate1}}@'${thisMPASFileDate1}'@g' $thisYAML
      #Date3
      sed -i 's@{{thisISO8601Date3}}@'${thisISO8601Date3}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate3}}@'${thisMPASFileDate3}'@g' $thisYAML
    endif
    if ("$subwindow" == "1") then
      #Date1
      sed -i 's@{{thisISO8601Date1}}@'${thisISO8601Date1}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate1}}@'${thisMPASFileDate1}'@g' $thisYAML
      #Date2
      sed -i 's@{{thisISO8601Date2}}@'${thisISO8601Date2}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate2}}@'${thisMPASFileDate2}'@g' $thisYAML
      #Date3
      sed -i 's@{{thisISO8601Date3}}@'${thisISO8601Date3}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate3}}@'${thisMPASFileDate3}'@g' $thisYAML
      #Date5
      sed -i 's@{{thisISO8601Date5}}@'${thisISO8601Date5}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate5}}@'${thisMPASFileDate5}'@g' $thisYAML
      #Date6
      sed -i 's@{{thisISO8601Date6}}@'${thisISO8601Date6}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate6}}@'${thisMPASFileDate6}'@g' $thisYAML
      #Date7
      sed -i 's@{{thisISO8601Date7}}@'${thisISO8601Date7}'@g' $thisYAML
      sed -i 's@{{thisMPASFileDate7}}@'${thisMPASFileDate7}'@g' $thisYAML
    endif
  endif
endif

# window length
sed -i 's@{{windowLength}}@PT'${ArgWindowHR}'H@g' $thisYAML

if ("$ArgAppType" == "variational") then
  if ("$DAType" == "4denvar" || "$DAType" == "4dhybrid") then
    # subwindow length
    sed -i 's@{{subwindowLength}}@PT'${subwindow}'H@g' $thisYAML
  endif
endif

# window beginning
sed -i 's@{{windowBegin}}@'${halfprevISO8601Date}'@' $thisYAML


## obs-related file naming
# crtm tables
sed -i 's@{{CRTMTABLES}}@'${CRTMTABLES}'@g' $thisYAML

# IR/VIS land surface coefficients
sed -i 's@{{IRVISlandCoeff}}@'${IRVISlandCoeff}'@g' $thisYAML

# input and output IODA DB directories
sed -i 's@{{InDBDir}}@'${WorkDir}'/'${InDBDir}'@g' $thisYAML
sed -i 's@{{OutDBDir}}@'${WorkDir}'/'${OutDBDir}'@g' $thisYAML

# obs, geo, and diag files with AppCategory suffixes
sed -i 's@{{obsPrefix}}@'${obsPrefix}'_'${AppCategory}'@g' $thisYAML
sed -i 's@{{geoPrefix}}@'${geoPrefix}'_'${AppCategory}'@g' $thisYAML
sed -i 's@{{diagPrefix}}@'${diagPrefix}'_'${AppCategory}'@g' $thisYAML

# satellite bias correction directories
sed -i 's@{{biasCorrectionDir}}@'${biasCorrectionDir}'@g' $prevYAML
sed -i 's@{{fixedTlapmeanCov}}@'${fixedTlapmeanCov}'@g' $prevYAML

# method for the tropopause pressure determination
sed -i 's@{{tropprsMethod}}@'${tropprsMethod}'@g' $prevYAML

# number of IODA pool writers
sed -i 's@{{maxIODAPoolSize}}@'${maxIODAPoolSize}'@g' $prevYAML

# (3) model-related substitutions
# ===============================

# bg file
sed -i 's@{{bgStatePrefix}}@'${BGFilePrefix}'@g' $thisYAML
sed -i 's@{{bgStateDir}}@'${WorkDir}'/'${backgroundSubDir}'@g' $thisYAML

# streams+namelist
set iMesh = 0
foreach mesh ($MeshList)
  @ iMesh++
  sed -i 's@{{'$mesh'StreamsFile}}@'${WorkDir}'/'$StreamsFileList[$iMesh]'@' $thisYAML
  sed -i 's@{{'$mesh'NamelistFile}}@'${WorkDir}'/'$NamelistFileList[$iMesh]'@' $thisYAML
end

## model and analysis variables
set AnalysisVariables = ($StandardAnalysisVariables)
set StateVariables = ($StandardStateVariables)

# if any CRTM yaml section includes the *cloudyCRTMObsOperator alias, then hydrometeors
# must be included in both the Analysis and State variables
grep '*cloudyCRTMObsOperator' $thisYAML
if ( $status == 0 ) then
  foreach hydro ($MPASHydroStateVariables)
    set StateVariables = ($StateVariables $hydro)
  end
  foreach hydro ($MPASHydroIncrementVariables)
    set AnalysisVariables = ($AnalysisVariables $hydro)
  end
endif

# substitute into yaml
foreach VarGroup (Analysis Model State)
  if (${VarGroup} == Analysis) then
    set Variables = ($AnalysisVariables)
  endif
  if (${VarGroup} == State || \
      ${VarGroup} == Model) then
    set Variables = ($StateVariables)
  endif
  set VarSub = ""
  foreach var ($Variables)
    set VarSub = "$VarSub$var,"
  end
  # remove trailing comma
  set VarSub = `echo "$VarSub" | sed 's/.$//'`
  sed -i 's@{{'$VarGroup'Variables}}@'$VarSub'@' $thisYAML
end

cp $thisYAML $appyaml

# ==================================================================================================
# ==================================================================================================
# YAML preparation stage
# ==================================================================================================
# ==================================================================================================

if ("$ArgAppType" == variational) then

  echo "Starting YAML preparation stage"

  # Prepares YAML for all members during member 1

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
  sed -i 's@{{anStateDir}}@'${WorkDir}'/'${analysisSubDir}'@g' $prevYAML


  # Hybrid Jb weights
  # =================
  if ( "$DAType" == "3dhybrid" || "$DAType" == "4dhybrid" ) then
    sed -i 's@{{staticCovarianceWeight}}@'${staticCovarianceWeight}'@' $prevYAML
    sed -i 's@{{ensembleCovarianceWeight}}@'${ensembleCovarianceWeight}'@' $prevYAML
  endif

  if ( "$DAType" == "3dhybrid-allsky" ) then
    sed -i 's@{{hybridCoefficientsDir}}@'${hybridCoefficientsDir}'@' $prevYAML
  endif

  # Static Jb term
  # ==============
  if ( "$DAType" == "3dvar" || "$DAType" =~ *"3dhybrid"* || "$DAType" =~ *"4dhybrid"* ) then
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
  endif # 3dvar || *"3dhybrid"* || *"4dhybrid"*


  # Ensemble Jb term
  # ================

  if ( "$DAType" == "3denvar" || "$DAType" =~ *"3dhybrid"* || "$DAType" == "4denvar" || "$DAType" =~ *"4dhybrid"* ) then
    ## yaml indentation
    if ( "$DAType" == "3denvar" ) then
      set nEnsPbIndent = 4
    else if ( "$DAType" =~ *"3dhybrid"* || "$DAType" =~ *"4dhybrid"* ) then
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

    @ dateOffset = ${ArgWindowHR} + ${ensPbOffsetHR}
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

  if ("$DAType" == "4denvar" || "$DAType" =~ *"4dhybrid"* ) then
    ## members
    # + pure envar: 'background error.members from template'
    # + hybrid envar: 'background error.components[iEnsemble].covariance.members from template'
    #   where iEnsemble is the ensemble component index of the hybrid B

    # performs sed substitution for EnsemblePbMembers
    set enspbmemsed = EnsemblePbMembers

    @ dateOffset = ${ArgWindowHR} + ${ensPbOffsetHR}
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
    else if ("$subwindow" == "1") then
      setenv myCommand "${substituteEnsembleBTemplate_4d_7slots} ${dir0} ${dir1} ${ensPbMemPrefix} ${ensPbFilePrefix}.${thisMPASFileDate1}.nc ${thisISO8601Date1} ${ensPbFilePrefix}.${thisMPASFileDate2}.nc ${thisISO8601Date2} ${ensPbFilePrefix}.${thisMPASFileDate3}.nc ${thisISO8601Date3} ${ensPbFilePrefix}.${thisMPASFileDate}.nc ${thisISO8601Date} ${ensPbFilePrefix}.${thisMPASFileDate5}.nc ${thisISO8601Date5} ${ensPbFilePrefix}.${thisMPASFileDate6}.nc ${thisISO8601Date6} ${ensPbFilePrefix}.${thisMPASFileDate7}.nc ${thisISO8601Date7} ${ensPbMemNDigits} ${ensPbNMembers} $yamlFiles ${enspbmemsed} ${nEnsPbIndent} $SelfExclusion"
    else
      echo "$0 (ERROR): invalid subwindow value:${subwindow}" > ./FAIL
      exit 1
    endif

    echo "$myCommand" > ./substitute_command

    ${myCommand}

    if ($status != 0) then
      echo "$0 (ERROR): failed to substitute ${enspbmemsed}" > ./FAIL
      exit 1
    endif

  endif #4denvar || 4dhybrid

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

  echo "Completed YAML preparation stage for ${ArgAppType} application"

  date

else if ("$ArgAppType" == enkf) then

  echo "Starting YAML preparation stage"

  # Rename appyaml generated by a previous preparation script
  # =========================================================
  rm prevPrep.yaml
  cp $appyaml prevPrep.yaml
  set prevYAML = $appyaml

  # Analysis directory
  # ==================
  sed -i 's@{{anStatePrefix}}@'${ANFilePrefix}'@g' $prevYAML
  sed -i 's@{{anStateDir}}@'${WorkDir}'/'${analysisSubDir}'@g' $prevYAML

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

  @ dateOffset = ${ArgWindowHR} + ${ensPbOffsetHR}
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
  sed -i 's@{{localizationDimension}}@'"${localizationDimension}"'@' $prevYAML
  sed -i 's@{{horizontalLocalizationMethod}}@'"${horizontalLocalizationMethod}"'@' $prevYAML
  sed -i 's@{{horizontalLocalizationLengthscale}}@'${horizontalLocalizationLengthscale}'@' $prevYAML
  sed -i 's@{{verticalLocalizationFunction}}@'"${verticalLocalizationFunction}"'@' $prevYAML
  sed -i 's@{{verticalLocalizationLengthscale}}@'${verticalLocalizationLengthscale}'@' $prevYAML

  # Jo term (member dependence)
  # ===========================

  # eliminate member-specific file output directory substitutions
  sed -i 's@{{MemberDir}}@@g' $prevYAML

  echo "Completed YAML preparation stage ${ArgAppType} application"

endif

date


# ==================================================================================================
# ==================================================================================================
# Model state preparation stage"
# ==================================================================================================
# ==================================================================================================

# other static variables
set self_StateDirs = ($prevCyclingFCDirs)
set self_StatePrefix = ${FCFilePrefix}

# Remove old netcdf lock files
rm *.nc*.lock

# Remove old invariant fields in case this directory was used previously
rm ${localInvariantFieldsPrefix}*.nc*

if ("$ArgAppType" == variational) then

  echo "Starting model state preparation stage"

  # ====================================
  # Input/Output model state preparation
  # ====================================

  # get source invariant fields
  set InvariantFieldsDirList = ($InvariantFieldsDirOuter $InvariantFieldsDirInner)
  set InvariantFieldsFileList = ($InvariantFieldsFileOuter $InvariantFieldsFileInner)

  set member = 1
  while ( $member <= ${nMembers} )
    set memSuffix = `${memberDir} $nMembers $member "${flowMemFileFmt}"`

    ## copy invariant fields
    # unique InvariantFieldsDir and InvariantFieldsFile for each ensemble member
    # + ensures independent ivgtyp, isltyp, etc...
    # + avoids concurrent reading of InvariantFieldsFile by all members
    set iMesh = 0
    foreach localInvariantFieldsFile ($localInvariantFieldsFileList)
      @ iMesh++

      set localInvariant = ${localInvariantFieldsFile}${memSuffix}
      rm ${localInvariant}

      set InvariantFieldsFile = $InvariantFieldsDirList[$iMesh]/$InvariantFieldsFileList[$iMesh]
      ln -sfv ${InvariantFieldsFile} ${localInvariant}
    end

    # TODO(JJG): centralize this directory name construction (cycle.csh?)
    set other = $self_StateDirs[$member]
    set bg = $CyclingDAInDirs[$member]
    mkdir -p ${bg}

    # Link bg from StateDirs
    # ======================
    set bgFileOther = ${other}/${self_StatePrefix}.${thisMPASFileDate}.nc
    set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc

    rm ${bgFile}${OrigFileSuffix} ${bgFile}
    ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
    ln -sfv ${bgFileOther} ${bgFile}

    if ( "$DAType" == "4denvar" || "$DAType" == "4dhybrid" ) then
      set bgFileOther = ${other}/${self_StatePrefix}.*.nc
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
    rm templateFields.${nCellsOuter}.${thisMPASFileDate}.nc${memSuffix}
    ln -sfv ${bgFile} templateFields.${nCellsOuter}.${thisMPASFileDate}.nc${memSuffix}

    if ( "$DAType" == "4denvar" || "$DAType" == "4dhybrid" ) then
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

      # use localInvariantFieldsFileInner as the TemplateFieldsFileInner
      # NOTE: not perfect for EDA if invariant fields differ between members,
      #       but dual-res EDA not working yet anyway
      cp -v ${InitFieldsDirInner}/${InitFieldsFileInner} $tFile

      if ( "$DAType" == "4denvar" || "$DAType" == "4dhybrid" ) then
        # Loop over times and set as the TemplateFieldsFileInner for this member for each time
        foreach bgFile (`ls -d ${bg}/*.nc`)
          set temp_file = `echo $bgFile | sed 's:.*/::'`
          set bgFileDate = `echo ${temp_file} | cut -c 4-22`
          cp -v ${InitFieldsDirInner}/${InitFieldsFileInner} templateFields.${nCellsInner}.${bgFileDate}.nc${memSuffix}
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
      if ( "$DAType" == "4denvar" || "$DAType" == "4dhybrid" ) then
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

      # use localInvariantFieldsFileInner as the TemplateFieldsFileInner
      cp -v ${InitFieldsDirInner}/${InitFieldsFileInner} $tFile

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

  echo "Completed model state preparation stage ${ArgAppType} application"

  date

else if ("$ArgAppType" == enkf) then

  echo "Starting model state preparation stage"

  # ====================================
  # Input/Output model state preparation
  # ====================================

  # TODO: modify below, do not loop over members, no memSuffix needed

  # mean background/analysis directories
  set member = 0
  set memDir = `${memberDir} $nMembers $member`
  mkdir -p ${backgroundSubDir}${memDir}
  mkdir -p ${analysisSubDir}${memDir}

  # member background/analysis directories and files
  set member = 1
  while ( $member <= ${nMembers} )
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

  # get source invariant fields
  set InvariantFieldsDirList = ($InvariantFieldsDirOuter)
  set InvariantFieldsFileList = ($InvariantFieldsFileOuter)

  set member = 1
  while ( $member <= 1 )
    set memSuffix = ""

    ## copy invariant fields
    # unique InvariantFieldsDir and InvariantFieldsFile for each ensemble member
    # + ensures independent ivgtyp, isltyp, etc...
    # + avoids concurrent reading of InvariantFieldsFile by all members
    set iMesh = 0
    foreach localInvariantFieldsFile ($localInvariantFieldsFileList)
      @ iMesh++

      set localInvariant = ${localInvariantFieldsFile}${memSuffix}
      rm ${localInvariant}

      set InvariantFieldsFile = $InvariantFieldsDirList[$iMesh]/$InvariantFieldsFileList[$iMesh]
      ln -sfv ${InvariantFieldsFile} ${localInvariant}
    end

    # use the 1st member background as the TemplateFieldsFileOuter
    set bg = $CyclingDAInDirs[$member]
    set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc

    rm templateFields.${nCellsOuter}.${thisMPASFileDate}.nc${memSuffix}
    ln -sfv ${bgFile} templateFields.${nCellsOuter}.${thisMPASFileDate}.nc${memSuffix}

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

  echo "Completed model state preparation stage ${ArgAppType} application"

  date

endif

date

exit 0
