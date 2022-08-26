#!/bin/csh -f

# Process arguments
# =================
## args
# ArgMesh: str, mesh name, one of allMeshesJinja
set ArgMesh = "$1"

# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/model.csh
source config/experiment.csh
source config/builds.csh
source config/environmentJEDI.csh
source config/applications/initic.csh
source config/externalanalyses.csh
source config/tools.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

# static work directory

if ("$ArgMesh" == "$outerMesh") then
  set WorkDir = ${ExternalAnalysisDirOuter}
  set nCells = $nCellsOuter
  set filePrefix = $externalanalyses__filePrefixOuter

else if ("$ArgMesh" == "$innerMesh") then
  set WorkDir = ${ExternalAnalysisDirInner}
  set nCells = $nCellsInner
  set filePrefix = $externalanalyses__filePrefixInner

else if ("$ArgMesh" == "$ensembleMesh") then
  set WorkDir = ${ExternalAnalysisDirEnsemble}
  set nCells = $nCellsEnsemble
  set filePrefix = $externalanalyses__filePrefixEnsemble

else
  echo "$0 (ERROR): invalid ArgMesh ($ArgMesh)"
  exit 1
endif

echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}



# ================================================================================================

# only need to continue if output file does not already exist
set outputFile = $filePrefix.$thisMPASFileDate.nc

if ( -e $outputFile ) then
  echo "$0 (INFO): outputFile ($outputFile) already exists, exiting with success"
  echo "$0 (INFO): if regenerating the outputFile is desired, delete the original"

  date

  exit 0
endif

# ================================================================================================

## link ungribbed files
ln -sfv ${ExternalAnalysisDir}/${externalanalyses__UngribPrefix}* ./

## link MPAS mesh graph info and static field
rm ./x1.${nCells}.graph.info*
ln -sfv $GraphInfoDir/x1.${nCells}.graph.info* .
ln -sfv $GraphInfoDir/x1.${nCells}.static.nc .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## copy/modify dynamic streams file
rm ${StreamsFileInit}
cp -v $ModelConfigDir/$AppName/${StreamsFileInit} .
sed -i 's@{{nCells}}@'${nCells}'@' ${StreamsFileInit}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFileInit}

## copy/modify dynamic namelist
rm ${NamelistFileInit}
cp -v $ModelConfigDir/$AppName/${NamelistFileInit} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFileInit
sed -i 's@nCells@'${nCells}'@' $NamelistFileInit
sed -i 's@{{UngribPrefix}}@'${externalanalyses__UngribPrefix}'@' $NamelistFileInit

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
