source /etc/profile.d/modules.csh
module load conda/latest
conda activate npl
module load cylc
module load git
git lfs install
module list
