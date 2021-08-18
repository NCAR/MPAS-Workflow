#!/bin/csh -f

date

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
set self_ModelConfigDir = $rtppModelConfigDir

# Remove old logs
rm jedi.log*

# ================================================================================================

## copy static fields
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileEnsemble}
rm ${localStaticFieldsFile}
set StaticMemDir = `${memberDir} ensemble 1 "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirEnsemble}${StaticMemDir}/${StaticFieldsFileEnsemble}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

## create RTPP mean output file to be overwritten by MPAS-JEDI RTPPEXE application
set memDir = `${memberDir} ensemble 0 "${flowMemFmt}"`
set meanDir = ${CyclingDAOutDir}${memDir}
mkdir -p ${meanDir}
cp $anDirs[1]/${anPrefix}.$fileDate.nc ${meanDir}

# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
ln -sfv $GraphInfoDir/x1.${MPASnCellsEnsemble}.graph.info* .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.diagnostics \
stream_list.${MPASCore}.output \
)
  ln -sfv $self_ModelConfigDir/$staticfile .
end

rm ${StreamsFile}
cp -v $self_ModelConfigDir/${StreamsFile} .
sed -i 's@nCells@'${MPASnCellsEnsemble}'@' ${StreamsFile}
sed -i 's@TemplateFieldsPrefix@'${TemplateFieldsPrefix}'@' ${StreamsFile}
sed -i 's@StaticFieldsPrefix@'${localStaticFieldsPrefix}'@' ${StreamsFile}

## copy/modify dynamic namelist
rm $NamelistFile
cp -v ${self_ModelConfigDir}/${NamelistFile} .
sed -i 's@startTime@'${NMLDate}'@' $NamelistFile
sed -i 's@nCells@'${MPASnCellsEnsemble}'@' $NamelistFile
sed -i 's@modelDT@'${MPASTimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' $NamelistFile

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv ${ModelConfigDir}/${file} .
end

# =============
# Generate yaml
# =============
## Copy applicationBase yaml
set thisYAML = orig.yaml
cp -v ${ConfigDir}/applicationBase/rtpp.yaml $thisYAML

## RTPP inflation factor
sed -i 's@RTPPInflationFactor@'${RTPPInflationFactor}'@g' $thisYAML

## streams
sed -i 's@EnsembleStreamsFile@'${StreamsFile}'@' $thisYAML

## namelist
sed -i 's@EnsembleNamelistFile@'${NamelistFile}'@' $thisYAML

## revise current date
#sed -i 's@2018-04-15_00.00.00@'${fileDate}'@g' $thisYAML
#sed -i 's@2018041500@'${thisValidDate}'@g' $thisYAML
sed -i 's@2018-04-15T00:00:00Z@'${ConfDate}'@g' $thisYAML

# use one of the analyses as the TemplateFieldsFileOuter
set meshFile = $anDirs[1]/${anPrefix}.$fileDate.nc
ln -sfv $meshFile ${TemplateFieldsFileOuter}

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
  qv \
)
foreach hydro ($MPASHydroVariables)
  set AnalysisVariables = ($AnalysisVariables $hydro)
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
set indent = "`${nSpaces} 2`"
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
      set memDir = "."`${memberDir} ensemble $member "${flowMemFmt}"`
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


# Run the executable
# ==================
ln -sfv ${RTPPBuildDir}/${RTPPEXE} ./
mpiexec ./${RTPPEXE} $appyaml >& jedi.log


# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  touch ./FAIL
  echo "ERROR in $0 : jedi application failed" >> ./FAIL
  exit 1
endif

## change static fields to a link, keeping for transparency
rm ${localStaticFieldsFile}
rm ${localStaticFieldsFile}${OrigFileSuffix}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}

date

exit 0
