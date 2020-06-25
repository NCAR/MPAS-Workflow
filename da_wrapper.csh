#!/bin/csh

#
#set environment:
# =============================================
source ./setup.csh

setenv DATE              CDATE
setenv WINDOW_HR         WINDOWHR
setenv PREVIOUS_FC_DIR   FCDIR
setenv BG_STATE_PREFIX   BGSTATEPREFIX
set OBS_LIST = ("${OBSLIST}")
setenv VARBC_TABLE       VARBCTABLE
setenv DA_TYPE           DATYPESUB
setenv DA_MODE           DAMODESUB
setenv DIAG_TYPE         DIAGTYPE
setenv DA_JOB_SCRIPT     DAJOBSCRIPT
setenv DEPEND_TYPE       DEPENDTYPE
setenv VF_JOB_SCRIPT     VFJOBSCRIPT
setenv YAML_TOP_DIR      YAMLTOPDIR
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
set YAML_DATE     = ${yy}-${mm}-${dd}T${hh}:00:00Z

set PDATE = `${BIN_DIR}/advance_cymdh ${DATE} -${WINDOW_HR}`
set yy = `echo ${PDATE} | cut -c 1-4`
set mm = `echo ${PDATE} | cut -c 5-6`
set dd = `echo ${PDATE} | cut -c 7-8`
set hh = `echo ${PDATE} | cut -c 9-10`
set PFILE_DATE     = ${yy}-${mm}-${dd}_${hh}.00.00
set PNAMELIST_DATE = ${yy}-${mm}-${dd}_${hh}:00:00
set PYAML_DATE     = ${yy}-${mm}-${dd}T${hh}:00:00Z

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
set PHALF_DATE = `${BIN_DIR}/advance_cymdh ${DATE} -${HALF_DT_HR_MINUS}`
set yy = `echo ${PHALF_DATE} | cut -c 1-4`
set mm = `echo ${PHALF_DATE} | cut -c 5-6`
set dd = `echo ${PHALF_DATE} | cut -c 7-8`
set hh = `echo ${PHALF_DATE} | cut -c 9-10`
#set PHALFFILE_DATE     = ${yy}-${mm}-${dd}_${hh}.${HALF_mi}.00
#set PHALFNAMELIST_DATE = ${yy}-${mm}-${dd}_${hh}:${HALF_mi}:00
set PHALFYAML_DATE     = ${yy}-${mm}-${dd}T${hh}:${HALF_mi}:00Z

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
mkdir Data

#Link conventional data
# ======================
ln -fsv $CONV_OBS_DIR/${DATE}/aircraft_obs*.nc4 Data/
ln -fsv $CONV_OBS_DIR/${DATE}/gnssro_obs*.nc4 Data/
ln -fsv $CONV_OBS_DIR/${DATE}/satwind_obs*.nc4 Data/
ln -fsv $CONV_OBS_DIR/${DATE}/sfc_obs*.nc4 Data/
ln -fsv $CONV_OBS_DIR/${DATE}/sondes_obs*.nc4 Data/

#Link AMSUA data
# ==============
ln -fsv $AMSUA_OBS_DIR/${DATE}/amsua*_obs_*.nc4 Data/

#Link ABI data
# ============
ln -fsv $ABI_OBS_DIR/${DATE}/abi*_obs_*.nc4 Data/

#Link AHI data
# ============
ln -fsv $AHI_OBS_DIR/${DATE}/ahi*_obs_*.nc4 Data/

#Link CRTM coeff files
# ====================
#ln -fsv ${CRTMTABLES}/*.bin Data/

# ===========
# BACKGROUND
# ===========

# Link bg from previous forecast
# =================================
ln -fsv ${PREVIOUS_FC_DIR}/${BG_STATE_PREFIX}.$FILE_DATE.nc ./${RST_FILE_PREFIX}.$FILE_DATE.nc_orig

# Link VarBC prior
# ====================
ln -fsv ${VARBC_TABLE} Data/satbias_crtm_bak


# Generate yaml
# =======================================

## Copy BASE MPAS-JEDI yaml
cp -v ${YAML_TOP_DIR}/applicationBase/${DA_TYPE}.yaml orig_jedi.yaml

## Add selected observations (see setup.csh)
foreach obs ($OBS_LIST)
  echo "Preparing YAML for ${obs} observations"
  set missing=0
  set SUBYAML=ObsTypePlugs/${DA_MODE}/${obs}
  if ( "$obs" =~ *"abi"* ) then
    find ./Data/abi*_obs_*.nc4 -mindepth 0 -maxdepth 0
    if ($? > 0) then
      set missing=1
    else
      set brokenLinks=( `find ./Data/abi*_obs_*.nc4 -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
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

  if ($missing == 0) then
    cat ${YAML_TOP_DIR}/${SUBYAML}.yaml >> orig_jedi.yaml
  endif
end

sed -i 's@DATYPE@'${DIAG_TYPE}'@g' orig_jedi.yaml
sed -i 's@RADTHINDISTANCE@'${RADTHINDISTANCE}'@g' orig_jedi.yaml
sed -i 's@RADTHINAMOUNT@'${RADTHINAMOUNT}'@g' orig_jedi.yaml
sed -i 's@CRTMTABLES@'${CRTMTABLES}'@g' orig_jedi.yaml

## Revise time info
sed 's/'${RST_FILE_PREFIX}'.2018-04-15_00.00.00.nc/'${RST_FILE_PREFIX}'.'${FILE_DATE}'.nc/g; s/2018041500/'${DATE}'/g; s/2018-04-15T00:00:00Z/'${YAML_DATE}'/g'  orig_jedi.yaml  > new0.yaml
sed 's/'${RST_FILE_PREFIX}'.2018-04-14_18.00.00.nc/'${RST_FILE_PREFIX}'.'${PFILE_DATE}'.nc/g; s/2018041418/'${PDATE}'/g; s/2018-04-14T18:00:00Z/'${PYAML_DATE}'/g'  new0.yaml  > new1.yaml
sed 's/x1.'${MPAS_NCELLS}'.init.2018-04-15_00.00.00.nc/x1.'${MPAS_NCELLS}'.init.'${FILE_DATE}'.nc/g' new1.yaml > new2.yaml
sed 's/PT6H/PT'${WINDOW_HR}'H/g' new2.yaml > new3.yaml

cat >! new4.yaml << EOF
  /window_begin: /c\
  window_begin: '${PHALFYAML_DATE}'
  /datadir: /c\
          datadir: ${BUMP_FILES_DIR}
EOF

sed -f new4.yaml new3.yaml >! jedi.yaml
rm new0.yaml new1.yaml new2.yaml new3.yaml new4.yaml


# Submit DA job script
# =================================
set JDEP=`cat ${JOBCONTROL}/last_${DEPEND_TYPE}_job`
if ( ${JDEP} == 0 ) then
  set JDA = `qsub -h ${DA_JOB_SCRIPT}`
else
  set JDA = `qsub -W depend=afterok:${JDEP} ${DA_JOB_SCRIPT}`
endif
echo "${JDA}" > ${JOBCONTROL}/last_${DA_MODE}_job


# Submit VF job script
# =================================
if ( ${VERIFYAFTERDA} > 0 ) then
  set JVF = `qsub -W depend=afterok:$JDA ${VF_JOB_SCRIPT}`
endif


# Release DA job
# =================================
if ( ${JDEP} == 0 ) then
  qrls $JDA
endif


exit
