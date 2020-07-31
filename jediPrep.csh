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

# MPAS mesh graph info
set meshFile = ./${BGFilePrefix}.${fileDate}.nc
ln -sf $GRAPHINFO_DIR/x1.${MPAS_NCELLS}.graph.info* .

# lookup tables
ln -sf ${MPASBUILDDIR}/src/core_atmosphere/physics/physics_wrf/files/* .

# Copy/revise time info in MPAS namelist
# ======================================
cp -v $DA_NML_DIR/* .

cp -v ${RESSPECIFICDIR}/namelist.atmosphere_da ./namelist.atmosphere
cp -v namelist.atmosphere orig_namelist.atmosphere
cat >! newnamelist << EOF
  /config_start_time /c\
   config_start_time      = '${NMLDate}'
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


# Generate yaml
# =======================================

## Copy BASE MPAS-JEDI yaml
cp -v ${CONFIGDIR}/applicationBase/${self_DAType}.yaml orig_jedi0.yaml

set AnalyzeHydrometeors = 0

## Add selected observations (see control.csh)
foreach obs ($self_ObsList)
  echo "Preparing YAML for ${obs} observations"
  set missing=0
  set SUBYAML=ObsPlugs/${self_DAMode}/${obs}
  if ( "$obs" =~ *"abi"* ) then
    find ${InDBDir}/abi*_obs_*.nc4 -mindepth 0 -maxdepth 0
    if ($? > 0) then
      set missing=1
    else
      set brokenLinks=( `find ${InDBDir}/abi*_obs_*.nc4 -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
      foreach link ($brokenLinks)
        set missing=1
      end
    endif
    if ($missing == 0) then
      echo "ABI data is present and selected; adding ABI to the YAML"
    else
      echo "ABI data is selected, but missing; NOT adding ABI to the YAML"
    endif
  else if ( "$obs" =~ *"conv"* ) then
    #KLUDGE to handle missing qv for sondes at single time
    if ( ${thisValidDate} == 2018043006 ) then
      set SUBYAML=${SUBYAML}-2018043006
    endif
  endif

  ## determine if hydrometeor variables will be analyzed
  # TODO: instead should grep for Clouds in ${CONFIGDIR}/${SUBYAML}.yaml
  if ( "$obs" =~ "all"* ) then
    set AnalyzeHydrometeors = 1
  endif

  if ($missing == 0) then
    cat ${CONFIGDIR}/${SUBYAML}.yaml >> orig_jedi0.yaml
  endif
end


## QC characteristics
sed -i 's@RADTHINDISTANCE@'${RADTHINDISTANCE}'@g' orig_jedi0.yaml
sed -i 's@RADTHINAMOUNT@'${RADTHINAMOUNT}'@g' orig_jedi0.yaml

# TODO(JJG): revise these date replacements to loop over
#            all relevant dates to this application (e.g., 4DEnVar?)
## revise previous date
sed -i 's@2018-04-14_18.00.00@'${prevFileDate}'@g' orig_jedi0.yaml
sed -i 's@2018041418@'${prevValidDate}'@g' orig_jedi0.yaml
sed -i 's@2018-04-14T18:00:00Z@'${prevConfDate}'@g'  orig_jedi0.yaml

## revise current date
sed -i 's@2018-04-15_00.00.00@'${fileDate}'@g' orig_jedi0.yaml
sed -i 's@2018041500@'${thisValidDate}'@g' orig_jedi0.yaml
sed -i 's@2018-04-15T00:00:00Z@'${ConfDate}'@g' orig_jedi0.yaml

## revise window length
sed -i 's@PT6H@PT'${self_WindowHR}'H@g' orig_jedi0.yaml


## File naming
sed -i 's@CRTMTABLES@'${CRTMTABLES}'@g' orig_jedi0.yaml
sed -i 's@InDBDir@'${InDBDir}'@g' orig_jedi0.yaml
sed -i 's@OutDBDir@'${OutDBDir}'@g' orig_jedi0.yaml
sed -i 's@obsPrefix@'${obsPrefix}'@g' orig_jedi0.yaml
sed -i 's@geoPrefix@'${geoPrefix}'@g' orig_jedi0.yaml
sed -i 's@diagPrefix@'${diagPrefix}'@g' orig_jedi0.yaml
sed -i 's@DAMode@'${self_DAMode}'@g' orig_jedi0.yaml
sed -i 's@nEnsDAMembers@'${nEnsDAMembers}'@g' orig_jedi0.yaml
if ( "$self_DAType" =~ *"eda"* ) then
  sed -i 's@OOPSMemberDir@/%{member}%@g' orig_jedi0.yaml
else
  sed -i 's@OOPSMemberDir@@g' orig_jedi0.yaml
endif
sed -i 's@meshFile@'${meshFile}'@g' orig_jedi0.yaml
sed -i 's@bgStatePrefix@'${BGFilePrefix}'@g' orig_jedi0.yaml
#sed -i 's@bgStateDir@'${CyclingDAInDir}'@g' orig_jedi0.yaml
sed -i 's@bgStateDir@'${self_WorkDir}'/'${bgDir}'@g' orig_jedi0.yaml
sed -i 's@anStatePrefix@'${ANFilePrefix}'@g' orig_jedi0.yaml
#sed -i 's@anStateDir@'${CyclingDAOutDir}'@g' orig_jedi0.yaml
sed -i 's@anStateDir@'${self_WorkDir}'/'${anDir}'@g' orig_jedi0.yaml


## revise full line configs
cat >! fulllineSEDF.yaml << EOF
  /window begin: /c\
  window begin: '${halfprevConfDate}'
EOF

sed -f fulllineSEDF.yaml orig_jedi0.yaml >! orig_jedi1.yaml
rm fulllineSEDF.yaml


## fill in model and analysis variable configs
set JEDIANVars = ( \
  temperature \
  spechum \
  uReconstructZonal \
  uReconstructMeridional \
  surface_pressure \
)
if ( $AnalyzeHydrometeors == 1 ) then
  foreach hydro ($MPASHydroVars)
    set JEDIANVars = ($JEDIANVars index_$hydro)
  end
endif

set analysissed = AnalysisVariables
set modelsed = ModelVariables
cat >! ${analysissed}SEDF.yaml << EOF
/${analysissed}/c\
EOF

cat >! ${modelsed}SEDF.yaml << EOF
/${modelsed}/c\
EOF

set ivar = 1
while ( $ivar <= ${#JEDIANVars} )
  set var = $JEDIANVars[$ivar]
  if ( $ivar < ${#JEDIANVars} ) then
    set var = ${var}\\
  endif
cat >>! ${analysissed}SEDF.yaml << EOF
      - $var
EOF

cat >>! ${modelsed}SEDF.yaml << EOF
    - $var
EOF

  @ ivar++
end
sed -f ${analysissed}SEDF.yaml orig_jedi1.yaml >! orig_jedi2.yaml
rm ${analysissed}SEDF.yaml
sed -f ${modelsed}SEDF.yaml orig_jedi2.yaml >! orig_jedi3.yaml
rm ${modelsed}SEDF.yaml


## fill in ensemble B config
# TODO(JJG): how does ensemble B config generation need to be
#            modified for 4DEnVar?
# TODO(JJG): move this to da as not needed for OMM
if ( "$self_DAType" =~ *"eda"* ) then
  set ensBDir = ${dynamicEnsBDir}
  set ensBFilePrefix = ${dynamicEnsBFilePrefix}
  set ensBMemFmt = "${dynamicEnsBMemFmt}"
  set ensBNMembers = ${dynamicEnsBNMembers}
else
  set ensBDir = ${fixedEnsBDir}
  set ensBFilePrefix = ${fixedEnsBFilePrefix}
  set ensBMemFmt = "${fixedEnsBMemFmt}"
  set ensBNMembers = ${fixedEnsBNMembers}
endif

sed -i 's@bumpLocDir@'${bumpLocDir}'@g' orig_jedi3.yaml
sed -i 's@bumpLocPrefix@'${bumpLocPrefix}'@g' orig_jedi3.yaml

set ensbsed = EnsembleBMembers
cat >! ${ensbsed}SEDF.yaml << EOF
/${ensbsed}/c\
EOF

set member = 1
while ( $member <= ${ensBNMembers} )
  set memDir = `${memberDir} ens $member "${ensBMemFmt}"`
  set incvars = incvars
  if ( $member < ${ensBNMembers} ) then
    set incvars = ${incvars}\\
  endif
# TODO: this indentation only works for pure EnVar, not Hybrid EnVar
cat >>! ${ensbsed}SEDF.yaml << EOF
    - filename: ${ensBDir}/${prevValidDate}${memDir}/${ensBFilePrefix}.${fileDate}.nc\
      date: *adate\
      state variables: *${incvars}
EOF

  @ member++
end
sed -f ${ensbsed}SEDF.yaml orig_jedi3.yaml >! jedi.yaml
rm ${ensbsed}SEDF.yaml

exit 0
