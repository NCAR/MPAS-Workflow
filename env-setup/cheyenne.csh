source /etc/profile.d/modules.csh
module load conda/latest
conda activate npl

# "conda init" modifies ~/.tcshrc in order to enable conda in batch jobs.  If conda is loaded in
# a csh/tcsh script that is part of a batch job, the following line is needed.

#conda init tcsh

# Also the "-f" flag must not be present in the csh/tcsh script that loads conda and activates npl,
# because that flag prevents sourcing ~/.tcshrc. Following this procedure will cause "~/.cshrc" to
# become null by replacing its usage with "~/.tcshrc".  After all settings residing in "~/.cshrc"
# are migrated to "~/.tcshrc", users should have their expected environment restored.

module load cylc
module load git
git lfs install
module list
