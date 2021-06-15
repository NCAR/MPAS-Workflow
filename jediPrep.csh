#!/bin/csh -f

#TODO: move this script functionality and relevent control's to python + maybe yaml

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
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/obsdata.csh
source config/mpas/variables.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh
source config/appindex.csh
source config/builds.csh
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
set self_ObsList = (${AppTypeTEMPLATEObsList})
set self_VARBCTable = VARBCTableTEMPLATE
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
set prevFileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set prevNMLDate = ${yy}-${mm}-${dd}_${hh}:00:00
set prevConfDate = ${yy}-${mm}-${dd}T${hh}:00:00Z

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
set halfprevConfDate = ${yy}-${mm}-${dd}T${hh}:${HALF_mi}:00Z

# ============================================================
# ============================================================
# Copy/link files: BUMP B matrix, namelist, yaml, bg, obs data
# ============================================================
# ============================================================

# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
foreach MPASnCells ($MPASnCellsList)
  ln -sfv $GraphInfoDir/x1.${MPASnCells}.graph.info* .
end

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## link stream_list configs
foreach staticfile ( \
stream_list.${MPASCore}.diagnostics \
stream_list.${MPASCore}.output \
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
  sed -i 's@TemplateFieldsPrefix@'${TemplateFieldsPrefix}'@' ${StreamsFile_}
  sed -i 's@StaticFieldsPrefix@'${localStaticFieldsPrefix}'@' ${StreamsFile_}
end

## copy/modify dynamic namelist file
set iMesh = 0
foreach NamelistFile_ ($NamelistFileList)
  @ iMesh++
  rm ${NamelistFile_}
  cp -v ${self_ModelConfigDir}/${NamelistFile} ./${NamelistFile_}
  sed -i 's@startTime@'${NMLDate}'@' ${NamelistFile_}
  sed -i 's@nCells@'$MPASnCellsList[$iMesh]'@' ${NamelistFile_}
  sed -i 's@modelDT@'${MPASTimeStep}'@' ${NamelistFile_}
  sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' ${NamelistFile_}
end

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv ${ModelConfigDir}/${file} .
end

# =============
# OBSERVATIONS
# =============
# get application index
set index = 0
foreach application (${applicationIndex})
  @ index++
  if ( $application == ${self_AppType} ) then
    set myAppIndex = $index
  endif
end

# setup directories
rm -r ${InDBDir}
mkdir -p ${InDBDir}
rm -r ${OutDBDir}
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $self_AppName $member`
  mkdir -p ${OutDBDir}${memDir}
  @ member++
end

# Link conventional data
# ======================
ln -sfv $ConventionalObsDir/${thisValidDate}/aircraft_obs*.h5 ${InDBDir}/
ln -sfv $ConventionalObsDir/${thisValidDate}/gnssro_obs*.h5 ${InDBDir}/
ln -sfv $ConventionalObsDir/${thisValidDate}/satwind_obs*.h5 ${InDBDir}/
ln -sfv $ConventionalObsDir/${thisValidDate}/sfc_obs*.h5 ${InDBDir}/
ln -sfv $ConventionalObsDir/${thisValidDate}/sondes_obs*.h5 ${InDBDir}/

# Link AMSUA+MHS data
# ==============
ln -sfv $PolarMWObsDir[$myAppIndex]/${thisValidDate}/amsua*_obs_*.h5 ${InDBDir}/
ln -sfv $PolarMWObsDir[$myAppIndex]/${thisValidDate}/mhs*_obs_*.h5 ${InDBDir}/

# Link ABI data
# ============
ln -sfv $ABIObsDir[$myAppIndex]/${thisValidDate}/abi*_obs_*.h5 ${InDBDir}/

# Link AHI data
# ============
ln -sfv $AHIObsDir[$myAppIndex]/${thisValidDate}/ahi*_obs_*.h5 ${InDBDir}/


# Link VarBC prior
# ====================
ln -sfv ${self_VARBCTable} ${InDBDir}/satbias_crtm_bak


# =============
# Generate yaml
# =============
## Copy applicationBase yaml
set thisYAML = orig.yaml
cp -v ${ConfigDir}/applicationBase/${self_AppName}.yaml $thisYAML

## indentation of observations array members
set nIndent = $applicationObsIndent[$myAppIndex]
set obsIndent = "`${nSpaces} $nIndent`"

## Add selected observations (see control.csh)
set checkForMissingObs = (sondes aircraft satwind gnssro sfc amsua mhs abi ahi)
set found = 0
set obsYAML = observations.yaml
rm $obsYAML
touch $obsYAML
foreach obs ($self_ObsList)
  echo "Preparing YAML for ${obs} observations"
  set missing=0
  set SUBYAML=${ConfigDir}/ObsPlugs/${self_AppType}/${obs}
  if ( "$obs" =~ *"sondes"* ) then
    #KLUDGE to handle missing qv for sondes at single time
    if ( ${thisValidDate} == 2018043006 ) then
      set SUBYAML=${SUBYAML}-2018043006
    endif
  endif
  # check that obs string matches at least one non-broken observation file link
  foreach inst ($checkForMissingObs)
    if ( "$obs" =~ *"${inst}"* ) then
      find ${InDBDir}/${inst}*_obs_*.h5 -mindepth 0 -maxdepth 0
      if ($? > 0) then
        @ missing++
      else
        set brokenLinks=( `find ${InDBDir}/${inst}*_obs_*.h5 -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
        foreach link ($brokenLinks)
          @ missing++
        end
      endif
    endif
  end

  if ($missing == 0) then
    echo "${obs} data is present and selected; adding ${obs} to the YAML"
    sed 's/^/'"$obsIndent"'/' ${SUBYAML}.yaml >> $obsYAML
    @ found++
  else
    echo "${obs} data is selected, but missing; NOT adding ${obs} to the YAML"
  endif
end
if ($found == 0) then
  echo "ERROR in $0 : no observation data is available for this date" > ./FAIL
  exit 1
endif

cat $obsYAML >> $thisYAML

#TODO: replace cat with sed substitution so that each application can decide what to do when there
# are zero observations available

## Horizontal interpolation type
sed -i 's@InterpolationType@'${InterpolationType}'@g' $thisYAML

## QC characteristics
sed -i 's@RADTHINDISTANCE@'${RADTHINDISTANCE}'@g' $thisYAML
sed -i 's@RADTHINAMOUNT@'${RADTHINAMOUNT}'@g' $thisYAML

# TODO(JJG): revise these date replacements to loop over
#            all dates relevant to this application (e.g., 4DEnVar?)
## previous date
sed -i 's@2018-04-14_18.00.00@'${prevFileDate}'@g' $thisYAML
sed -i 's@2018041418@'${prevValidDate}'@g' $thisYAML
sed -i 's@2018-04-14T18:00:00Z@'${prevConfDate}'@g'  $thisYAML

## current date
sed -i 's@2018-04-15_00.00.00@'${fileDate}'@g' $thisYAML
sed -i 's@2018041500@'${thisValidDate}'@g' $thisYAML
sed -i 's@2018-04-15T00:00:00Z@'${ConfDate}'@g' $thisYAML

## window length
sed -i 's@PT6H@PT'${self_WindowHR}'H@g' $thisYAML

## window beginning
sed -i 's@WindowBegin@'${halfprevConfDate}'@' $thisYAML

## file naming
sed -i 's@CRTMTABLES@'${CRTMTABLES}'@g' $thisYAML
sed -i 's@InDBDir@'${InDBDir}'@g' $thisYAML
sed -i 's@OutDBDir@'${OutDBDir}'@g' $thisYAML
sed -i 's@obsPrefix@'${obsPrefix}'@g' $thisYAML
sed -i 's@geoPrefix@'${geoPrefix}'@g' $thisYAML
sed -i 's@diagPrefix@'${diagPrefix}'@g' $thisYAML
sed -i 's@AppType@'${self_AppType}'@g' $thisYAML
sed -i 's@nEnsDAMembers@'${nEnsDAMembers}'@g' $thisYAML
sed -i 's@bgStatePrefix@'${BGFilePrefix}'@g' $thisYAML
sed -i 's@bgStateDir@'${self_WorkDir}'/'${bgDir}'@g' $thisYAML
sed -i 's@anStatePrefix@'${ANFilePrefix}'@g' $thisYAML
sed -i 's@anStateDir@'${self_WorkDir}'/'${anDir}'@g' $thisYAML
set prevYAML = $thisYAML

# streams+namelist
set iMesh = 0
foreach mesh ($MeshList)
  @ iMesh++
  sed -i 's@'$mesh'StreamsFile@'$StreamsFileList[$iMesh]'@' $thisYAML
  sed -i 's@'$mesh'NamelistFile@'$NamelistFileList[$iMesh]'@' $thisYAML
end

## model and analysis variables
set AnalysisVariables = ($StandardAnalysisVariables)
set StateVariables = ($StandardStateVariables)
# if any CRTM yaml section includes Clouds, then analyze hydrometeors
grep '^\ \+Clouds' $prevYAML
if ( $status == 0 ) then
  foreach hydro ($MPASHydroVariables)
    set AnalysisVariables = ($AnalysisVariables $hydro)
    set StateVariables = ($StateVariables $hydro)
  end
endif
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
  sed -i 's@'$VarGroup'Variables@'$VarSub'@' $prevYAML
end

#set VarSub = ""
#foreach var ($AnalysisVariables)
#  set VarSub = "$VarSub$var,"
#end
## remove trailing comma
#set VarSub = `echo "$VarSub" | sed 's/.$//'`
#sed -i 's@ModelVariables@'$VarSub'@' $prevYAML
#sed -i 's@AnalysisVariables@'$VarSub'@' $prevYAML


# TODO(JJG): J terms below not needed for hofx application; move to a new variationalPrep.csh.
#  Can use an intermediate yaml (e.g., jediPrep.yaml) between jediPrep.csh and application-specific
#  preparations. Could also have an hofxPrep.csh, starts off by just copying yaml.

## ensemble Jb yaml indentation
if ( "$self_AppName" =~ *"envar"* ) then
  set nEnsPbIndent = 4
else if ( "$self_AppName" =~ *"hybrid"* ) then
  set nEnsPbIndent = 8
else
  set nEnsPbIndent = 0
endif

## ensemble Jb localization
sed -i 's@bumpLocDir@'${bumpLocDir}'@g' $prevYAML
sed -i 's@bumpLocPrefix@'${bumpLocPrefix}'@g' $prevYAML

## ensemble Jb inflation
set enspbinfsed = EnsemblePbInflation
set removeInflation = 0
if ( "$self_AppName" =~ *"eda"* && ${ABEInflation} == True ) then
  set inflationFields = ${CyclingABEInflationDir}/BT${ABEIChannel}_ABEIlambda.nc
  find ${inflationFields} -mindepth 0 -maxdepth 0
  if ($? > 0) then
    ## inflation file not generated because all instruments (abi, ahi?) missing at this cylce date
    #TODO: use last valid inflation factors?
    set removeInflation = 1
  else
    set thisYAML = insertInflation.yaml
    set indent = "`${nSpaces} $nEnsPbIndent`"
#NOTE: no_transf=1 allows for spechum and temperature inflation values to be read
#      directly from inflationFields without a variable transform. Also requires spechum
#      and temperature to be in stream_list.atmosphere.output.

cat >! ${enspbinfsed}SEDF.yaml << EOF
/${enspbinfsed}/c\
${indent}inflation field:\
${indent}  date: *adate\
${indent}  filename: ${inflationFields}\
${indent}  no_transf: 1
EOF

    sed -f ${enspbinfsed}SEDF.yaml $prevYAML >! $thisYAML
    set prevYAML = $thisYAML
  endif
else
  set removeInflation = 1
endif
if ($removeInflation > 0) then
  # delete the line containing $enspbinfsed
  sed -i '/^'${enspbinfsed}'/d' $prevYAML
endif


set enspbmemsed = EnsemblePbMembers
if ( "$self_AppName" =~ *"eda"* ) then
  echo "files:" > $appyaml

  set member = 1
  while ( $member <= ${nEnsDAMembers} )
    set memberyaml = member_$member.yaml

    # add eda-member yaml name to list of member yamls
    echo "  - $memberyaml" >> $appyaml

    # create eda-member-specific yaml
    cp $prevYAML $memberyaml

    ## ensemble Jb members
cat >! ${enspbmemsed}SEDF.yaml << EOF
/${enspbmemsed}/c\
EOF

    # TODO(JJG): how does ensemble B config generation need to be
    #            modified for 4DEnVar?
    set indent = "`${nSpaces} $nEnsPbIndent`"
    set bmember = 0
    set bremain = ${ensPbNMembers}
    if ( $LeaveOneOutEDA == True ) then
      @ bremain--
    endif

    while ( $bmember < ${ensPbNMembers} )
      @ bmember++
      if ( $bmember == $member && $LeaveOneOutEDA == True ) then
        continue
      endif
      set memDir = `${memberDir} ensemble $bmember "${ensPbMemFmt}"`
      set filename = ${ensPbDir}/${prevValidDate}${memDir}/${ensPbFilePrefix}.${fileDate}.nc
      if ( $bremain > 1 ) then
        set filename = ${filename}\\
      endif

cat >>! ${enspbmemsed}SEDF.yaml << EOF
${indent}- date: *adate\
${indent}  state variables: *incvars\
${indent}  filename: ${filename}
EOF

      @ bremain--
    end
    set thisYAML = last.yaml
    sed -f ${enspbmemsed}SEDF.yaml $memberyaml >! $thisYAML
    rm ${enspbmemsed}SEDF.yaml
    cp $thisYAML $memberyaml

    ## Jo term
    set memDir = `${memberDir} $self_AppName $member`
    sed -i 's@OOPSMemberDir@'${memDir}'@g' $memberyaml
    if ($member == 1) then
      sed -i 's@ObsPerturbations@false@g' $memberyaml
    else
      sed -i 's@ObsPerturbations@true@g' $memberyaml
    endif
    sed -i 's@MemberSeed@'$member'@g' $memberyaml

    @ member++
  end
else
  # create deterministic "member" yaml
  set memberyaml = $appyaml
  cp $prevYAML $memberyaml

  ## ensemble Jb members
cat >! ${enspbmemsed}SEDF.yaml << EOF
/${enspbmemsed}/c\
EOF

  # TODO(JJG): how does ensemble B config generation need to be
  #            modified for 4DEnVar?
  set indent = "`${nSpaces} $nEnsPbIndent`"
  set bmember = 0
  while ( $bmember < ${ensPbNMembers} )
    @ bmember++
    set memDir = `${memberDir} ensemble $bmember "${ensPbMemFmt}"`
    set filename = ${ensPbDir}/${prevValidDate}${memDir}/${ensPbFilePrefix}.${fileDate}.nc
    if ( $bmember < ${ensPbNMembers} ) then
      set filename = ${filename}\\
    endif

cat >>! ${enspbmemsed}SEDF.yaml << EOF
${indent}- date: *adate\
${indent}  state variables: *incvars\
${indent}  filename: ${filename}
EOF

  end
  set thisYAML = last.yaml
  sed -f ${enspbmemsed}SEDF.yaml $memberyaml >! $thisYAML
  rm ${enspbmemsed}SEDF.yaml
  cp $thisYAML $memberyaml

  ## Jo term
  sed -i 's@OOPSMemberDir@@g' $memberyaml
  sed -i 's@ObsPerturbations@false@g' $memberyaml
  sed -i 's@MemberSeed@1@g' $memberyaml
endif


exit 0
