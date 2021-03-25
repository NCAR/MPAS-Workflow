#!/bin/csh -f

source config/experiment.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh
source config/builds.csh
source config/benchmark.csh

## controls the workflow file structure of all experiments

# While any variable may be changed, doing so may prevent restart or re-verification of previously
# executed experiments

# TODO: move TMPDIR creation to individul jobs or common cylc environment setup script, similar
# to how jediPrep.csh is used
setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

##########################
## run directory structure
##########################
# TopExpDir, where all experiments are located
# TODO: move to a higher level config file so that benchmark.csh can use it too
set ExperimentUser = ${USER}
set TopExpDir = /glade/scratch/${ExperimentUser}/pandac

## absolute experiment directory
setenv PackageBaseName MPAS-Workflow
setenv ExperimentName ${ExperimentUser}
setenv ExperimentName ${ExperimentName}_${DAType}
setenv ExperimentName ${ExperimentName}${ExpObsName}
setenv ExperimentName ${ExperimentName}${EnsExpSuffix}
setenv ExperimentName ${ExperimentName}_${MPASGridDescriptor}
setenv ExperimentNameWithoutSuffix ${ExperimentName}
setenv ExperimentName ${ExperimentName}${ExpSuffix}

set ExpDir = ${TopExpDir}/${ExperimentName}

## immediate subdirectories
setenv CyclingDAWorkDir ${ExpDir}/CyclingDA
setenv CyclingFCWorkDir ${ExpDir}/CyclingFC
setenv CyclingInflationWorkDir ${ExpDir}/CyclingInflation
setenv RTPPInflationWorkDir ${CyclingInflationWorkDir}/RTPP
setenv ABEInflationWorkDir ${CyclingInflationWorkDir}/ABEI

setenv ExtendedFCWorkDir ${ExpDir}/ExtendedFC
setenv VerificationWorkDir ${ExpDir}/Verification

## benchmark experiment archive
setenv BenchmarkCyclingDAWorkDir ${BenchmarkExpDir}/CyclingDA
setenv BenchmarkVerificationWorkDir ${BenchmarkExpDir}/Verification

## directories copied from PackageBaseName
setenv mainScriptDir ${ExpDir}/${PackageBaseName}
setenv ConfigDir ${mainScriptDir}/config

## directory string formatter for EDA members
# third argument to memberDir.py
setenv flowMemFmt "/mem{:03d}"

## appyaml: universal yaml file name for all jedi applications
setenv appyaml jedi.yaml


#############################################
## model state file and directory descriptors
#############################################
setenv RSTFilePrefix restart
setenv ICFilePrefix mpasin
setenv InitFilePrefixOuter x1.${MPASnCellsOuter}.init
setenv InitFilePrefixInner x1.${MPASnCellsInner}.init
setenv InitFilePrefixEnsemble x1.${MPASnCellsEnsemble}.init

setenv FCFilePrefix mpasout
setenv fcDir fc
setenv DIAGFilePrefix diag

setenv ANFilePrefix an
setenv anDir ${ANFilePrefix}
setenv BGFilePrefix bg
setenv bgDir ${BGFilePrefix}

setenv StreamsFile streams.${MPASCore}
setenv NamelistFile namelist.${MPASCore}

setenv TemplateFieldsPrefix templateFields
setenv TemplateFieldsFileOuter ${TemplateFieldsPrefix}.${MPASnCellsOuter}.nc
setenv TemplateFieldsFileInner ${TemplateFieldsPrefix}.${MPASnCellsInner}.nc
setenv TemplateFieldsFileEnsemble ${TemplateFieldsPrefix}.${MPASnCellsEnsemble}.nc

setenv localStaticFieldsPrefix static
setenv localStaticFieldsFileOuter ${localStaticFieldsPrefix}.${MPASnCellsOuter}.nc
setenv localStaticFieldsFileInner ${localStaticFieldsPrefix}.${MPASnCellsInner}.nc
setenv localStaticFieldsFileEnsemble ${localStaticFieldsPrefix}.${MPASnCellsEnsemble}.nc

setenv OrigFileSuffix _orig


############################################
## instrument file and directory descriptors
############################################
## database file prefixes
#  for obs, geovals, and hofx-diagnostics
# Note: these are self-consistent across multiple applications
#       and can be changed to any non-empty string
setenv obsPrefix      obsout
setenv geoPrefix      geoval
setenv diagPrefix     ydiags

## InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

## VarBCAnalysis is the analysis variational bias correction coefficient file
# TODO: enable VarBC updating
# -----
setenv VarBCAnalysis ${OutDBDir}/satbias_crtm_ana

##################################
## application-specific templating
##################################
setenv ModelConfigDir ${ConfigDir}/mpas

set OuterStreamsFile = ${StreamsFile}_${MPASGridDescriptorOuter}
set OuterNamelistFile = ${NamelistFile}_${MPASGridDescriptorOuter}

set InnerStreamsFile = ${StreamsFile}_${MPASGridDescriptorInner}
set InnerNamelistFile = ${NamelistFile}_${MPASGridDescriptorInner}

#set EnsembleStreamsFile = ${StreamsFile}_${MPASGridDescriptorEnsemble}
#set EnsembleNamelistFile = ${NamelistFile}_${MPASGridDescriptorEnsemble}

# forecast
setenv forecastModelConfigDir ${ModelConfigDir}/forecast
##set forecastMeshList = (Forecast)
#set forecastMPASnCellsList = ($MPASnCellsOuter)
#set forecastlocalStaticFieldsFileList = ( \
#$localStaticFieldsFileOuter \
#)
#set forecastStreamsFileList = ($OuterStreamsFile)
#set forecastNamelistFileList = ($OuterNamelistFile)

# variational
if ($nEnsDAMembers > 1 && ${ABEInflation} == True) then
  setenv variationalModelConfigDir ${ModelConfigDir}/variational-bginflate
else
  setenv variationalModelConfigDir ${ModelConfigDir}/variational
endif
set variationalMeshList = (Outer Inner)
set variationalMPASnCellsList = ($MPASnCellsOuter $MPASnCellsInner)
set variationallocalStaticFieldsFileList = ( \
$localStaticFieldsFileOuter \
$localStaticFieldsFileInner \
)
set variationalStreamsFileList = ($OuterStreamsFile $InnerStreamsFile)
set variationalNamelistFileList = ($OuterNamelistFile $InnerNamelistFile)

# hofx
setenv hofxModelConfigDir ${ModelConfigDir}/hofx
set hofxMeshList = (HofX)
set hofxMPASnCellsList = ($MPASnCellsOuter)
#set hofxlocalStaticFieldsFileList = ( \
#$localStaticFieldsFileOuter \
#)
set hofxStreamsFileList = ($OuterStreamsFile)
set hofxNamelistFileList = ($OuterNamelistFile)

# rtpp
setenv rtppModelConfigDir ${ModelConfigDir}/rtpp
#set rtppMeshList = (Ensemble)
#set rtppMPASnCellsList = ($MPASnCellsEnsemble)
#set rtpplocalStaticFieldsFileList = ( \
#$localStaticFieldsFileEnsemble \
#)
#set rtppStreamsFileList = ($EnsembleStreamsFile)
#set rtppNamelistFileList = ($EnsembleNamelistFile)

