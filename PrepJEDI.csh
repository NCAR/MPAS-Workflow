#!/bin/csh -f

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
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

# ArgStateType: str, FC if this is a forecasted state, activates ArgDT in directory naming
set ArgStateType = "$3"

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

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

# Setup environment
# =================
source config/environment.csh
source config/filestructure.csh
source config/model.csh
source config/observations.csh
source config/tools.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh
source config/modeldata.csh
source config/obsdata.csh
source config/mpas/variables.csh
source config/builds.csh
source config/AppTypeTEMPLATE.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

# templated work directory
set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# other templated variables
set self_WindowHR = WindowHRTEMPLATE
set self_AppName = AppNameTEMPLATE
set self_AppType = AppTypeTEMPLATE
set self_ModelConfigDir = $AppTypeTEMPLATEModelConfigDir
set MeshList = (${AppTypeTEMPLATEMeshList})
set MPASnCellsList = (${AppTypeTEMPLATEMPASnCellsList})
set StreamsFileList = (${AppTypeTEMPLATEStreamsFileList})
set NamelistFileList = (${AppTypeTEMPLATENamelistFileList})


# ================================================================================================

# Previous time info for yaml entries
# ===================================
set prevValidDate = `$advanceCYMDH ${thisValidDate} -${self_WindowHR}`
set yy = `echo ${prevValidDate} | cut -c 1-4`
set mm = `echo ${prevValidDate} | cut -c 5-6`
set dd = `echo ${prevValidDate} | cut -c 7-8`
set hh = `echo ${prevValidDate} | cut -c 9-10`

#TODO: HALF STEP ONLY WORKS FOR INTEGER VALUES OF self_WindowHR
@ HALF_DT_HR = ${self_WindowHR} / 2
@ ODD_DT = ${self_WindowHR} % 2
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
foreach MPASnCells ($MPASnCellsList)
  ln -sfv $GraphInfoDir/x1.${MPASnCells}.graph.info* .
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
  ln -sfv $self_ModelConfigDir/$staticfile .
end

## copy/modify dynamic streams file
set iMesh = 0
foreach StreamsFile_ ($StreamsFileList)
  @ iMesh++
  rm ${StreamsFile_}
  cp -v $self_ModelConfigDir/${StreamsFile} ./${StreamsFile_}
  sed -i 's@nCells@'$MPASnCellsList[$iMesh]'@' ${StreamsFile_}
  sed -i 's@TemplateFieldsPrefix@'${self_WorkDir}'/'${TemplateFieldsPrefix}'@' ${StreamsFile_}
  sed -i 's@StaticFieldsPrefix@'${self_WorkDir}'/'${localStaticFieldsPrefix}'@' ${StreamsFile_}
  sed -i 's@forecastPrecision@'${forecastPrecision}'@' ${StreamsFile_}
end

## copy/modify dynamic namelist file
set iMesh = 0
foreach NamelistFile_ ($NamelistFileList)
  @ iMesh++
  rm ${NamelistFile_}
  cp -v ${self_ModelConfigDir}/${NamelistFile} ./${NamelistFile_}
  sed -i 's@startTime@'${thisMPASNamelistDate}'@' ${NamelistFile_}
  sed -i 's@nCells@'$MPASnCellsList[$iMesh]'@' ${NamelistFile_}
  sed -i 's@blockDecompPrefix@'${self_WorkDir}'/x1.'$MPASnCellsList[$iMesh]'@' ${NamelistFile_}
  sed -i 's@modelDT@'${MPASTimeStep}'@' ${NamelistFile_}
  sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' ${NamelistFile_}
end

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv ${ModelConfigDir}/${file} .
end


# ======================
# Link observations data
# ======================

rm -r ${InDBDir}
mkdir -p ${InDBDir}

rm -r ${OutDBDir}
mkdir ${OutDBDir}

date

foreach instrument ($observations)
  echo "Retrieving data for ${instrument} observations"
  # need to change to mainScriptDir for getObservationsOrNone to work
  cd ${mainScriptDir}

  # Check for instrument-specific directory first
  set key = IODADirectory
  set address = "${observations__resource}.${key}.${self_AppType}.${instrument}"
  # TODO: this is somewhat slow with lots of redundant loads of the entire observations.yaml config
  set IODADirectory = "`$getObservationsOrNone ${address}`"
  if ("$IODADirectory" == None) then
    # Fall back on "common" directory, if present
    set address_ = "${observations__resource}.${key}.${self_AppType}.common"
    set IODADirectory = "`$getObservationsOrNone ${address_}`"
    if ("$IODADirectory" == None) then
      echo "$0 (WARNING): skipping ${instrument} due to missing value at ${address} and ${address_}"
      continue
    endif
  endif
  # substitute $ObsWorkDir for {{ObsWorkDir}}
  set IODADirectory = `echo "$IODADirectory" | sed 's@{{ObsWorkDir}}@'$ObsWorkDir'@'`

  # prefix
  set key = IODAPrefix
  set address = "${observations__resource}.${key}.${instrument}"
  set IODAPrefix = "`$getObservationsOrNone ${address}`"
  if ("$IODAPrefix" == None) then
    set IODAPrefix = ${instrument}
  endif
  cd ${self_WorkDir}

  # link the data
  ln -sfv ${IODADirectory}/${thisValidDate}/${IODAPrefix}_obs_${thisValidDate}.h5 \
          ${InDBDir}/${instrument}_obs_${thisValidDate}.h5
  date
end


# =============
# Generate yaml
# =============

# (1) copy applicationBase yaml
# =============================

set thisYAML = orig.yaml
set prevYAML = ${thisYAML}

cp -v ${ConfigDir}/applicationBase/${self_AppName}.yaml $thisYAML
if ( $status != 0 ) then
  echo "ERROR in $0 : application YAML not available --> ${self_AppName}.yaml" > ./FAIL
  exit 1
endif

# (2) obs-related substitutions
# =============================

## indentation of observations vector members, specified in config/AppTypeTEMPLATE.csh
set obsIndent = "`${nSpaces} $nObsIndent`"

## Add selected observations (see config/AppTypeTEMPLATE.csh)
# (i) combine the observation YAML stubs into single file
set observationsYAML = observations.yaml
rm $observationsYAML
touch $observationsYAML

set found = 0
foreach instrument ($observations)
  echo "Preparing YAML for ${instrument} observations"
  set missing=0
  set SUBYAML=${ConfigDir}/ObsPlugs/${self_AppType}/${instrument}
  if ( "$instrument" =~ *"sondes"* ) then
    #KLUDGE to handle missing qv for sondes at single time
    if ( ${thisValidDate} == 2018043006 ) then
      set SUBYAML=${SUBYAML}-2018043006
    endif
  endif
  # check that instrument string matches at least one non-broken observation file link
  find ${InDBDir}/${instrument}_obs_*.h5 -mindepth 0 -maxdepth 0
    if ($? > 0) then
      @ missing++
    else
      set brokenLinks=( `find ${InDBDir}/${instrument}_obs_*.h5 -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
      foreach link ($brokenLinks)
        @ missing++
      end
    endif

  if ($missing == 0) then
    echo "${instrument} data is present and selected; adding ${instrument} to the YAML"
    sed 's@^@'"$obsIndent"'@' ${SUBYAML}.yaml >> $observationsYAML
    @ found++
  else
    echo "${instrument} data is selected, but missing; NOT adding ${instrument} to the YAML"
  endif
end
if ($found == 0) then
  echo "ERROR in $0 : no observation data is available for this date" > ./FAIL
  exit 1
endif

# (ii) concatenate all observations to thisYAML
cat $observationsYAML >> $thisYAML

# (iii) add re-usable YAML anchors
set obsanchorssed = ObsAnchors
set thisSEDF = ${obsanchorssed}SEDF.yaml
cat >! ${thisSEDF} << EOF
/${obsanchorssed}/c\
EOF

# add base anchors
foreach SUBYAML (${ConfigDir}/ObsPlugs/${self_AppType}/${obsanchorssed}.yaml)
  # concatenate with line breaks substituted
  sed 's@$@\\@' ${SUBYAML} >> ${thisSEDF}
end

# add anchors for allSkyIR ObsError fits

# allSkyIR ObsAnchors (channel selection)
set SUBYAML=${ConfigDir}/ObsPlugs/allSkyIR/${self_AppType}/ObsAnchors.yaml
sed 's@$@\\@' ${SUBYAML} >> ${thisSEDF}

# allSkyIRErrorType
# TODO: move to experiment.csh? maybe keep it here as a lower level control knob
# function used for the all-sky IR ObsError parameterization
# Options: Okamoto, Polynomial2D, Polynomial2DByLatBand, Constant
set allSkyIRErrorType = Constant

#POLYNOMIAL2DFITDEGREE
# 2d polynomial fit degree for CFxMax vs. CFy, only applies when allSkyIRErrorType==Polynomial2D
# Options: [10, 12]
set POLYNOMIAL2DFITDEGREE = 12

#Polynomial2DLatBands
# + latitude bands for which individual fits are available for
#   allSkyIRErrorType==Polynomial2DByLatBand
# + see config/ObsPlugs/allSkyIR/Polynomial2DByLatBandAssignErrorFunction_InfraredInstrument.yaml
set Polynomial2DLatBands = (NXTro NTro ITCZ STro SXTro Tro)

#ConstantErrorValueAllChannels
# constant observation error value across all channels when allSkyIRErrorType==Constant
set ConstantErrorValueAllChannels = "3.0"

if ($allSkyIRErrorType == Constant) then
  foreach InfraredInstrument (abi_g16 ahi_himawari8)
    # assign error parameter anchor
    set SUBYAML=${ConfigDir}/ObsPlugs/allSkyIR/${allSkyIRErrorType}AssignErrorParameter_InfraredInstrument.yaml
    sed 's@InfraredInstrument@'${InfraredInstrument}'@g' ${SUBYAML} > tempYAML
    sed -i 's@ConstantErrorValueAllChannels@'${ConstantErrorValueAllChannels}'@g' tempYAML
    sed 's@$@\\@' tempYAML >> ${thisSEDF}
    rm tempYAML
  end
else if ($allSkyIRErrorType == Okamoto) then
  foreach InfraredInstrument (abi_g16 ahi_himawari8)
    # assign error function anchor
    set SUBYAML=${ConfigDir}/ObsPlugs/allSkyIR/${self_AppType}/${allSkyIRErrorType}AssignErrorFunction_${InfraredInstrument}.yaml
    sed 's@HofXMeshDescriptor@'${HofXMeshDescriptor}'@g' ${SUBYAML} > tempYAML
    sed 's@$@\\@' tempYAML >> ${thisSEDF}
    rm tempYAML
  end
else
  foreach InfraredInstrument (abi_g16 ahi_himawari8)
    # polynomial2d fit parameters
    if ($allSkyIRErrorType == Polynomial2D) then
      set SUBYAML=${ConfigDir}/ObsPlugs/allSkyIR/${InfraredInstrument}/MonitorCycle15daysTwice/30-60km_degree=${POLYNOMIAL2DFITDEGREE}_fit2D_CldFrac2D_omf_STD_0min_${InfraredInstrument}.yaml
      sed 's@$@\\@' ${SUBYAML} >> ${thisSEDF}
    else if ($allSkyIRErrorType == Polynomial2DByLatBand) then
      foreach LatBand ($Polynomial2DLatBands)
        set SUBYAML=${ConfigDir}/ObsPlugs/allSkyIR/${InfraredInstrument}/MonitorCycle15daysTwice/30-60km_degree=${POLYNOMIAL2DFITDEGREE}_fit2D_CldFrac2D_omf_STD_${LatBand}_0min_${InfraredInstrument}.yaml
        sed 's@$@\\@' ${SUBYAML} >> ${thisSEDF}
      end
    else
      echo "ERROR in $0 : invalid allSkyIRErrorType=${allSkyIRErrorType}" > ./FAIL
      exit 1
    endif

    # assign error function anchor (Polynomial2D depends on fit parameters being added first above)
    set SUBYAML=${ConfigDir}/ObsPlugs/allSkyIR/${allSkyIRErrorType}AssignErrorFunction_InfraredInstrument.yaml
    sed 's@InfraredInstrument@'${InfraredInstrument}'@g' ${SUBYAML} > tempYAML
    sed -i 's@POLYNOMIAL2DFITDEGREE@'${POLYNOMIAL2DFITDEGREE}'@g' tempYAML
    sed 's@$@\\@' tempYAML >> ${thisSEDF}
    rm tempYAML
  end
endif
# add _blank key to account for extra line break above
#echo '_blank: null' >> ${thisSEDF}

# finally, insert into prevYAML
set thisYAML = insertObsAnchors.yaml
sed -f ${thisSEDF} $prevYAML >! $thisYAML
rm ${thisSEDF}
set prevYAML = $thisYAML

# (iv) substitute allsky IR PerformActionFilters
set nIndent = $applicationObsIndent[$myAppIndex]
@ nIndent = $nIndent + 2
set filtersIndent = "`${nSpaces} $nIndent`"

foreach InfraredInstrument (abi_g16 ahi_himawari8)
  set performactionsed = PerformActionFilters_${InfraredInstrument}
  set performactiontemplate = PerformActionFilters_InfraredInstrument
  set thisSEDF = ${performactionsed}SEDF.yaml
cat >! ${thisSEDF} << EOF
/${performactionsed}/c\
EOF

  # add base anchors
  foreach SUBYAML (${ConfigDir}/ObsPlugs/allSkyIR/${allSkyIRErrorType}${performactiontemplate}.yaml)
    # concatenate with line breaks substituted
    sed 's@$@\\@' ${SUBYAML} > tempYAML
    sed -i 's@InfraredInstrument@'${InfraredInstrument}'@g' tempYAML
    sed 's@^@'"$filtersIndent"'@' tempYAML >> ${thisSEDF}
    rm tempYAML
  end
  # add _blank key to account for extra line break above
  #echo ${filtersIndent}'      _blank: null' >> ${thisSEDF}

  # finally, insert into prevYAML
  set thisYAML = insert${allSkyIRErrorType}${performactionsed}.yaml
  sed -f ${thisSEDF} $prevYAML >! $thisYAML
  rm ${thisSEDF}
  set prevYAML = $thisYAML
end


## Horizontal interpolation type
sed -i 's@InterpolationType@'${InterpolationType}'@g' $thisYAML


## QC characteristics
sed -i 's@RADTHINDISTANCE@'${RADTHINDISTANCE}'@g' $thisYAML
sed -i 's@RADTHINAMOUNT@'${RADTHINAMOUNT}'@g' $thisYAML

# need to change to mainScriptDir for getObservationsOrNone to work
cd ${mainScriptDir}
set ABISuperObGrid = "`$getObservationsOrNone ${observations__resource}.IODASuperObGrid.abi_g16`"
set AHISuperObGrid = "`$getObservationsOrNone ${observations__resource}.IODASuperObGrid.ahi_himawari8`"
cd ${self_WorkDir}

if ("$ABISuperObGrid" != None) then
  sed -i 's@ABISUPEROBGRID@'${ABISuperObGrid}'@g' $thisYAML
endif
if ("$AHISuperObGrid" != None) then
  sed -i 's@AHISUPEROBGRID@'${AHISuperObGrid}'@g' $thisYAML
endif

sed -i 's@HofXMeshDescriptor@'${HofXMeshDescriptor}'@' $thisYAML


## date-time information
# current date
sed -i 's@{{thisValidDate}}@'${thisValidDate}'@g' $thisYAML
sed -i 's@{{thisMPASFileDate}}@'${thisMPASFileDate}'@g' $thisYAML
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML

# window length
sed -i 's@{{windowLength}}@PT'${self_WindowHR}'H@g' $thisYAML

# window beginning
sed -i 's@{{windowBegin}}@'${halfprevISO8601Date}'@' $thisYAML


## obs-related file naming
# crtm tables
sed -i 's@CRTMTABLES@'${CRTMTABLES}'@g' $thisYAML

# input and output IODA DB directories
sed -i 's@InDBDir@'${self_WorkDir}'/'${InDBDir}'@g' $thisYAML
sed -i 's@OutDBDir@'${self_WorkDir}'/'${OutDBDir}'@g' $thisYAML

# obs, geo, and diag files with self_AppType suffixes
sed -i 's@obsPrefix@'${obsPrefix}'_'${self_AppType}'@g' $thisYAML
sed -i 's@geoPrefix@'${geoPrefix}'_'${self_AppType}'@g' $thisYAML
sed -i 's@diagPrefix@'${diagPrefix}'_'${self_AppType}'@g' $thisYAML


# (3) model-related substitutions
# ===============================

# bg file
sed -i 's@bgStatePrefix@'${BGFilePrefix}'@g' $thisYAML
sed -i 's@bgStateDir@'${self_WorkDir}'/'${bgDir}'@g' $thisYAML

# streams+namelist
set iMesh = 0
foreach mesh ($MeshList)
  @ iMesh++
  sed -i 's@'$mesh'StreamsFile@'${self_WorkDir}'/'$StreamsFileList[$iMesh]'@' $thisYAML
  sed -i 's@'$mesh'NamelistFile@'${self_WorkDir}'/'$NamelistFileList[$iMesh]'@' $thisYAML
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
  sed -i 's@'$VarGroup'Variables@'$VarSub'@' $thisYAML
end

cp $thisYAML $appyaml

exit 0
