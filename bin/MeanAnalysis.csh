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

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/staticstream.csh
source config/auto/workflow.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

set self_WorkDir = $MeanAnalysisDirs[1]
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir} && rm *

# build, executable, yaml
set myBuildDir = ${meanStateBuildDir}
set myEXE = ${meanStateExe}
set myYAML = ${self_WorkDir}/ens_mean_variance.yaml

# other static variables
set self_StateDirs = ($CyclingDAOutDirs)
set self_StatePrefix = ${ANFilePrefix}
set memberPrefix = ${self_StatePrefix}.${thisMPASFileDate}.mem
set meanName = ${self_StatePrefix}.$thisMPASFileDate.nc
set varianceName = ${self_StatePrefix}.$thisMPASFileDate.variance.nc

# ================================================================================================
## Link background/analysis members
set member = 1
while ( $member <= ${nMembers} )
  set appMember = `${memberDir} 2 $member "{:03d}"`
  ln -sfv $self_StateDirs[$member]/${meanName} ./${memberPrefix}${appMember}
  @ member++
end

if (${nMembers} == 1) then
  ## pass-through for mean
  ln -sfv $self_StateDirs[1]/${meanName} ./
  echo "$0 (INFO): linked determinstic state for mean"
  exit 0
endif

## make copy for mean
cp $self_StateDirs[1]/${meanName} ./${meanName}

## make copy for variance
cp $self_StateDirs[1]/${meanName} ./${varianceName}

# ===================================================
## Prepare jedi-related files
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileEnsemble}
rm ${localStaticFieldsFile}
set StaticMemDir = `${memberDir} 2 1 "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirEnsemble}${StaticMemDir}/${StaticFieldsFileEnsemble}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
ln -sfv $GraphInfoDir/x1.${nCellsEnsemble}.graph.info* .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.background \
stream_list.${MPASCore}.analysis \
stream_list.${MPASCore}.ensemble \
stream_list.${MPASCore}.control \
)
  ln -sfv $ModelConfigDir/rtpp/$staticfile .
end

rm ${StreamsFile}
cp -v $ModelConfigDir/rtpp/${StreamsFile} .
sed -i 's@{{nCells}}@'${nCellsEnsemble}'@' ${StreamsFile}
sed -i 's@{{TemplateFieldsPrefix}}@'${self_WorkDir}'/'${TemplateFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{StaticFieldsPrefix}}@'${self_WorkDir}'/'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

# determine analysis output precision
ncdump -h ${meanName} | grep uReconstruct | grep double
if ($status == 0) then
  set analysisPrecision=double
else
  ncdump -h ${meanName} | grep uReconstruct | grep float
  if ($status == 0) then
    set analysisPrecision=single
  else
    echo "ERROR in $0 : cannot determine analysis precision" > ./FAIL
    exit 1
  endif
endif
sed -i 's@{{analysisPRECISION}}@'${analysisPrecision}'@' ${StreamsFile}

## copy/modify dynamic namelist
rm $NamelistFile
cp -v $ModelConfigDir/rtpp/${NamelistFile} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFile
sed -i 's@blockDecompPrefix@'${self_WorkDir}'/x1.'${nCellsEnsemble}'@' ${NamelistFile}
sed -i 's@modelDT@'${TimeStepEnsemble}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScaleEnsemble}'@' $NamelistFile

## modify namelist physics
sed -i 's@radtlwInterval@'${RadiationLWIntervalEnsemble}'@' $NamelistFile
sed -i 's@radtswInterval@'${RadiationSWIntervalEnsemble}'@' $NamelistFile
sed -i 's@physicsSuite@'${PhysicsSuiteEnsemble}'@' $NamelistFile
sed -i 's@micropScheme@'${MicrophysicsEnsemble}'@' $NamelistFile
sed -i 's@convectionScheme@'${ConvectionEnsemble}'@' $NamelistFile
sed -i 's@pblScheme@'${PBLEnsemble}'@' $NamelistFile
sed -i 's@gwdoScheme@'${GwdoEnsemble}'@' $NamelistFile
sed -i 's@radtCldScheme@'${RadiationCloudEnsemble}'@' $NamelistFile
sed -i 's@radtLWScheme@'${RadiationLWEnsemble}'@' $NamelistFile
sed -i 's@radtSWScheme@'${RadiationSWEnsemble}'@' $NamelistFile
sed -i 's@sfcLayerScheme@'${SfcLayerEnsemble}'@' $NamelistFile
sed -i 's@lsmScheme@'${LSMEnsemble}'@' $NamelistFile

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv $ModelConfigDir/$file .
end

# =============
# Generate yaml
# =============
## Copy jedi/applications yaml
set thisYAML = orig.yaml
cp -v ${ConfigDir}/jedi/applications/ens_mean_variance.yaml $thisYAML

## streams
sed -i 's@{{EnsembleStreamsFile}}@'${self_WorkDir}'/'${StreamsFile}'@' $thisYAML

## namelist
sed -i 's@{{EnsembleNamelistFile}}@'${self_WorkDir}'/'${NamelistFile}'@' $thisYAML

## revise current date
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML

# use one of the analyses as the TemplateFieldsFileOuter
set meshFile = ${meanName} 
ln -sfv $meshFile ${TemplateFieldsFileOuter}

# Set necessary variables (integer variables should not be included.)
set StateVariables = ( \
  $StandardAnalysisVariables \
  pressure_p \
  pressure \
  rho \
  theta \
  u \
  qv \
  $MPASHydroStateVariables \
)

set VarSub = ""
foreach var ($StateVariables)
  set VarSub = "$VarSub$var,"
end
# remove trailing comma
set VarSub = `echo "$VarSub" | sed 's/.$//'`
sed -i 's@{{StateVariables}}@'$VarSub'@' $thisYAML

## file naming
sed -i 's@{{EnsembleMember}}@'${memberPrefix}'@g' $thisYAML
sed -i 's@{{EnsembleNumber}}@'${nMembers}'@g' $thisYAML
sed -i 's@{{EnsembleMeanFile}}@'${meanName}'@g' $thisYAML
sed -i 's@{{EnsembleVarianceFile}}@'${varianceName}'@g' $thisYAML
set prevYAML = $thisYAML

## state and analysis variable configs
mv $prevYAML $myYAML

# Run the executable
# ==================
ln -sfv ${myBuildDir}/${myEXE} ./
mpiexec ./${myEXE} $myYAML ./jedi.log >& jedi.log.all

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
endif

## change static fields to a link, keeping for transparency
rm ${localStaticFieldsFile}
mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}

date

exit 0
