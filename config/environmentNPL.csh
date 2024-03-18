#!/bin/csh -f

if ( $?config_environmentNPL ) exit 0
setenv config_environmentNPL 1

if ( "$NCAR_HOST" == "derecho" ) then
  source /etc/profile.d/z00_modules.csh
  module purge
  module load conda/latest
  module list
  conda activate npl
else if ( "$NCAR_HOST" == "cheyenne" ) then
  source /etc/profile.d/modules.csh
  module purge
  module load ncarenv/1.3
  module load gnu/10.1.0
  module load ncarcompilers/0.5.0
  module load netcdf/4.8.1
  module load conda/latest
  conda activate npl

  module load cylc
  module load graphviz
  module load git
  git lfs install
  module list
else
  echo "unknown NCAR_HOST " $NCAR_HOST
endif
