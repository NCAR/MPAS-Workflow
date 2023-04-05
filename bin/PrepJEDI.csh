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

## link MPAS mesh graph info
foreach nCells ($nCellsList)
  ln -sfv $GraphInfoDir/x1.${nCells}.graph.info* .
end

## link MPAS-Atmosphere lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

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
  sed -i 's@{{StaticFieldsPrefix}}@'${WorkDir}'/'${localStaticFieldsPrefix}'@' ${StreamsFile_}
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
  sed -i 's@blockDecompPrefix@'${WorkDir}'/x1.'$nCellsList[$iMesh]'@' ${NamelistFile_}
  sed -i 's@modelDT@'${TimeStep}'@' ${NamelistFile_}
  sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' ${NamelistFile_}
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

# (I) copy jedi/applications yaml
# ===============================

set thisYAML = orig.yaml
set prevYAML = ${thisYAML}

cp -v ${ConfigDir}/jedi/applications/${AppName}.yaml $thisYAML
if ( $status != 0 ) then
  echo "ERROR in $0 : application YAML not available --> ${AppName}.yaml" > ./FAIL
  exit 1
endif

# (II) obs-related substitutions
# ==============================

## indentation of observations vector members, specified in config/auto/$ArgAppType.csh
set obsIndent = "`${nSpaces} $nObsIndent`"

## Add selected observations (see config/auto/$ArgAppType.csh)
# (A) combine the observation YAML stubs into single file
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
        ln -sf ${biasCorrectionDir}/satbias_${i}.h5 ${CyclingDADir}/${thisValidDate}/dbOut
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

# (B) insert Observations
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

# (C) insert re-usable YAML anchors

# (1) multiple kinds of anchors for allSkyIR ObsError

# (a) settings

# Note: allSkyIRErrorType is set by calling application

# POLYNOMIAL2DFITDEGREE
# 2d polynomial fit degree for CFxMax vs. CFy, only applies when allSkyIRErrorType==Polynomial2D
# Options: [10, 12]
set POLYNOMIAL2DFITDEGREE = 12

# Polynomial2DLatBands
# + latitude bands for which individual fits are available for
#   allSkyIRErrorType==Polynomial2DByLatBand
# + see config/jedi/ObsPlugs/allSkyIR/Polynomial2DByLatBandAssignErrorFunction_InfraredInstrument.yaml
set Polynomial2DLatBands = (NXTro NTro ITCZ STro SXTro Tro)

# ConstantErrorValueAllChannels
# constant observation error value across all channels when allSkyIRErrorType==Constant
set ConstantErrorValueAllChannels = "3.0"

# (b) allSkyIR ObsAnchors (channel selection)
set anchor = ObsAnchors
set prependYAML = jedi/ObsPlugs/allSkyIR/${AppCategory}/${anchor}.yaml
set thisYAML = insertAllSkyIR${anchor}.yaml
cat ${ConfigDir}/${prependYAML} > $thisYAML

# (c) more sub-anchor parts
if ($allSkyIRErrorType == Constant) then
  foreach InfraredInstrument (abi_g16 ahi_himawari8)
    # assign error parameter anchor
    set SUBYAML=${ConfigDir}/jedi/ObsPlugs/allSkyIR/${allSkyIRErrorType}AssignErrorParameter_InfraredInstrument.yaml
    sed 's@{{InfraredInstrument}}@'${InfraredInstrument}'@g' ${SUBYAML} > tempYAML
    sed -i 's@{{ConstantErrorValueAllChannels}}@'${ConstantErrorValueAllChannels}'@g' tempYAML
    cat tempYAML >> ${thisYAML}
    rm tempYAML
  end
else if ($allSkyIRErrorType == Okamoto) then
  foreach InfraredInstrument (abi_g16 ahi_himawari8)
    # assign error function anchor
    set SUBYAML=${ConfigDir}/jedi/ObsPlugs/allSkyIR/${AppCategory}/${allSkyIRErrorType}AssignErrorFunction_${InfraredInstrument}.yaml
    sed 's@{{HofXMeshDescriptor}}@'${outerMesh}'@g' ${SUBYAML} > tempYAML

    # need to change to mainScriptDir for getObservationsOrNone to work
    cd ${mainScriptDir}
    set ABISuperObGrid = "`$getObservationsOrNone resources.${observations__resource}.IODASuperObGrid.abi_g16`"
    set AHISuperObGrid = "`$getObservationsOrNone resources.${observations__resource}.IODASuperObGrid.ahi_himawari8`"
    cd ${WorkDir}
    if ("$ABISuperObGrid" != None) then
      sed -i 's@{{ABISUPEROBGRID}}@'${ABISuperObGrid}'@g' tempYAML
    endif
    if ("$AHISuperObGrid" != None) then
      sed -i 's@{{AHISUPEROBGRID}}@'${AHISuperObGrid}'@g' tempYAML
    endif

    cat tempYAML >> ${thisYAML}
    rm tempYAML
  end
else
  foreach InfraredInstrument (abi_g16 ahi_himawari8)
    # polynomial2d fit parameters
    if ($allSkyIRErrorType == Polynomial2D) then
      set SUBYAML=${ConfigDir}/jedi/ObsPlugs/allSkyIR/${InfraredInstrument}/1stDoaDob/30-60km_degree=${POLYNOMIAL2DFITDEGREE}_fit2D_CldFrac2D_doadob_RMS_0min_${InfraredInstrument}.yaml
      cat ${SUBYAML} >> ${thisYAML}
    else if ($allSkyIRErrorType == Polynomial2DByLatBand) then
      foreach LatBand ($Polynomial2DLatBands)
        set SUBYAML=${ConfigDir}/jedi/ObsPlugs/allSkyIR/${InfraredInstrument}/1stDoaDob/30-60km_degree=${POLYNOMIAL2DFITDEGREE}_fit2D_CldFrac2D_doadob_RMS_${LatBand}_0min_${InfraredInstrument}.yaml
        cat ${SUBYAML} >> ${thisYAML}
      end
    else
      echo "ERROR in $0 : invalid allSkyIRErrorType=${allSkyIRErrorType}" > ./FAIL
      exit 1
    endif

    # assign error function anchor (Polynomial2D depends on fit parameters being added first above)
    set SUBYAML=${ConfigDir}/jedi/ObsPlugs/allSkyIR/${allSkyIRErrorType}AssignErrorFunction_InfraredInstrument.yaml
    sed 's@{{InfraredInstrument}}@'${InfraredInstrument}'@g' ${SUBYAML} > tempYAML
    sed -i 's@{{POLYNOMIAL2DFITDEGREE}}@'${POLYNOMIAL2DFITDEGREE}'@g' tempYAML
    cat tempYAML >> ${thisYAML}
    rm tempYAML
  end
endif

# (d) cat prevYAML
cat $prevYAML >> $thisYAML
set prevYAML = $thisYAML

# (e) substitute allsky IR PerformActionFilters
@ nIndent = $nObsIndent + 2
set filtersIndent = "`${nSpaces} $nIndent`"
foreach InfraredInstrument (abi_g16 ahi_himawari8)
  set performactionsed = PerformActionFilters_${InfraredInstrument}
  set performactiontemplate = PerformActionFilters_InfraredInstrument
  set thisSEDF = ${performactionsed}SEDF.yaml
cat >! ${thisSEDF} << EOF
/{{${performactionsed}}}/c\
EOF

  # add base anchors
  foreach SUBYAML (${ConfigDir}/jedi/ObsPlugs/allSkyIR/${allSkyIRErrorType}${performactiontemplate}.yaml)
    # concatenate with line breaks substituted
    sed 's@$@\\@' ${SUBYAML} > tempYAML
    sed -i 's@{{InfraredInstrument}}@'${InfraredInstrument}'@g' tempYAML
    sed 's@^@'"$filtersIndent"'@' tempYAML >> ${thisSEDF}
    rm tempYAML
  end

  # finally, insert into prevYAML
  set thisYAML = insert${allSkyIRErrorType}${performactionsed}.yaml
  sed -f ${thisSEDF} $prevYAML >! $thisYAML
  rm ${thisSEDF}
  set prevYAML = $thisYAML
end

# (2) anchors that are specific to each application
set appSpecificAnchors = (ObsAnchors)

foreach anchor ($appSpecificAnchors)
  # prepend prevYAML with prependYAML
  set prependYAML = jedi/ObsPlugs/${ArgAppType}/${anchor}.yaml
  set thisYAML = insert${anchor}.yaml
  cat ${ConfigDir}/${prependYAML} > $thisYAML
  cat $prevYAML >> $thisYAML
  set prevYAML = $thisYAML
end

# (3) anchors that are common across all applications
set appAgnosticAnchors = (ObsErrorAnchors)

foreach anchor ($appAgnosticAnchors)
  # prepend prevYAML with prependYAML
  set prependYAML = jedi/ObsPlugs/${anchor}.yaml
  set thisYAML = insert${anchor}.yaml
  cat ${ConfigDir}/${prependYAML} > $thisYAML
  cat $prevYAML >> $thisYAML
  set prevYAML = $thisYAML
end

# (D) QC characteristics
sed -i 's@{{RADTHINDISTANCE}}@'${radianceThinningDistance}'@g' $thisYAML

# method for the tropopause pressure determination
sed -i 's@{{tropprsMethod}}@'${tropprsMethod}'@g' $prevYAML


# (E) date-time information
# current date
sed -i 's@{{thisValidDate}}@'${thisValidDate}'@g' $thisYAML
sed -i 's@{{thisMPASFileDate}}@'${thisMPASFileDate}'@g' $thisYAML
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML

# window length
sed -i 's@{{windowLength}}@PT'${ArgWindowHR}'H@g' $thisYAML

# window beginning
sed -i 's@{{windowBegin}}@'${halfprevISO8601Date}'@' $thisYAML

# (F) common obs space settings
# number of IODA pool writers
sed -i 's@{{maxIODAPoolSize}}@'${maxIODAPoolSize}'@g' $prevYAML


# (G) obs-related file naming
# crtm tables
sed -i 's@{{CRTMTABLES}}@'${CRTMTABLES}'@g' $thisYAML

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

# (III) model-related substitutions
# =================================

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

exit 0
