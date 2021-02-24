#!/bin/csh

#TODO: move this script functionality and relevent control's to python + maybe yaml

date

set ArgMember = "$1"
set ArgDT = "$2"
set ArgStateType = "$3"

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

set test = `echo $ArgMember | grep '^[0-9]*$'`
set isInt = (! $status)
if ( $isInt && "$ArgMember" != "0") then
  set self_WorkDir = $WorkDirsArg[$ArgMember]
else
 set self_WorkDir = $WorkDirsArg
endif
set test = `echo $ArgDT | grep '^[0-9]*$'`
set isInt = (! $status)
if ( ! $isInt) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif

echo "WorkDir = ${self_WorkDir}"

set self_WindowHR = WindowHRArg
set self_ObsList = ("${ObsListArg}")
set self_VARBCTable = VARBCTableArg
set self_AppName = AppNameArg
set self_AppType = AppTypeArg

mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

##
## Previous time info for yaml entries:
## ====================================
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
ln -sf $GRAPHINFO_DIR/x1.${MPASnCells}.graph.info* .

## link lookup tables
foreach fileGlob ($FCLookupFileGlobs)
  ln -sf ${FCLookupDir}/*${fileGlob} .
end

## link static stream settings

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.surface \
stream_list.${MPASCore}.diagnostics \
stream_list.${MPASCore}.output \
)
  ln -sf $daModelConfigDir/$staticfile .
end
set STREAMS = streams.${MPASCore}
rm ${STREAMS}
cp -v $daModelConfigDir/${STREAMS} .
sed -i 's@nCells@'${MPASnCells}'@' ${STREAMS}

## copy/modify dynamic namelist
set NL = namelist.${MPASCore}
rm $NL
cp -v ${daModelConfigDir}/${NL} .
sed -i 's@startTime@'${NMLDate}'@' $NL
sed -i 's@nCells@'${MPASnCells}'@' $NL
sed -i 's@modelDT@'${MPASTimeStep}'@' $NL
sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' $NL

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
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $self_AppName $member`
  mkdir -p ${OutDBDir}${memDir}
  @ member++
end

# Link conventional data
# ======================
ln -fsv $CONVObsDir/${thisValidDate}/aircraft_obs*.nc4 ${InDBDir}/
ln -fsv $CONVObsDir/${thisValidDate}/gnssro_obs*.nc4 ${InDBDir}/
ln -fsv $CONVObsDir/${thisValidDate}/satwind_obs*.nc4 ${InDBDir}/
ln -fsv $CONVObsDir/${thisValidDate}/sfc_obs*.nc4 ${InDBDir}/
ln -fsv $CONVObsDir/${thisValidDate}/sondes_obs*.nc4 ${InDBDir}/

# Link AMSUA+MHS data
# ==============
ln -fsv $MWObsDir[$myAppIndex]/${thisValidDate}/amsua*_obs_*.nc4 ${InDBDir}/
ln -fsv $MWObsDir[$myAppIndex]/${thisValidDate}/mhs*_obs_*.nc4 ${InDBDir}/

# Link ABI data
# ============
ln -fsv $ABIObsDir[$myAppIndex]/${thisValidDate}/abi*_obs_*.nc4 ${InDBDir}/

# Link AHI data
# ============
ln -fsv $AHIObsDir[$myAppIndex]/${thisValidDate}/ahi*_obs_*.nc4 ${InDBDir}/


# Link VarBC prior
# ====================
ln -fsv ${self_VARBCTable} ${InDBDir}/satbias_crtm_bak


# =============
# Generate yaml
# =============
## Copy applicationBase yaml
set thisYAML = orig.yaml
cp -v ${CONFIGDIR}/applicationBase/${self_AppName}.yaml $thisYAML

## indentation of observations array members
set nIndent = $applicationObsIndent[$myAppIndex]
set obsIndent = "`${nSpaces} $nIndent`"

## Add selected observations (see control.csh)
set checkForMissingObs = (sondes aircraft satwind gnssro sfc amsua mhs abi ahi)
foreach obs ($self_ObsList)
  echo "Preparing YAML for ${obs} observations"
  set missing=0
  set SUBYAML=${CONFIGDIR}/ObsPlugs/${self_AppType}/${obs}
  if ( "$obs" =~ *"sondes"* ) then
    #KLUDGE to handle missing qv for sondes at single time
    if ( ${thisValidDate} == 2018043006 ) then
      set SUBYAML=${SUBYAML}-2018043006
    endif
  endif
  # check for that obs string matches at least one non-broken observation file link
  foreach inst ($checkForMissingObs)
    if ( "$obs" =~ *"${inst}"* ) then
      find ${InDBDir}/${inst}*_obs_*.nc4 -mindepth 0 -maxdepth 0
      if ($? > 0) then
        @ missing++
      else
        set brokenLinks=( `find ${InDBDir}/${inst}*_obs_*.nc4 -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
        foreach link ($brokenLinks)
          @ missing++
        end
      endif
    endif
  end

  if ($missing == 0) then
    echo "${obs} data is present and selected; adding ${obs} to the YAML"
    sed 's/^/'"$obsIndent"'/' ${SUBYAML}.yaml >> $thisYAML
  else
    echo "${obs} data is selected, but missing; NOT adding ${obs} to the YAML"
  endif
end


## QC characteristics
sed -i 's@RADTHINDISTANCE@'${RADTHINDISTANCE}'@g' $thisYAML
sed -i 's@RADTHINAMOUNT@'${RADTHINAMOUNT}'@g' $thisYAML

# TODO(JJG): revise these date replacements to loop over
#            all relevant dates to this application (e.g., 4DEnVar?)
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


## model and analysis variables
set AnalysisVariables = ($StandardAnalysisVariables)
set StateVariables = ($StandardStateVariables)
# if any CRTM yaml section includes Clouds, then analyze hydrometeors
grep '^\ \+Clouds' $prevYAML
if ( $status == 0 ) then
  foreach hydro ($MPASHydroVariables)
    set AnalysisVariables = ($AnalysisVariables index_$hydro)
    set StateVariables = ($StateVariables index_$hydro)
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


# TODO(JJG): move the J terms below to da.csh as not needed for OMM

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
    set indent = "    "
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

  set ensPbDir = ${dynamicEnsBDir}
  set ensPbFilePrefix = ${dynamicEnsBFilePrefix}
  set ensPbMemFmt = "${dynamicEnsBMemFmt}"
  set ensPbNMembers = ${dynamicEnsBNMembers}

  set member = 1
  while ( $member <= ${ensPbNMembers} )
    set memberyaml = member_$member.yaml

    # add eda-member yaml name to list of member yamls
    echo "  - $memberyaml" >> $appyaml

    # create eda-member-specific yaml
    cp $prevYAML $memberyaml

    ## ensemble Jb members
    # TODO(JJG): how does ensemble B config generation need to be
    #            modified for 4DEnVar?
    # TODO: this indentation only works for pure EnVar, not Hybrid EnVar
    set indent = "    "
    set bmember = 0
    set bremain = ${ensPbNMembers}
    if ( $LeaveOneOutEDA == True ) then
      @ bremain--
    endif
cat >! ${enspbmemsed}SEDF.yaml << EOF
/${enspbmemsed}/c\
EOF

    while ( $bmember < ${ensPbNMembers} )
      @ bmember++
      if ( $bmember == $member && $LeaveOneOutEDA == True ) then
        continue
      endif
      set memDir = `${memberDir} ens $bmember "${ensPbMemFmt}"`
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
    set memDir = `${memberDir} eda $member`
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
  set ensPbDir = ${fixedEnsBDir}
  set ensPbFilePrefix = ${fixedEnsBFilePrefix}
  set ensPbMemFmt = "${fixedEnsBMemFmt}"
  set ensPbNMembers = ${fixedEnsBNMembers}

cat >! ${enspbmemsed}SEDF.yaml << EOF
/${enspbmemsed}/c\
EOF

  # TODO(JJG): how does ensemble B config generation need to be
  #            modified for 4DEnVar?
  # TODO: this indentation only works for pure EnVar, not Hybrid EnVar
  set indent = "    "
  set bmember = 0
  while ( $bmember < ${ensPbNMembers} )
    @ bmember++
    set memDir = `${memberDir} ens $bmember "${ensPbMemFmt}"`
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
