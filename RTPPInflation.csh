#!/bin/csh

date

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

if (${nEnsDAMembers} < 2) then
  exit 0
endif

# static work directory
set self_WorkDir = $CyclingRTPPInflationDir
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# other static variables
#set bgPrefix = $FCFilePrefix
#set bgDirs = ($prevCyclingFCDirs)
set bgPrefix = $BGFilePrefix
set bgDirs = ($CyclingDAInDirs)
set anPrefix = $ANFilePrefix
set anDirs = ($CyclingDAOutDirs)

## create RTPP mean output file to be overwritten
set memDir = `${memberDir} ens 0 "${flowMemFmt}"`
set meanDir = ${CyclingDAOutDir}${memDir}
mkdir -p ${meanDir}
cp $anDirs[1]/${anPrefix}.$fileDate.nc ${meanDir}


# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
ln -sf $GraphInfoDir/x1.${MPASnCells}.graph.info* .

## link lookup tables
foreach fileGlob ($FCLookupFileGlobs)
  ln -sf ${FCLookupDir}/*${fileGlob} .
end

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.surface \
stream_list.${MPASCore}.diagnostics \
stream_list.${MPASCore}.output \
)
  ln -sf $rtppModelConfigDir/$staticfile .
end
set STREAMS = streams.${MPASCore}
rm ${STREAMS}
cp -v $rtppModelConfigDir/${STREAMS} .
sed -i 's@nCells@'${MPASnCells}'@' ${STREAMS}

## link namelist.atmosphere already modifed for this cycle
ln -sf $CyclingDADirs[1]/namelist.atmosphere ./

# =============
# Generate yaml
# =============
## Copy applicationBase yaml
set thisYAML = orig.yaml
cp -v ${CONFIGDIR}/applicationBase/rtpp.yaml $thisYAML

## RTPP inflation factor
sed -i 's@RTPPInflationFactor@'${RTPPInflationFactor}'@g' $thisYAML

## revise current date
#sed -i 's@2018-04-15_00.00.00@'${fileDate}'@g' $thisYAML
#sed -i 's@2018041500@'${thisValidDate}'@g' $thisYAML
sed -i 's@2018-04-15T00:00:00Z@'${ConfDate}'@g' $thisYAML

# use one of the analyses as the localTemplateFieldsFile
set meshFile = $anDirs[1]/${anPrefix}.$fileDate.nc
ln -sf $meshFile ${localTemplateFieldsFile}

## copy static fields:
set staticMemDir = `${memberDir} ens 1 "${staticMemFmt}"`
set memberStaticFieldsFile = ${staticFieldsDir}${staticMemDir}/${staticFieldsFile}
rm ${localStaticFieldsFile}
ln -sf ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

## file naming
sed -i 's@OOPSMemberDir@/mem%{member}%@g' $thisYAML
sed -i 's@anStatePrefix@'${anPrefix}'@g' $thisYAML
sed -i 's@anStateDir@'${CyclingDAOutDir}'@g' $thisYAML
set prevYAML = $thisYAML

## state and analysis variable configs
# Note: includes model forecast variables that need to be
# averaged and/or remain constant through RTPP
set AnalysisVariables = ( \
  $StandardAnalysisVariables \
  pressure_p \
  pressure \
  rho \
  theta \
  u \
  index_qv \
)
foreach hydro ($MPASHydroVariables)
  set AnalysisVariables = ($AnalysisVariables index_$hydro)
end
set StateVariables = ( \
  $AnalysisVariables \
)
foreach VarGroup (Analysis State)
  if (${VarGroup} == Analysis) then
    set Variables = ($AnalysisVariables)
  endif
  if (${VarGroup} == State) then
    set Variables = ($StateVariables)
  endif
  set VarSub = ""
  foreach var ($Variables)
    set VarSub = "$VarSub$var,"
  end
  # remove trailing comma
  set VarSub = `echo "$VarSub" | sed 's/.$//'`
  sed -i 's@'$VarGroup'Variables@'$VarSub'@' $prevYAML
end

## fill in ensemble B config and link/copy analysis ensemble members
set indent = "  "
foreach PMatrix (Pb Pa)
  if ($PMatrix == Pb) then
    set ensPDirs = ($bgDirs)
    set ensPFilePrefix = ${bgPrefix}
    set ensPFileSuffix = ${OrigFileSuffix}
  endif
  if ($PMatrix == Pa) then
    set ensPDirs = ($anDirs)
    set ensPFilePrefix = ${anPrefix}
    set ensPFileSuffix = ""
  endif

  set enspsed = Ensemble${PMatrix}Members
cat >! ${enspsed}SEDF.yaml << EOF
/${enspsed}/c\
EOF

  set member = 1
  while ( $member <= ${nEnsDAMembers} )
    set filename = $ensPDirs[$member]/${ensPFilePrefix}.${fileDate}.nc${ensPFileSuffix}
    ## copy original analysis files for diagnosing RTPP behavior (not necessary)
    if ($PMatrix == Pa) then
      set memDir = "."`${memberDir} ens $member "${flowMemFmt}"`
      set anmemberDir = ${anDir}0/${memDir}
      rm -r ${anmemberDir}
      mkdir -p ${anmemberDir}
      cp ${filename} ${anmemberDir}/
    endif
    if ( $member < ${nEnsDAMembers} ) then
      set filename = ${filename}\\
    endif
cat >>! ${enspsed}SEDF.yaml << EOF
${indent}- <<: *state\
${indent}  filename: ${filename}
EOF

    @ member++
  end
  set thisYAML = orig${PMatrix}.yaml
  sed -f ${enspsed}SEDF.yaml $prevYAML >! $thisYAML
  rm ${enspsed}SEDF.yaml
  set prevYAML = $thisYAML
end
mv $prevYAML $appyaml

# ===================
# ===================
# Run the executable:
# ===================
# ===================
ln -sf ${RTPPBuildDir}/${RTPPEXE} ./
mpiexec ./${RTPPEXE} $appyaml >& jedi.log

#
# Check status:
# =============================================
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  touch ./FAIL
  echo "ERROR in $0 : jedi application failed" >> ./FAIL
  exit 1
endif

## change static fields to a link:
rm ${localStaticFieldsFile}
rm ${localStaticFieldsFile}${OrigFileSuffix}
ln -sf ${memberStaticFieldsFile} ${localStaticFieldsFile}

date

exit 0
