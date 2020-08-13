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
set self_DAType = DATypeArg
set self_DAMode = DAModeArg

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
ln -sf $GRAPHINFO_DIR/x1.${MPAS_NCELLS}.graph.info* .

## link lookup tables
ln -sf ${FCStaticFiles} .

## link static stream settings

## link static stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.surface \
stream_list.${MPASCore}.diagnostics \
stream_list.${MPASCore}.output \
streams.${MPASCore} \
)
  ln -sf $DA_NML_DIR/$staticfile .
end

## copy/modify dynamic namelist
cp -v ${RESSPECIFICDIR}/namelist.atmosphere_da ./namelist.atmosphere
cp -v namelist.atmosphere orig_namelist.atmosphere
set indent = "   "
cat >! newnamelist << EOF
  /config_start_time /c\
${indent}config_start_time = '${NMLDate}'
EOF
sed -f newnamelist orig_namelist.atmosphere >! namelist.atmosphere
rm newnamelist

# =============
# OBSERVATIONS
# =============
rm -r ${InDBDir}
mkdir -p ${InDBDir}
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $self_DAType $member`
  mkdir -p ${OutDBDir}${memDir}
  @ member++
end

# Link conventional data
# ======================
ln -fsv $CONV_OBS_DIR/${thisValidDate}/aircraft_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${thisValidDate}/gnssro_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${thisValidDate}/satwind_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${thisValidDate}/sfc_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${thisValidDate}/sondes_obs*.nc4 ${InDBDir}/

# Link AMSUA data
# ==============
ln -fsv $AMSUA_OBS_DIR/${thisValidDate}/amsua*_obs_*.nc4 ${InDBDir}/

# Link ABI data
# ============
ln -fsv $ABI_OBS_DIR/${thisValidDate}/abi*_obs_*.nc4 ${InDBDir}/

# Link AHI data
# ============
ln -fsv $AHI_OBS_DIR/${thisValidDate}/ahi*_obs_*.nc4 ${InDBDir}/

# Link VarBC prior
# ====================
ln -fsv ${self_VARBCTable} ${InDBDir}/satbias_crtm_bak


# =============
# Generate yaml
# =============
## Copy applicationBase yaml
set thisYAML = orig.yaml
cp -v ${CONFIGDIR}/applicationBase/${self_DAType}.yaml $thisYAML

## Add selected observations (see control.csh)
set checkForMissingObs = (abi ahi amsua mhs)
foreach obs ($self_ObsList)
  echo "Preparing YAML for ${obs} observations"
  set missing=0
  set SUBYAML=${CONFIGDIR}/ObsPlugs/${self_DAMode}/${obs}
  if ( "$obs" =~ *"conv"* ) then
    #KLUDGE to handle missing qv for sondes at single time
    if ( ${thisValidDate} == 2018043006 ) then
      set SUBYAML=${SUBYAML}-2018043006
    endif
  else
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
  endif

  if ($missing == 0) then
    echo "${obs} data is present and selected; adding ${obs} to the YAML"
    cat ${SUBYAML}.yaml >> $thisYAML
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
sed -i 's@DAMode@'${self_DAMode}'@g' $thisYAML
sed -i 's@nEnsDAMembers@'${nEnsDAMembers}'@g' $thisYAML
if ( "$self_DAType" =~ *"eda"* ) then
  sed -i 's@OOPSMemberDir@/%{member}%@g' $thisYAML
else
  sed -i 's@OOPSMemberDir@@g' $thisYAML
endif
set meshFile = ${self_WorkDir}/${bgDir}/${BGFilePrefix}.$fileDate.nc
sed -i 's@meshFile@'${meshFile}'@g' $thisYAML
sed -i 's@bgStatePrefix@'${BGFilePrefix}'@g' $thisYAML
sed -i 's@bgStateDir@'${self_WorkDir}'/'${bgDir}'@g' $thisYAML
sed -i 's@anStatePrefix@'${ANFilePrefix}'@g' $thisYAML
sed -i 's@anStateDir@'${self_WorkDir}'/'${anDir}'@g' $thisYAML
set prevYAML = $thisYAML


## model and analysis variables
set AnalysisVariables = ($StandardAnalysisVariables)
# if any CRTM yaml section includes Clouds, then analyze hydrometeors
grep '^\ \+Clouds' $prevYAML
if ( $status == 0 ) then
  foreach hydro ($MPASHydroVariables)
    set AnalysisVariables = ($AnalysisVariables index_$hydro)
  end
endif
set VarSub = ""
foreach var ($AnalysisVariables)
  set VarSub = "$VarSub$var,"
end
# remove trailing comma
set VarSub = `echo "$VarSub" | sed 's/.$//'`
sed -i 's@ModelVariables@'$VarSub'@' $prevYAML
sed -i 's@AnalysisVariables@'$VarSub'@' $prevYAML


## ensemble covariance
# localization
sed -i 's@bumpLocDir@'${bumpLocDir}'@g' $prevYAML
sed -i 's@bumpLocPrefix@'${bumpLocPrefix}'@g' $prevYAML
# ensemble forecasts
# TODO(JJG): how does ensemble B config generation need to be
#            modified for 4DEnVar?
# TODO(JJG): move this to da as not needed for OMM
if ( "$self_DAType" =~ *"eda"* ) then
  set ensPbDir = ${dynamicEnsBDir}
  set ensPbFilePrefix = ${dynamicEnsBFilePrefix}
  set ensPbMemFmt = "${dynamicEnsBMemFmt}"
  set ensPbNMembers = ${dynamicEnsBNMembers}
else
  set ensPbDir = ${fixedEnsBDir}
  set ensPbFilePrefix = ${fixedEnsBFilePrefix}
  set ensPbMemFmt = "${fixedEnsBMemFmt}"
  set ensPbNMembers = ${fixedEnsBNMembers}
endif
set enspsed = EnsemblePbMembers
cat >! ${enspsed}SEDF.yaml << EOF
/${enspsed}/c\
EOF

# TODO: this indentation only works for pure EnVar, not Hybrid EnVar
set indent = "    "
set member = 1
while ( $member <= ${ensPbNMembers} )
  set memDir = `${memberDir} ens $member "${ensPbMemFmt}"`
  set filename = ${ensPbDir}/${prevValidDate}${memDir}/${ensPbFilePrefix}.${fileDate}.nc
  if ( $member < ${ensPbNMembers} ) then
    set filename = ${filename}\\
  endif
cat >>! ${enspsed}SEDF.yaml << EOF
${indent}- <<: *state\
${indent}  filename: ${filename}
EOF

  @ member++
end
sed -f ${enspsed}SEDF.yaml $prevYAML >! $appyaml
rm ${enspsed}SEDF.yaml

exit 0
