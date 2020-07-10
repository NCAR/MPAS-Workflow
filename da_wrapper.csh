#!/bin/csh

#
# Setup environment:
# =============================================
source ./setup.csh

setenv DATE              CDATE
setenv WINDOW_HR         WINDOWHR
set OBS_LIST = ("${OBSLIST}")
setenv VARBC_TABLE       VARBCTABLE
setenv DA_TYPE           DATYPESUB
setenv DA_MODE           DAMODESUB
setenv DIAG_TYPE         DIAGTYPE
setenv DA_JOB_SCRIPT     DAJOBSCRIPT
setenv thisDependsOn     DEPENDTYPE
setenv VF_JOB_SCRIPT     VFJOBSCRIPT
setenv CONFIG_DIR        CONFIGDIR
setenv RES_SPECIFIC_DIR  RESSPECIFICDIR


#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${DATE} | cut -c 1-4`
set mm = `echo ${DATE} | cut -c 5-6`
set dd = `echo ${DATE} | cut -c 7-8`
set hh = `echo ${DATE} | cut -c 9-10`
set FILE_DATE     = ${yy}-${mm}-${dd}_${hh}.00.00
set NAMELIST_DATE = ${yy}-${mm}-${dd}_${hh}:00:00
set CONF_DATE     = ${yy}-${mm}-${dd}T${hh}:00:00Z

set PDATE = `$advanceCYMDH ${DATE} -${WINDOW_HR}`
set yy = `echo ${PDATE} | cut -c 1-4`
set mm = `echo ${PDATE} | cut -c 5-6`
set dd = `echo ${PDATE} | cut -c 7-8`
set hh = `echo ${PDATE} | cut -c 9-10`
set PFILE_DATE     = ${yy}-${mm}-${dd}_${hh}.00.00
set PNAMELIST_DATE = ${yy}-${mm}-${dd}_${hh}:00:00
set PCONF_DATE     = ${yy}-${mm}-${dd}T${hh}:00:00Z

#TODO: HALF STEP ONLY WORKS FOR INTEGER VALUES OF WINDOW_HR
@ HALF_DT_HR = ${WINDOW_HR} / 2
@ ODD_DT = ${WINDOW_HR} % 2
@ HALF_mi_ = ${ODD_DT} * 30
set HALF_mi = $HALF_mi_
if ( $HALF_mi_ < 10 ) then
  set HALF_mi = 0$HALF_mi
endif

#@ HALF_DT_HR_PLUS = ${HALF_DT_HR}
@ HALF_DT_HR_MINUS = ${HALF_DT_HR} + ${ODD_DT}
set PHALF_DATE = `$advanceCYMDH ${DATE} -${HALF_DT_HR_MINUS}`
set yy = `echo ${PHALF_DATE} | cut -c 1-4`
set mm = `echo ${PHALF_DATE} | cut -c 5-6`
set dd = `echo ${PHALF_DATE} | cut -c 7-8`
set hh = `echo ${PHALF_DATE} | cut -c 9-10`
#set PHALFFILE_DATE     = ${yy}-${mm}-${dd}_${hh}.${HALF_mi}.00
#set PHALFNAMELIST_DATE = ${yy}-${mm}-${dd}_${hh}:${HALF_mi}:00
set PHALFCONF_DATE     = ${yy}-${mm}-${dd}T${hh}:${HALF_mi}:00Z

# ============================================================
# ============================================================
# Copy/link files: BUMP B matrix, namelist, yaml, bg, obs data
# ============================================================
# ============================================================

# MPAS mesh graph info
ln -sf $GRAPHINFO_DIR/x1.${MPAS_NCELLS}.graph.info* .

# lookup tables
ln -sf ${MPASBUILDDIR}/src/core_atmosphere/physics/physics_wrf/files/* .

# Copy/revise time info in MPAS namelist
# ======================================
cp -v $DA_NML_DIR/* .

cp -v ${RES_SPECIFIC_DIR}/namelist.atmosphere_da ./namelist.atmosphere
cp -v namelist.atmosphere orig_namelist.atmosphere
cat >! newnamelist << EOF
  /config_start_time /c\
   config_start_time      = '${NAMELIST_DATE}'
EOF
sed -f newnamelist orig_namelist.atmosphere >! namelist.atmosphere
rm newnamelist

# =============
# OBSERVATIONS
# =============
mkdir -p ${InDBDir}
set member = 1
while ( $member <= ${nEnsDAMembers} )
  set memDir = `${memberDir} $DA_TYPE $member`
  mkdir -p ${OutDBDir}${memDir}
  @ member++
end

# Link conventional data
# ======================
ln -fsv $CONV_OBS_DIR/${DATE}/aircraft_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${DATE}/gnssro_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${DATE}/satwind_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${DATE}/sfc_obs*.nc4 ${InDBDir}/
ln -fsv $CONV_OBS_DIR/${DATE}/sondes_obs*.nc4 ${InDBDir}/

# Link AMSUA data
# ==============
ln -fsv $AMSUA_OBS_DIR/${DATE}/amsua*_obs_*.nc4 ${InDBDir}/

# Link ABI data
# ============
ln -fsv $ABI_OBS_DIR/${DATE}/abi*_obs_*.nc4 ${InDBDir}/

# Link AHI data
# ============
ln -fsv $AHI_OBS_DIR/${DATE}/ahi*_obs_*.nc4 ${InDBDir}/

# Link VarBC prior
# ====================
ln -fsv ${VARBC_TABLE} ${InDBDir}/satbias_crtm_bak


# Generate yaml
# =======================================

## Copy BASE MPAS-JEDI yaml
cp -v ${CONFIG_DIR}/applicationBase/${DA_TYPE}.yaml orig_jedi0.yaml

set AnalyzeHydrometeors = 0

## Add selected observations (see setup.csh)
foreach obs ($OBS_LIST)
  echo "Preparing YAML for ${obs} observations"
  set missing=0
  set SUBYAML=ObsTypePlugs/${DA_MODE}/${obs}
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
    if ( ${DATE} == 2018043006 ) then
      set SUBYAML=${SUBYAML}-2018043006
    endif
  endif

  ## determine if hydrometeor variables will be analyzed
  if ( "$obs" =~ "all"* ) then
    set AnalyzeHydrometeors = 1
  endif

  if ($missing == 0) then
    cat ${CONFIG_DIR}/${SUBYAML}.yaml >> orig_jedi0.yaml
  endif
end

## fill in observation characteristics
sed -i 's@DATYPE@'${DIAG_TYPE}'@g' orig_jedi0.yaml
sed -i 's@RADTHINDISTANCE@'${RADTHINDISTANCE}'@g' orig_jedi0.yaml
sed -i 's@RADTHINAMOUNT@'${RADTHINAMOUNT}'@g' orig_jedi0.yaml
sed -i 's@CRTMTABLES@'${CRTMTABLES}'@g' orig_jedi0.yaml
sed -i 's@InDBDir@'${InDBDir}'@g' orig_jedi0.yaml
sed -i 's@OutDBDir@'${OutDBDir}'@g' orig_jedi0.yaml
sed -i 's@obsPrefix@'${obsPrefix}'@g' orig_jedi0.yaml
sed -i 's@geoPrefix@'${geoPrefix}'@g' orig_jedi0.yaml
sed -i 's@diagPrefix@'${diagPrefix}'@g' orig_jedi0.yaml

if ( "$DA_TYPE" =~ *"eda"* ) then
  sed -i 's@OOPSMemberDir@/%{member}%@g' orig_jedi0.yaml
  sed -i 's@nEnsDAMembers@'${nEnsDAMembers}'@g' orig_jedi0.yaml
else
  sed -i 's@OOPSMemberDir@@g' orig_jedi0.yaml
endif

# TODO(JJG): revise these date replacements to loop over
#            all relevant dates to this application (e.g., 4DEnVar?)
## revise previous date
sed -i 's@2018-04-14_18.00.00@'${PFILE_DATE}'@g' orig_jedi0.yaml
sed -i 's@2018041418@'${PDATE}'@g' orig_jedi0.yaml
sed -i 's@2018-04-14T18:00:00Z@'${PCONF_DATE}'@g'  orig_jedi0.yaml

## revise current date
sed -i 's@2018-04-15_00.00.00@'${FILE_DATE}'@g' orig_jedi0.yaml
sed -i 's@2018041500@'${DATE}'@g' orig_jedi0.yaml
sed -i 's@2018-04-15T00:00:00Z@'${CONF_DATE}'@g' orig_jedi0.yaml

## revise window length
sed -i 's@PT6H@PT'${WINDOW_HR}'H@g' orig_jedi0.yaml

## revise full line configs
cat >! fulllineSEDF.yaml << EOF
  /window_begin: /c\
  window_begin: '${PHALFCONF_DATE}'
EOF

sed -f fulllineSEDF.yaml orig_jedi0.yaml >! orig_jedi1.yaml
rm fulllineSEDF.yaml

if ( "$DATYPE" =~ *"eda"* ) then
  set topEnsBDir = ${FCCY_WORK_DIR}
  set ensBMemFmt = "${oopsMemFmt}"
  set nEnsBMembers = ${nEnsDAMembers}
else
  set topEnsBDir = ${fixedEnsembleB}
  set ensBMemFmt = "${fixedEnsMemFmt}"
  set nEnsBMembers = ${nFixedMembers}
endif

## fill in ensemble B config
# TODO(JJG): how does this ensemble config generation need to be
#            modified for 4DEnVar?
sed -i 's@bumpLocDir@'${bumpLocDir}'@g' orig_jedi1.yaml
sed -i 's@bumpLocPrefix@'${bumpLocPrefix}'@g' orig_jedi1.yaml

set ensbsed = EnsembleBMembers
cat >! ${ensbsed}SEDF.yaml << EOF
/${ensbsed}/c\
EOF

set member = 1
while ( $member <= ${nEnsBMembers} )
  set memDir = `${memberDir} ens $member "${ensBMemFmt}"`
  set adate = adate
  if ( $member < ${nEnsBMembers} ) then
     set adate = ${adate}\\
  endif
cat >>! ${ensbsed}SEDF.yaml << EOF
      - filename: ${topEnsBDir}/${PDATE}${memDir}/${FC_FILE_PREFIX}.${FILE_DATE}.nc\
        date: *${adate}
EOF

  @ member++
end
sed -f ${ensbsed}SEDF.yaml orig_jedi1.yaml >! orig_jedi2.yaml
rm ${ensbsed}SEDF.yaml


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
sed -f ${analysissed}SEDF.yaml orig_jedi2.yaml >! orig_jedi3.yaml
rm ${analysissed}SEDF.yaml
sed -f ${modelsed}SEDF.yaml orig_jedi3.yaml >! jedi.yaml
rm ${modelsed}SEDF.yaml


# Submit DA job script
# =================================
#TODO: move all job control to top-level cycling/workflow scripts
set JALL=(`cat ${JOBCONTROL}/last_${thisDependsOn}_job`)
set JDEP = ''
foreach J ($JALL)
  if (${J} != "0" ) then
    set JDEP = ${JDEP}:${J}
  endif
end
set JDA = `qsub -W depend=afterok${JDEP} ${DA_JOB_SCRIPT}`

echo "${JDA}" > ${JOBCONTROL}/last_${DA_MODE}_job

# Submit VF job script
# =================================
if ( ${VERIFYAFTERDA} > 0 && ${VF_JOB_SCRIPT} != "None" ) then
  set JVF = `qsub -W depend=afterok:$JDA ${VF_JOB_SCRIPT}`
endif

exit
