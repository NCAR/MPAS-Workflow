source /etc/profile.d/modules.csh
module load conda/latest
conda activate npl

# Currently "conda init" is only needed for the bash environment in order to use conda in batch
# jobs.  If conda is loaded in a csh/tcsh script that is part of a batch job, the following line
# is also needed.  Also the "-f" flag must not be present in the csh/tcsh script that loads conda
# and activates npl.

#conda init tcsh

# note: the above line will cause your "~/.cshrc" file to become null by replacing its usage with
# "~/.tcshrc".  After all settings residing in "~/.cshrc" are migrated to "~/.tcshrc", you should
# have your expected environment

module load cylc
module load git
git lfs install
module list
