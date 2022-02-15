#!/bin/csh -f
#Create bias correction input files

date

# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
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
set WorkDir = ${VARBCDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

## RDA bias data
set RDAabiasDir = ${RDAdataDir}/ds735.0/abias/${yyyy}
set RDAabiaspcDir = ${RDAdataDir}/ds735.0/abiaspc/${yyyy}

set abias_tar_file = ${RDAabiasDir}/abias.${yymmdd}.tar.gz
set abiaspc_tar_file = ${RDAabiaspcDir}/abiaspc.${yymmdd}.tar.gz

set abias_file = gdas.abias.t${hh}z.${yymmdd}.txt
set abiaspc_file = gdas.abiaspc.t${hh}z.${yymmdd}.txt

set tmp_abiastar_dir = ${yymmdd}.abias
set tmp_abiaspctar_dir = ${yymmdd}.abiaspc

# Untar bias files
tar -x -f ${abias_tar_file} ${tmp_abiastar_dir}/${abias_file}
tar -x -f ${abiaspc_tar_file} ${tmp_abiaspctar_dir}/${abiaspc_file}

# Move files to WorkDir and remove temporary folder
mv ${tmp_abiastar_dir}/${abias_file} .
mv ${tmp_abiaspctar_dir}/${abiaspc_file} .
rmdir ${tmp_abiastar_dir}
rmdir ${tmp_abiaspctar_dir}

# Create links to pre-defined names
ln -sfv ${abias_file} ./satbias_crtm_in
ln -sfv ${abiaspc_file} ./satbias_crtm_pc

# Yaml for satellite bias conversion to IODA
set YAML = ${ConfigDir}/ObsPlugs/varbc/satbias_converter.yaml

# Concatenate metop-c sensor if thisValidDate > 20190714
if ( ${thisValidDate} > 2019071400 ) then
  set metopCYAML = ${ConfigDir}/ObsPlugs/varbc/metopC.yaml
  cat $metopCYAML >> $YAML
endif
cp $YAML .

# Run the satbias2ioda executable to convert satellite bias files to IODA-v2
# for observations found in folder
# ==================
source ${ConfigDir}/environmentForJedi.csh ${BuildCompiler}
rm ./${satbias2iodaEXE}
ln -sfv ${satbias2iodaBuildDir}/${satbias2iodaEXE} ./
./${satbias2iodaEXE} $YAML >&! log_satbias

# Link satbias to satbias_cov
foreach obs ( *".h5"* )
  set f1 = `echo "${obs}" | cut -d'_' -f1`
  set f2 = `echo "${obs}" | cut -d'_' -f2`
  set f3 = `echo "${obs}" | cut -d'_' -f3`
  set satbias_cov = ${f1}_cov_${f2}_${f3}
  ln -svf $obs $satbias_cov 
end

# Extract tlapmean for each sensor and satellite
# mean temperature lapse rate for non-linear
if ( ${thisValidDate} > 2019071400 ) then
  set amsua = (amsua_n15 amsua_n18 amsua_n19 amsua_aqua amsua_metop-a amsua_metop-b amsua_metop-c)
  set mhs   = (mhs_n18 mhs_n19 mhs_metop-a mhs_metop-b mhs_metop-c)
  set iasi  = (iasi_metop-a iasi_metop-b iasi_metop-c)
else
  set amsua = (amsua_n15 amsua_n18 amsua_n19 amsua_aqua amsua_metop-a amsua_metop-b)
  set mhs   = (mhs_n18 mhs_n19 mhs_metop-a mhs_metop-b)
  set iasi  = (iasi_metop-a iasi_metop-b)
endif

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
