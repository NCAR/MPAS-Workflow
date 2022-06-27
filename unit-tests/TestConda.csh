#!/bin/csh -f

# Tests the functionality of some python tools used in the workflow under a conda-based python
# environment

if (0) then
  which python
  python --version

  echo "PATH=$PATH"

  which conda

  ## python environment
  source /etc/profile.d/modules.csh
  echo "source complete"

  module load ncarenv
  echo "module load ncarenv complete"

  module load conda/latest

  echo "module load conda/latest complete"

  which conda

  conda activate npl
  echo "status=$status"
  echo "conda activate complete"

  echo "PATH=$PATH"

endif
which python
python --version
pip list

python /glade/scratch/${USER}/pandac/TryConda/MPAS-Workflow/tools/memberDir.py 25 5

set s = $status
echo status=$s
#if (s != 0) then
#  exit $s
#endif

python /glade/scratch/${USER}/pandac/TryConda/MPAS-Workflow/tools/advanceCYMDH.py 2018041420 8

set s = $status
echo status=$s
#if (s != 0) then
#  exit $s
#endif

python /glade/scratch/${USER}/pandac/TryConda/MPAS-Workflow/tools/getYAMLNode.py /glade/scratch/${USER}/pandac/TryConda/MPAS-Workflow/scenarios/base/model.yaml /glade/scratch/${USER}/pandac/TryConda/MPAS-Workflow/scenarios/3dvar_OIE120km_WarmStart.yaml model.outerMesh -o key

set s = $status
echo status=$s
#if (s != 0) then
#  exit $s
#endif

#source config/model.csh

#echo "outerMesh = $outerMesh"
#echo "innerMesh = $innerMesh"

exit 0
