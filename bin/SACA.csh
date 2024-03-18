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

# AppCategory: saca
set AppCategory = "$2"

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/model.csh
source config/auto/staticstream.csh
source config/auto/workflow.csh
source config/auto/saca.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# static work directory
set WorkDir = "${ExperimentDirectory}/"`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# build, executable, yaml
set myBuildDir = ${SACABuildDir}
set myEXE = ${SACAEXE}
set myYAML = ${WorkDir}/$appyaml

# cold start forecst folder
set ColdStartFCDir = "ColdStartFC"

# Remove old logs
rm addincrement.log*

# ================================================================================================

# ====================================
# Input/Output model state preparation
# ====================================
set bg = ${AppCategory}_$backgroundSubDir
mkdir -p ${bg}

# Link bg from StateDirs
# ======================
set bgFileOther = ${ColdStartFCDir}/${thisValidDate}/${FCFilePrefix}.${thisMPASFileDate}.nc
set bgFile = ${bg}/${FCFilePrefix}.$thisMPASFileDate.nc #bg.nc

rm ${bgFile}${OrigFileSuffix} ${bgFile}
ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
ln -sfv ${bgFileOther} ${bgFile}

set an = ${AppCategory}_$analysisSubDir
mkdir -p ${an}

set anFile = ${an}/${ICFilePrefix}.$thisMPASFileDate.nc #update.nc
rm ${anFile}
cp ${bgFile} ${anFile}

# Link static and template fields files
rm ./${localStaticFieldsFile}
rm ./${TemplateFieldsFile}
ln -sfv $GraphInfoDir/${localStaticFieldsFile} .
ln -sfv ${bgFile} ${TemplateFieldsFile} .

# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
rm ./x1.${nCells}.graph.info*
ln -sfv $GraphInfoDir/x1.${nCells}.graph.info* .
  
## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

if (${MicropScheme} == 'mp_thompson' ) then
  ln -svf $MPThompsonTablesDir/* .
endif

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.background \
stream_list.${MPASCore}.analysis \
stream_list.${MPASCore}.ensemble \
stream_list.${MPASCore}.control \
stream_list.${MPASCore}.${AppCategory}_analysis \
stream_list.${MPASCore}.${AppCategory}_background \
stream_list.${MPASCore}.${AppCategory}_obs \
)
  ln -sfv $ModelConfigDir/${AppCategory}/$staticfile .
end

rm ${StreamsFile}
cp -v $ModelConfigDir/${AppCategory}/${StreamsFile} .
sed -i 's@{{nCells}}@'${nCells}'@' ${StreamsFile}
sed -i 's@{{TemplateFieldsPrefix}}@'${WorkDir}'/'${TemplateFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{StaticFieldsPrefix}}@'${WorkDir}'/'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

## copy/modify dynamic namelist
rm $NamelistFile
cp -v $ModelConfigDir/saca/${NamelistFile} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFile
sed -i 's@blockDecompPrefix@'${WorkDir}'/x1.'${nCells}'@' ${NamelistFile}
sed -i 's@modelDT@'${TimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' $NamelistFile
## modify namelist physics
sed -i 's@radtlwInterval@'${RadiationLWInterval}'@' $NamelistFile
sed -i 's@radtswInterval@'${RadiationSWInterval}'@' $NamelistFile
sed -i 's@physicsSuite@'${PhysicsSuite}'@' $NamelistFile
sed -i 's@micropScheme@'${MicropScheme}'@' $NamelistFile
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
set address = "resources.${observations__resource}.${key}.${AppCategory}.common"
set $key = "`$getObservationsOrNone ${address}`"

# prefix
set key = IODAPrefix
set address = "resources.${observations__resource}.${AppCategory}"
set $key = "`$getObservationsOrNone ${address}`"

cd ${WorkDir}
set obsFile = ${IODADirectory}/${IODAPrefix}_obs_$thisMPASFileDate.nc
set sacaObsFile = ${IODAPrefix}_obs_${thisValidDate}.nc
ln -sfv ${obsFile} ${InDBDir}/${sacaObsFile}

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

## AppCategory
sed -i 's@{{AppCategory}}@'${AppCategory}'@g' $thisYAML

## namelist
sed -i 's@{{SACANamelistFile}}@'${WorkDir}'/'${NamelistFile}'@' $thisYAML

## streams
sed -i 's@{{SACAStreamsFile}}@'${WorkDir}'/'${StreamsFile}'@' $thisYAML

## current date
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML

# state variables
set Variables = ($SACAStateVariables)
set VarSub = ""
foreach var ($Variables)
  set VarSub = "$VarSub$var,"
end
# remove trailing comma
set VarSub = `echo "$VarSub" | sed 's/.$//'`
sed -i 's@{{SACAStateVariables}}@'$VarSub'@' $thisYAML

# saca bg file
sed -i 's@{{bgStateDir}}@'${WorkDir}'/'${bg}'@g' $thisYAML
sed -i 's@{{bgStatePrefix}}@'${bgPrefix}'@g' $thisYAML
sed -i 's@{{thisMPASFileDate}}@'${thisMPASFileDate}'@g' $thisYAML

# added variables
set addedVars = `cat stream_list.atmosphere.${AppCategory}_obs`
set addedVarSub = ""
foreach var ($addedVars)
  set addedVarSub = "$addedVarSub$var,"
end
# remove trailing comma
set addedVarSub = `echo "$addedVarSub" | sed 's/.$//'`
sed -i 's@{{addedVars}}@'${addedVarSub}'@g' $thisYAML

# saca an file
sed -i 's@{{anStateDir}}@'${WorkDir}'/'${an}'@g' $thisYAML
sed -i 's@{{anStatePrefix}}@'${ICFilePrefix}'@g' $thisYAML

# saca obs
sed -i 's@{{InDBDir}}@'${WorkDir}'/'${InDBDir}'@g' $thisYAML
sed -i 's@{{SACAObs}}@'${${sacaObsFile}}'@g' $thisYAML

cp $thisYAML $appyaml


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

date

exit 0
