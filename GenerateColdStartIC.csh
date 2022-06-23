#!/bin/csh -f

date

# Setup environment
# =================
source config/model.csh
source config/experiment.csh
source config/modeldata.csh
source config/builds.csh
source config/environmentJEDI.csh
source config/applications/initic.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set WorkDir = ${InitICWorkDir}/${thisValidDate}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

## link MPAS mesh graph info and static field
rm ./x1.${nCellsOuter}.graph.info*
ln -sfv $GraphInfoDir/x1.${nCellsOuter}.graph.info* .
ln -sfv $GraphInfoDir/x1.${nCellsOuter}.static.nc .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## copy/modify dynamic streams file
rm ${StreamsFileInit}
cp -v $ModelConfigDir/$AppName/${StreamsFileInit} .
sed -i 's@nCells@'${nCellsOuter}'@' ${StreamsFileInit}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFileInit}

## copy/modify dynamic namelist
rm ${NamelistFileInit}
cp -v $ModelConfigDir/$AppName/${NamelistFileInit} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFileInit
sed -i 's@nCells@'${nCellsOuter}'@' $NamelistFileInit

# Run the executable
# ==================
rm ./${InitEXE}
ln -sfv ${InitBuildDir}/${InitEXE} ./
mpiexec ./${InitEXE}

# Check status
# ============
grep "Finished running the init_${MPASCore} core" log.init_${MPASCore}.0000.out
if ( $status != 0 ) then
  echo "ERROR in $0 : MPAS-init failed" > ./FAIL
  exit 1
endif

date

exit 0
