#!/bin/csh -f

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/mpas/variables.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh
source config/builds.csh
source config/environment.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# static variables
set self_InitICConfigDir = $initICModelConfigDir
# ================================================================================================

## link ungribbed GFS
ln -sfv ${ungribDir}/GFS:${FirstFileICDate} ./GFS:${FirstFileICDate}

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
rm ${StreamsFileIni}
cp -v $self_InitICConfigDir/${StreamsFileIni} .
sed -i 's@nCells@'${MPASnCellsOuter}'@' ${StreamsFileIni}
sed -i 's@forecastPrecision@'${forecastPrecision}'@' ${StreamsFileIni}

## copy/modify dynamic namelist
rm ${NamelistFileIniC}
cp -v ${self_InitICConfigDir}/${NamelistFileIniC} ${NamelistFileIniC}
sed -i 's@startTime@'${NMLDate}'@' $NamelistFileIniC
sed -i 's@nCells@'${MPASnCellsOuter}'@' $NamelistFileIniC

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

## change static fields to a link, keeping for transparency
#rm ${localStaticFieldsFile}
#mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}

date

exit 0
