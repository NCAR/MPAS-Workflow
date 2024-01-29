#!/bin/tcsh -f

# Use deactivate to remove NPL from environment if it is activated
which conda >& /dev/null
if ($? == 0) then
  conda deactivate
endif

if ( "$NCAR_HOST" == "derecho" ) then
  if ( ! $?CYLC_ENV ) then
    echo 'CYLC_ENV environment variable is not set, setting it to /glade/work/jwittig/conda-envs/my-cylc8.2'
    setenv CYLC_ENV /glade/work/jwittig/conda-envs/my-cylc8.2
  endif
#  source /etc/profile.d/z00_modules.csh
#  module purge
  module load conda/latest

  conda activate $CYLC_ENV
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

setenv PYTHONDONTWRITEBYTECODE 1 # avoid __pycache__ creation

# "conda init" modifies ~/.tcshrc in order to enable conda in batch jobs.  If conda is loaded in
# a csh/tcsh script that is part of a batch job, the following line is needed.

#conda init tcsh

# Also the "-f" flag must not be present in the csh/tcsh script that loads conda and activates npl,
# because that flag prevents sourcing ~/.tcshrc. Following this procedure will cause "~/.cshrc" to
# become null by replacing its usage with "~/.tcshrc".  After all settings residing in "~/.cshrc"
# are migrated to "~/.tcshrc", users should have their expected environment restored.

