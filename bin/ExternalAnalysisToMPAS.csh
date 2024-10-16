#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: my location
set ArgWorkDir = "$2"

# ArgFilePrefix: prefix for output file
set ArgFilePrefix = "$3"

# ArgType: type of horizontal mesh 
set ArgType = "$4"

# ArgNCells: number of horizontal mesh cells
set ArgNCells = "$5"

# ArgRatio: Ratio of horizontal mesh cells
set ArgRatio = "$6"

# ArgExternalAnalysesDir: location of external analyses
set ArgExternalAnalysesDir = "$7"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/auto/model.csh
source config/auto/invariantstream.csh
source config/tools.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./bin/getCycleVars.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
set ExternalAnalysesDir = ${ExperimentDirectory}/`echo "$ArgExternalAnalysesDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

# only need to continue if output file does not already exist
set outputFile = $ArgFilePrefix.$thisMPASFileDate.nc

if ( -e $outputFile ) then
  if ( -e CONVERTSUCCESS ) then
    echo "$0 (INFO): outputFile ($outputFile) and CONVERTSUCCESS file already exist, exiting with success"
    echo "$0 (INFO): if regenerating the output outputFile is desired, delete CONVERTSUCCESS"

    date

    exit 0
  endif

#  set oSize = `du -sh $outputFile | sed 's@'$outputFile'@@'`
#  if ( "$oSize" != "0" ) then
#    echo "$0 (INFO): outputFile ($outputFile) already exists, exiting with success"
#    echo "$0 (INFO): if regenerating the outputFile is desired, delete $outputFile"
#
#    date
#
#    exit 0
#  endif

  rm $outputFile
endif

# ================================================================================================
## link ungribbed files
ln -sfv ${ExternalAnalysesDir}/${externalanalyses__UngribPrefix}* ./

## link MPAS mesh graph info
rm ./x${ArgRatio}.${ArgNCells}.graph.info*
ln -sfv $GraphInfoDir/x${ArgRatio}.${ArgNCells}.graph.info* .

## Link MPAS invariant field
if ( $ArgType == "Outer" ) then
   ln -sfv $InvariantFieldsDirOuter/$InvariantFieldsFileOuter .
else
   ln -sfv $InvariantFieldsDirInner/$InvariantFieldsFileInner .
endif

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## copy/modify dynamic streams file
rm ${StreamsFileInit}
cp -v $ModelConfigDir/initic/${StreamsFileInit} .
sed -i 's@{{nCells}}@'${ArgNCells}'@' ${StreamsFileInit}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFileInit}
sed -i 's@{{meshRatio}}@'${ArgRatio}'@' ${StreamsFileInit}

## copy/modify dynamic namelist
rm ${NamelistFileInit}
cp -v $ModelConfigDir/initic/${NamelistFileInit} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFileInit
sed -i 's@nCells@'${ArgNCells}'@' $NamelistFileInit
sed -i 's@{{meshRatio}}@'${ArgRatio}'@' $NamelistFileInit
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
  rm $outputFile
  echo "ERROR in $0 : MPAS-init failed" > ./FAIL
  exit 1
endif

date

touch CONVERTSUCCESS

exit 0
