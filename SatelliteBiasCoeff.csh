#!/bin/csh -f
#Create bias correction input files

date

# Setup environment
# =================
source config/environment.csh
source config/filestructure.csh
source config/variational.csh
source config/modeldata.csh
source config/builds.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yyyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c1-4`
set mmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c5-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set WorkDir = ${satelliteBiasDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

# yaml for satellite bias conversion to IODA
set YAML = ${ConfigDir}/ObsPlugs/varbc/satbias_converter.yaml
set metopaYAML = ${ConfigDir}/ObsPlugs/varbc/satbias_converter_metop-a.yaml
set metopcYAML = ${ConfigDir}/ObsPlugs/varbc/satbias_converter_metop-c.yaml

# determine which metop sensors to concatenate and set list of sensors
# depending on thisValidDate
if ( ${thisValidDate} > 2019071400 && ${thisValidDate} < 2021110100 ) then
  cat $metopaYAML >> $YAML
  cat $metopcYAML >> $YAML
  set amsua = (amsua_n15 amsua_n18 amsua_n19 amsua_aqua amsua_metop-a amsua_metop-b amsua_metop-c)
  set mhs   = (mhs_n18 mhs_n19 mhs_metop-a mhs_metop-b mhs_metop-c)
  set iasi  = (iasi_metop-a iasi_metop-b iasi_metop-c)
else if ( ${thisValidDate} > 2021110100 ) then
  cat $metopcYAML >> $YAML
  set amsua = (amsua_n15 amsua_n18 amsua_n19 amsua_aqua amsua_metop-b amsua_metop-c)
  set mhs   = (mhs_n18 mhs_n19 mhs_metop-b mhs_metop-c)
  set iasi  = (iasi_metop-b iasi_metop-c)
else
  set amsua = (amsua_n15 amsua_n18 amsua_n19 amsua_aqua amsua_metop-a amsua_metop-b)
  set mhs   = (mhs_n18 mhs_n19 mhs_metop-a mhs_metop-b)
  set iasi  = (iasi_metop-a iasi_metop-b)
endif
cp $YAML .

echo '$amsua $mhs $iasi' $amsua $mhs $iasi

# run the satbias2ioda executable to convert satellite bias files to IODA-v2
# for observations found in folder
# ==================
rm ./${satbias2iodaEXE}
ln -sfv ${satbias2iodaBuildDir}/${satbias2iodaEXE} ./
./${satbias2iodaEXE} $YAML >&! log_satbias

# Check status
# ============
#grep "" log_satbias
#if ( $status != 0 ) then
#  echo "ERROR in $0 : satbias2ioda failed" > ./FAIL
#  exit 1
#endif

# link satbias to satbias_cov
foreach obs ( *".h5"* )
  set f1 = `echo "${obs}" | cut -d'_' -f1`
  set f2 = `echo "${obs}" | cut -d'_' -f2`
  set f3 = `echo "${obs}" | cut -d'_' -f3`
  set satbias_cov = ${f1}_cov_${f2}_${f3}
  ln -svf $obs $satbias_cov 
end

# extract tlapmean for each sensor and satellite
# mean temperature lapse rate for non-linear
foreach sensor ($amsua $mhs $iasi) 
  foreach sensorsat ($sensor)
    echo 'Extracting tlaps for '$sensorsat
    grep $sensorsat satbias_crtm_in > log0.$sensorsat
    awk  '{print $2, "\t", $3, "\t",$4 }'  log0.$sensorsat > log1.$sensorsat
    cat log1.$sensorsat | xargs -L1 > ${sensorsat}_tlapmean.txt
    rm log0.$sensorsat log1.$sensorsat
  end
end

date

exit 0
