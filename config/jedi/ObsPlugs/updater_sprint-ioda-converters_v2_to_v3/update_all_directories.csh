#!/bin/tcsh -f

set wd = `pwd`

set directories = ( \
  ${wd}/../variational/base \
  ${wd}/../variational/filters \
  ${wd}/../variational/filtersWithBias \
  ${wd}/../variational/bias \
  ${wd}/../hofx/base \
  ${wd}/../hofx/filters \
)

foreach d ($directories)
  cd $d
  pwd

  # step 1
  ln -sf ${wd}/rename_all_name_map_files.sh ./
  ln -sf ${wd}/read_namemap_updatedefaultmapping.py
  ./rename_all_name_map_files.sh
  rm rename_all_name_map_files.sh
  rm read_namemap_updatedefaultmapping.py

  # step 2
#  ln -sf ${wd}/add_obsop_map.csh
#  ./add_obsop_map.csh
#  rm add_obsop_map.csh

  cd $wd
end

