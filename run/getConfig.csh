#!/bin/csh -f

set wd = `pwd`
source run/tools.csh $wd

# get arguments
set thisYAML = $1
set configSection = $2
set key = $3

# retrieve config value
set value = `${getYAMLKey} ${thisYAML} ${configSection}.${key}`

# return config value
echo $value
