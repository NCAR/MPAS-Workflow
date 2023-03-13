#!/bin/csh -f

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
source config/auto/rtpp.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

if (${nMembers} < 2) then
  exit 0
endif

# static work directory
set self_WorkDir = "${ExperimentDirectory}/"`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${RTPPBuildDir}
set myEXE = ${RTPPEXE}
set myYAML = ${self_WorkDir}/$appyaml

# other static variables
#set bgPrefix = $FCFilePrefix
#set bgDirs = ($prevCyclingFCDirs)
set bgPrefix = $BGFilePrefix
set bgDirs = ($CyclingDAInDirs)
set anPrefix = $ANFilePrefix
set anDirs = ($CyclingDAOutDirs)

# Remove old logs
rm jedi.log*

# ================================================================================================

## copy static fields
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileEnsemble}
rm ${localStaticFieldsFile}
set StaticMemDir = `${memberDir} 2 1 "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirEnsemble}${StaticMemDir}/${StaticFieldsFileEnsemble}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

## create RTPP mean output file to be overwritten by MPAS-JEDI RTPPEXE application
set memDir = `${memberDir} 2 0 "${flowMemFmt}"`
set meanDir = ${CyclingDAOutDir}${memDir}
mkdir -p ${meanDir}
set firstANFile = $anDirs[1]/${anPrefix}.$thisMPASFileDate.nc
cp ${firstANFile} ${meanDir}

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
ncdump -h ${firstANFile} | grep uReconstruct | grep double
if ($status == 0) then
  set analysisPrecision=double
else
  ncdump -h ${firstANFile} | grep uReconstruct | grep float
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
sed -i 's@modelDT@'${TimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' $NamelistFile

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv $ModelConfigDir/$file .
end

# =============
# Generate yaml
# =============
## Copy jedi/applications yaml
set thisYAML = orig.yaml
cp -v ${ConfigDir}/jedi/applications/$appyaml $thisYAML

## RTPP inflation factor
sed -i 's@{{relaxationFactor}}@'${relaxationFactor}'@g' $thisYAML

## streams
sed -i 's@{{EnsembleStreamsFile}}@'${self_WorkDir}'/'${StreamsFile}'@' $thisYAML

## namelist
sed -i 's@{{EnsembleNamelistFile}}@'${self_WorkDir}'/'${NamelistFile}'@' $thisYAML

## revise current date
sed -i 's@{{thisISO8601Date}}@'${thisISO8601Date}'@g' $thisYAML

# use one of the analyses as the TemplateFieldsFileOuter
set meshFile = ${firstANFile}
ln -sfv $meshFile ${TemplateFieldsFileOuter}

## file naming
sed -i 's@{{MemberDir}}@/mem%{member}%@g' $thisYAML
sed -i 's@{{anStatePrefix}}@'${anPrefix}'@g' $thisYAML
sed -i 's@{{anStateDir}}@'${CyclingDAOutDir}'@g' $thisYAML
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
foreach hydro ($MPASHydroIncrementVariables)
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
  sed -i 's@{{'$VarGroup'Variables}}@'$VarSub'@' $prevYAML
end

## fill in ensemble B config and link/copy analysis ensemble members
set indent = "`${nSpaces} 2`"
foreach PMatrix (Pb Pa)
  if ($PMatrix == Pb) then
    set ensPDirs = ($bgDirs)
    set ensPFilePrefix = ${bgPrefix}
  endif
  if ($PMatrix == Pa) then
    set ensPDirs = ($anDirs)
    set ensPFilePrefix = ${anPrefix}
  endif

  set enspsed = Ensemble${PMatrix}Members
cat >! ${enspsed}SEDF.yaml << EOF
/{{${enspsed}}}/c\
EOF

  set ensPFile = ${ensPFilePrefix}.${thisMPASFileDate}.nc
  set anBeforeRTPPDir = ${analysisSubDir}BeforeRTPP
  mkdir ${anBeforeRTPPDir}
  rm ${analysisSubDir}
  ln -sf ${anBeforeRTPPDir} ${analysisSubDir}
  set member = 1
  while ( $member <= ${nMembers} )
    set ensPDir = $ensPDirs[$member]
    set ensPFileBeforeRTPP = ${ensPDir}/${ensPFile}

    ## copy original analysis files for diagnosing RTPP behavior
    if ($PMatrix == Pa) then
      set memDir = `${memberDir} 2 $member "${flowMemFmt}"`
      set tempAnalysisCopyDir = ./${analysisSubDir}${memDir}

      # Restore ${ensPFileBeforeRTPP} with original files if ${tempAnalysisCopyDir}/${ensPFile} already exists
      if ( -f "${tempAnalysisCopyDir}/${ensPFile}" ) then
        rm ${ensPFileBeforeRTPP}
        cp -v ${tempAnalysisCopyDir}/${ensPFile} ${ensPFileBeforeRTPP}
      else
        rm -r ${tempAnalysisCopyDir}
        mkdir -p ${tempAnalysisCopyDir}
        cp -v ${ensPFileBeforeRTPP} ${tempAnalysisCopyDir}/
      endif
    endif
    set filename = ${ensPFileBeforeRTPP}
    if ( $member < ${nMembers} ) then
      set filename = ${filename}\\
    endif
cat >>! ${enspsed}SEDF.yaml << EOF
${indent}- <<: *stateReadConfig\
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
