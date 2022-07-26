source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl

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
