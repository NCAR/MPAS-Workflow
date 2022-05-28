source /etc/profile.d/modules.csh
module load conda/latest
conda activate npl
conda init tcsh
# note: the above line will cause your "~/.cshrc" file to become null by replacing its usage with
# "~/.tcshrc".  After all settings residing in "~/.cshrc" are migrated to "~/.tcshrc", you should
# have your expected environment
module load cylc
module load git
git lfs install
module list
