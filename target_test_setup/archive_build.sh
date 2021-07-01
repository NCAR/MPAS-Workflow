#!/bin/bash

d=`pwd`
base="mpas-bundle_gnu-openmpi"
suf=`date +%d%b%Y | tr '[a-z]' '[A-Z]'`
name=${base}_${suf}
cp -rp build $name
cd $name/MPAS/core_atmosphere
ln -sf $d/$name/_deps/mpas_data-src/atmosphere/physics_wrf/files/* ./
cd -
