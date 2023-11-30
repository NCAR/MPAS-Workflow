#!/bin/bash -f

# Use deactivate to remove NPL from environment if it is activated
type conda >& /dev/null
if [ $? -eq 0 ]; then
  conda deactivate
fi

if [[ "$NCAR_HOST" == "derecho" ]]; then
  if [[ "$CYLC_ENV" == "" ]]; then
    echo "set CYLC_ENV environment variable to the name of the cylc8 conda package"
    return
  fi

  source /etc/profile.d/z00_modules.sh
  module purge
  module load intel-oneapi/2023.0.0
  module load cray-mpich/8.1.25
  module load parallel-netcdf/1.12.3
  module load parallelio/2.5.10
  module load ncl/6.6.2
  module load hdf5/1.12.2
  module load netcdf/4.9.2
  module load ncarcompilers/1.0.0
  module load nco/5.1.4
  module load conda/latest

  conda activate $CYLC_ENV

elif [[ "$NCAR_HOST" == "cheyenne" ]]; then
  source /etc/profile.d/modules.sh
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
fi

export PYTHONDONTWRITEBYTECODE=1 # avoid __pycache__ creation

# "conda init" modifies ~/.tcshrc in order to enable conda in batch jobs.  If conda is loaded in
# a csh/tcsh script that is part of a batch job, the following line is needed.

#conda init tcsh

# Also the "-f" flag must not be present in the csh/tcsh script that loads conda and activates npl,
# because that flag prevents sourcing ~/.tcshrc. Following this procedure will cause "~/.cshrc" to
# become null by replacing its usage with "~/.tcshrc".  After all settings residing in "~/.cshrc"
# are migrated to "~/.tcshrc", users should have their expected environment restored.

