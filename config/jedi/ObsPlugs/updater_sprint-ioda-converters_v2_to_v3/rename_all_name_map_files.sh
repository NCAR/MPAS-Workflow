#!/bin/bash

# Run this script in the directory with yaml files that need updating
# Script kindly provided by Mike Cooke (Met Office)

export config=/glade/work/guerrett/pandac/code/mpas-bundleSources/mpas-bundle_sandbox0/ioda/share/ioda/yaml/validation/ObsSpace.yaml
export yaml_upgrader=./read_namemap_updatedefaultmapping.py

for f in $(ls *.yaml)
do
  echo $f
  python3 $yaml_upgrader $config $f
  #exit
  mv $f.new $f
done
