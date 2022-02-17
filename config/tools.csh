#!/bin/csh -f

## workflow tools
set pyDir = tools
set pyTools = ( \
  advanceCYMDH \
  getYAMLKey \
  memberDir \
  nSpaces \
  substituteEnsembleB \
  updateXTIME \
)
foreach tool ($pyTools)
  setenv ${tool} "python ${pyDir}/${tool}.py"
end

setenv getConfig "config/getConfig.csh"
setenv setConfig "config/setConfig.csh"

#config()
#{
#  set configSection = $1
#  echo $configSection
#  set yamlName = $2
#  echo $yamlName
#  set key = $3
#  echo $key
#  set value = "${getConfig} config/${configSection}/${yamlName}.yaml ${configSection}.${key}"
#  echo $value
#}
