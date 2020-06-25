#!/bin/csh

setenv VERIFYJOBSCRIPT VFSCRIPT


# execute VF job script
# =================================
qsub ${VERIFYJOBSCRIPT}


exit
