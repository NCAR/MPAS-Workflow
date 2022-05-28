source /etc/profile.d/modules.sh
module load conda/latest
conda activate npl
conda init bash
module load cylc
module load git
git lfs install
module list
