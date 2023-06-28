#!/bin/bash -f

# Use deactivate to remove NPL from environment if it is activated
type conda >& /dev/null
if [ $? -eq 0 ]; then
  conda deactivate
fi

source /etc/profile.d/modules.sh
module purge
module load ncarenv/1.3
module load gnu/10.1.0
module load ncarcompilers/0.5.0
module load netcdf/4.8.1
module load conda/latest
conda activate npl
export PYTHONDONTWRITEBYTECODE=1 # avoid __pycache__ creation

# "conda init" modifies ~/.bashrc in order to enable conda in batch jobs.  If conda is loaded in
# a bash script that is part of a batch job, the following line is needed.

#conda init bash

# Also the "-f" flag must not be present in the bash script that loads conda and activates npl,
# because that flag prevents sourcing ~/.bashrc.

module load cylc
module load graphviz
module load git
git lfs install
module list
