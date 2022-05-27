source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl
module load cylc
module load git
git lfs install
module list
