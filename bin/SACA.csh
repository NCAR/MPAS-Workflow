#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Process arguments
# =================
## args
# ArgWorkDir: my location
set ArgWorkDir = "$1"

# ArgStateDir: where the initial condition state is located
set ArgStateDir = "$2"

# ArgRunSaca: whether to run saca or not, but copy the 6hr forecast from previous cycle
set ArgRunSaca = "$3"

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/auto/model.csh
source config/auto/staticstream.csh
source config/auto/workflow.csh
source config/auto/saca.csh
source config/auto/naming.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# getObservationsOrNone exposes the observations section of the config for run-time-dependent
# behaviors
source config/auto/scenario.csh observations
setenv getObservationsOrNone "${getLocalOrNone}"

# remove static work directory if it already exists
set WorkDir = "${ExperimentDirectory}/"`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
if ( -d $WorkDir ) then
  rm -r $WorkDir
endif

echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# build, executable, yaml
set myBuildDir = ${SACABuildDir}
set myEXE = ${SACAEXE}
set myYAML = ${WorkDir}/$appyaml

# AppName
set AppName = "saca"

# Remove old logs
rm addincrement.log*

# ================================================================================================
# Previous time info for yaml entries
# ===================================
set prevValidDate = `$advanceCYMDH ${thisValidDate} -${prevBgHR}`
set yy = `echo ${prevValidDate} | cut -c 1-4`
set mm = `echo ${prevValidDate} | cut -c 5-6`
set dd = `echo ${prevValidDate} | cut -c 7-8`
set hh = `echo ${prevValidDate} | cut -c 9-10`

# cold start forecast folder
set StateDir = ${ExperimentDirectory}/${ArgStateDir}/${prevValidDate}

set nCells = $nCellsOuter
set meshRatio = $meshRatioOuter
set TimeStep = $TimeStepOuter
set DiffusionLengthScale = $DiffusionLengthScaleOuter
set RadiationLWInterval = $RadiationLWIntervalOuter
set RadiationSWInterval = $RadiationSWIntervalOuter
set PhysicsSuite = $PhysicsSuiteOuter
set Microphysics = $MicrophysicsOuter
set Convection = $ConvectionOuter
set PBL = $PBLOuter
set Gwdo = $GwdoOuter
set RadiationCloud = $RadiationCloudOuter
set RadiationLW = $RadiationLWOuter
set RadiationSW = $RadiationSWOuter
set SfcLayer = $SfcLayerOuter
set LSM = $LSMOuter

# ====================================
# Input/Output model state preparation
# ====================================
set bg = $backgroundSubDir
mkdir -p ${bg}

# Link bg from StateDir
# ======================
set bgFileOther = ${StateDir}/${FCFilePrefix}.${thisMPASFileDate}.nc
set bgFile = ${bg}/${FCFilePrefix}.$thisMPASFileDate.nc

rm ${bgFile}${OrigFileSuffix} ${bgFile}
ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
ln -sfv ${bgFileOther} ${bgFile}

set an = $analysisSubDir
mkdir -p ${an}

set anFile = ${an}/${ICFilePrefix}.$thisMPASFileDate.nc
rm ${anFile}
cp ${bgFile} ${anFile}

if ( "${ArgRunSaca}" == "False" ) then
  echo "$0 (INFO): RunSaca is False, 6hr fcst copied, exiting with success"
  date
  exit 0
endif

# Link static and template fields files
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set StaticFieldsFile = ${StaticFieldsDirOuter}/${StaticFieldsFileOuter}
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ./${localStaticFieldsFile}
ln -sfv ${StaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${StaticFieldsFile} ${localStaticFieldsFile}

set TemplateFieldsFile = ${TemplateFieldsFileOuter}
rm ./${TemplateFieldsFile}
ln -sfv ${bgFile} ${TemplateFieldsFile}

# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
rm ./x${meshRatio}.${nCells}.graph.info*
ln -sfv $GraphInfoDir/x${meshRatio}.${nCells}.graph.info* .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

if ( ${Microphysics} == 'mp_thompson' ) then
  ln -svf $MPThompsonTablesDir/* .
endif

## copy stream_list/streams configs
cp -v $ModelConfigDir/${AppName}/stream_list.${MPASCore}.${AppName}_background .
cp -v $ModelConfigDir/${AppName}/stream_list.${MPASCore}.${AppName}_obs .
cp -v $ModelConfigDir/${AppName}/stream_list.${MPASCore}.${AppName}_analysis .

rm ${StreamsFile}
cp -v $ModelConfigDir/${AppName}/${StreamsFile} .
sed -i 's@{{nCells}}@'${nCells}'@' ${StreamsFile}
sed -i 's@{{TemplateFieldsPrefix}}@'${WorkDir}'/'${TemplateFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{StaticFieldsPrefix}}@'${WorkDir}'/'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

## copy/modify dynamic namelist
rm $NamelistFile
cp -v $ModelConfigDir/saca/${NamelistFile} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFile
sed -i 's@nCells@'${nCells}'@' $NamelistFile
sed -i 's@modelDT@'${TimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' $NamelistFile
sed -i 's@{{meshRatio}}@'${meshRatio}'@' $NamelistFile

## modify namelist physics
sed -i 's@radtlwInterval@'${RadiationLWInterval}'@' $NamelistFile
sed -i 's@radtswInterval@'${RadiationSWInterval}'@' $NamelistFile
sed -i 's@physicsSuite@'${PhysicsSuite}'@' $NamelistFile
sed -i 's@micropScheme@'${Microphysics}'@' $NamelistFile
sed -i 's@convectionScheme@'${Convection}'@' $NamelistFile
sed -i 's@pblScheme@'${PBL}'@' $NamelistFile
sed -i 's@gwdoScheme@'${Gwdo}'@' $NamelistFile
sed -i 's@radtCldScheme@'${RadiationCloud}'@' $NamelistFile
sed -i 's@radtLWScheme@'${RadiationLW}'@' $NamelistFile
sed -i 's@radtSWScheme@'${RadiationSW}'@' $NamelistFile
sed -i 's@sfcLayerScheme@'${SfcLayer}'@' $NamelistFile
sed -i 's@lsmScheme@'${LSM}'@' $NamelistFile

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  cp $ModelConfigDir/$file .
end

echo "  - xland"   >> keptvars.yaml
echo "  - cldmask" >> keptvars.yaml
echo "  - brtemp"  >> keptvars.yaml

echo ""                               >> geovars.yaml
echo "  - field name: ni"             >> geovars.yaml
echo "    mpas template field: theta" >> geovars.yaml
echo "    mpas identity field: ni"    >> geovars.yaml

# ======================
# Link observations data
# ======================
rm -r ${InDBDir}
mkdir -p ${InDBDir}

echo "Retrieving data"
# need to change to mainScriptDir for getObservationsOrNone to work
cd ${mainScriptDir}

# Check for instrument-specific directory first
set key = IODADirectory
set address = "resources.${observations__resource}.${key}.${AppName}.common"
set $key = "`$getObservationsOrNone ${address}`"

# prefix
set key = IODAPrefix
set address = "resources.${observations__resource}.${key}.${AppName}"
set $key = "`$getObservationsOrNone ${address}`"

cd ${WorkDir}
set obsFile = ${IODADirectory}/${IODAPrefix}_obs.$thisMPASFileDate.nc
set sacaObsFile = ${IODAPrefix}_obs_${thisValidDate}.nc
if ( ! -e ${obsFile} ) then
  echo "$0 (WARNING): skipping ${thisValidDate}, no SACA observation is available for this date"
  date
  exit 0
endif
cp ${obsFile} ${InDBDir}/${sacaObsFile}

# Rename variables
module load nco
ncrename -v BCM_G16,cldmask  ${InDBDir}/${sacaObsFile}
ncrename -v BT_G16C13,brtemp ${InDBDir}/${sacaObsFile}

# =============
# Generate yaml
# =============
## Copy jedi/applications yaml
set thisYAML = orig.yaml
cp -v ${ConfigDir}/jedi/applications/$appyaml $thisYAML

## AppName
sed -i 's@{{AppName}}@'${AppName}'@g' $thisYAML

## namelist
sed -i 's@{{SACANamelistFile}}@'${WorkDir}'/'${NamelistFile}'@' $thisYAML

## streams
sed -i 's@{{SACAStreamsFile}}@'${WorkDir}'/'${StreamsFile}'@' $thisYAML

## cloud building algorithm configuration
# convert to lower-case
set buildMADWRF_lower    = `echo "${buildMADWRF}"    | sed 's/\(.*\)/\L\1/'`
set buildGSDCloud_lower  = `echo "${buildGSDCloud}"  | sed 's/\(.*\)/\L\1/'`
set saturateQv_lower     = `echo "${saturateQv}"     | sed 's/\(.*\)/\L\1/'`
set conserveThetaV_lower = `echo "${conserveThetaV}" | sed 's/\(.*\)/\L\1/'`
sed -i 's@{{buildMADWRF}}@'${buildMADWRF_lower}'@g' $thisYAML
sed -i 's@{{buildGSDCloud}}@'${buildGSDCloud_lower}'@g' $thisYAML
sed -i 's@{{saturateQv}}@'${saturateQv_lower}'@g' $thisYAML
sed -i 's@{{conserveThetaV}}@'${conserveThetaV_lower}'@g' $thisYAML
sed -i 's@{{cldfraDef}}@'${cldfraDef}'@g' $thisYAML
sed -i 's@{{cldfraThresh}}@'${cldfraThresh}'@g' $thisYAML
sed -i 's@{{cldmaskThresh}}@'${cldmaskThresh}'@g' $thisYAML
sed -i 's@{{cldBluidHeigt}}@'${cldBluidHeigt}'@g' $thisYAML

## current date
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML

# saca bg file
sed -i 's@{{bgStateDir}}@'${WorkDir}'/'${bg}'@g' $thisYAML
sed -i 's@{{bgStatePrefix}}@'${FCFilePrefix}'@g' $thisYAML
sed -i 's@{{thisMPASFileDate}}@'${thisMPASFileDate}'@g' $thisYAML

# saca an file
sed -i 's@{{anStateDir}}@'${WorkDir}'/'${an}'@g' $thisYAML
sed -i 's@{{anStatePrefix}}@'${ICFilePrefix}'@g' $thisYAML

# saca obs
sed -i 's@{{InDBDir}}@'${WorkDir}'/'${InDBDir}'@g' $thisYAML
sed -i 's@{{SACAObs}}@'${sacaObsFile}'@g' $thisYAML

# state variables
set Variables = ($SACAStateVariables)
set VarSub = ""
foreach var ($Variables)
  set VarSub = "$VarSub$var,"
end
# remove trailing comma
set VarSub = `echo "$VarSub" | sed 's/.$//'`
# optional for diag and diag_cldfra
if (${runSacaDiag} == True) then
  set VarSub = $VarSub",uReconstructZonal,uReconstructMeridional"
  echo "uReconstructZonal"      >> stream_list.${MPASCore}.${AppName}_background
  echo "uReconstructMeridional" >> stream_list.${MPASCore}.${AppName}_background
  echo "uReconstructZonal"      >> stream_list.${MPASCore}.${AppName}_analysis
  echo "uReconstructMeridional" >> stream_list.${MPASCore}.${AppName}_analysis
endif

# added variables to saca_obs
set addedVars = `cat stream_list.${MPASCore}.${AppName}_obs`
set addedVarSub = ""
foreach var ($addedVars)
  set addedVarSub = "$addedVarSub$var,"
end
# remove trailing comma
set addedVarSub = `echo "$addedVarSub" | sed 's/.$//'`

sed -i 's@{{SACAStateVariables}}@'$VarSub'@' $thisYAML
sed -i 's@{{addedVars}}@'${addedVarSub}'@g' $thisYAML

cp $thisYAML $appyaml

limit stacksize unlimited
setenv GFORTRAN_CONVERT_UNIT 'big_endian:101-200'
setenv FI_CXI_RX_MATCH_MODE 'hybrid'

setenv OOPS_TRACE 1
setenv OOPS_DEBUG 1
setenv OOPS_INFO 1

# Run the executable
# ==================
ln -sfv ${myBuildDir}/${myEXE} ./
mpiexec ./${myEXE} $myYAML ./addincrement.log >& addincrement.log.all


# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' addincrement.log
if ( $status != 0 ) then
  echo "ERROR in $0 : addincrement application failed" > ./FAIL
  exit 1
endif

# ================================================================================================
## change static fields to a link, keeping for transparency
rm ${localStaticFieldsFile}
mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}

# Remove netcdf lock files
rm *.nc*.lock
rm */*.nc*.lock

# Remove core file
rm core

date

exit 0
