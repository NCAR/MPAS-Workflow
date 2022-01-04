#!/bin/csh -f

date

# Setup environment
# =================
source config/environment.csh
source config/filestructure.csh
source config/modeldata.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh
source config/builds.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
echo "WorkDir = ${InitICDir}"
mkdir -p ${InitICDir}
cd ${InitICDir}

# ================================================================================================

## link MPAS mesh graph info and static field
rm ./x1.${MPASnCellsOuter}.graph.info*
ln -sfv $GraphInfoDir/x1.${MPASnCellsOuter}.graph.info* .
ln -sfv $GraphInfoDir/x1.${MPASnCellsOuter}.static.nc .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## copy/modify dynamic streams file
rm ${StreamsFileInit}
cp -v ${initModelConfigDir}/${StreamsFileInit} .
sed -i 's@nCells@'${MPASnCellsOuter}'@' ${StreamsFileInit}
sed -i 's@forecastPrecision@'${forecastPrecision}'@' ${StreamsFileInit}

## copy/modify dynamic namelist
rm ${NamelistFileInit}
cp -v ${initModelConfigDir}/${NamelistFileInit} .
sed -i 's@startTime@'${NMLDate}'@' $NamelistFileInit
sed -i 's@nCells@'${MPASnCellsOuter}'@' $NamelistFileInit

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
