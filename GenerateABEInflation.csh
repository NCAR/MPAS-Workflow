#!/bin/csh -f

date

# Setup environment
# =================
source config/experiment.csh
source config/tools.csh
source config/model.csh
source config/modeldata.csh
source config/environmentPython.csh
source config/applications/verifyobs.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingABEInflationDir
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# other static variables
set self_StatePrefix = ${FCFilePrefix}
set self_AppType = hofx

# ================================================================================================

set localStaticFieldsFile = ${localStaticFieldsFileOuter}

## copy static fields
rm static.nc

set StaticMemDir = `${memberDir} 2 1 "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
rm ${localStaticFieldsFile}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}

# gridTemplateFile must include latCell, lonCell, theta, and surface_pressure
set gridTemplateFile = ${self_WorkDir}/${localStaticFieldsFile}

# could use mean state, but not guaranteed to have all required fields
#set meanStatePrefix = ${FCFilePrefix}
#set meanName = ${meanStatePrefix}.$thisMPASFileDate.nc
#set gridTemplateFile = $MeanBackgroundDirs[1]/$meanName


# location of mean background obs-space hofx database
set dbPath = ${VerifyEnsMeanBGDirs}/${OutDBDir}

set self_ObsList = (abi_g16 ahi_himawari8)
set nInstAvailable = 0
set instrumentArg = ''
foreach inst ($self_ObsList)
  set missing = 0
  # TODO: define obsoutGlob construction in a different place
  set obsoutGlob = "${dbPath}/obsout_${self_AppType}_${inst}_*.h5"
  echo "Searching for ${obsoutGlob}"
  find ${obsoutGlob} -mindepth 0 -maxdepth 0
  if ($? > 0) then
    @ missing++
  else
    set brokenLinks=( `find ${obsoutGlob} -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
    foreach link ($brokenLinks)
      @ missing++
    end
  endif
  if ($missing == 0) then
    set instrumentArg = $instrumentArg${inst},
    echo "${inst} data was found successfully"
    @ nInstAvailable++
  else
    echo "${inst} data is selected, but missing; NOT adding ${inst} to ABE instruments"
  endif
end

if ($nInstAvailable == 0) then
  exit 0
endif


# generate ABE Inflation Factors
# ==============================
set mainScript="GenerateABEIFactors"
ln -fs ${pyVerifyDir}/*.py ./
ln -fs ${pyVerifyDir}/${mainScript}.py ./

set NUMPROC=`cat $PBS_NODEFILE | wc -l`

# plotLambda
# OPTIONS: True, False
# expensive, but informative if inflation factors are needed as diagnostic
set plotLambda = False

set success = 1
while ( $success != 0 )
  mv log.${mainScript} log.${mainScript}_LAST
  setenv baseCommand "python ${mainScript}.py ${thisValidDate} -n ${NUMPROC} -p ${dbPath} -o ${obsPrefix} -g ${geoPrefix} -d ${diagPrefix} -i ${instrumentArg} -c ${ABEIChannel} -r ${ABEILocalizationRadius} -m ${gridTemplateFile} -app hofx -plot ${plotLambda}"

  echo "${baseCommand}" | tee ./myCommand
  ${baseCommand} >& log.${mainScript}

  set success = $?

  if ( $success != 0 ) then
    source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh default
    sleep 3
  endif
end

grep "Finished __main__ successfully" log.${mainScript}
if ( $status != 0 ) then
  echo "ERROR in $0 : ${mainScript} failed" > ./FAIL
  exit 1
endif

date

exit
