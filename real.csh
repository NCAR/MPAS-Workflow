#!/bin/csh

# Set the start time variable
# setenv STARTIME `date -u +%Y%m%d%H%M%S`
# setenv STARTIME `date -u +%Y%m%d%H%M`
setenv STARTIME `date -u +%Y%m%d%H`
#setenv STARTIME 2024103009
# setenv STARTIME `cat date.dat`
echo "Original Start Time: $STARTIME"

# Extract components from STARTIME
setenv YYYY `echo $STARTIME | cut -c1-4`
setenv MM `echo $STARTIME | cut -c5-6`
setenv DD `echo $STARTIME | cut -c7-8`
setenv HH `echo $STARTIME | cut -c9-10`

# Adjust the start time by subtracting 3 hours
setenv STARTIME `date -d "${YYYY}-${MM}-${DD} ${HH} -3 hours" +"%Y%m%d%H"`
setenv YYYY `echo $STARTIME | cut -c1-4`
setenv MM `echo $STARTIME | cut -c5-6`
setenv DD `echo $STARTIME | cut -c7-8`
setenv HH `echo $STARTIME | cut -c9-10`
echo "Start Time: $STARTIME"

# Set the cycle window
set CYCLE_WINDOW = 6

# Calculate cycle and hour
@ CYCLE = $HH / $CYCLE_WINDOW
@ HR = $CYCLE * $CYCLE_WINDOW
echo "HR: $HR"
#set HH = $HR

if ($HR < 10) then
    set HH = "0$HR"
else
    set HH = $HR
endif
echo "HH: $HH"
# Calculate cycle number
@ CYCLE_NUMBER = $CYCLE + 1

# Set cycle time
set CYCLE_TIME = "${YYYY}${MM}${DD}T${HH}"
set DATE_TIME = "${YYYY}${MM}${DD}${HH}"

# Subtract cycle window hours to get STARTIME0
setenv STARTIME0 `date -d "${YYYY}-${MM}-${DD} ${HH} -${CYCLE_WINDOW} hours" +"%Y%m%d%H"`
setenv YYYY0 `echo $STARTIME0 | cut -c1-4`
setenv MM0 `echo $STARTIME0 | cut -c5-6`
setenv DD0 `echo $STARTIME0 | cut -c7-8`
setenv HH0 `echo $STARTIME0 | cut -c9-10`
set CYCLE_TIME0 = "${YYYY0}${MM0}${DD0}T${HH0}"
set DATE_TIME0 = "${YYYY0}${MM0}${DD0}${HH0}"

echo "$STARTIME, $CYCLE_TIME, $CYCLE_TIME0, $CYCLE_NUMBER"

#link gefs data
cd /glade/derecho/scratch/zhuming/pandac/gefs30km_ensFc
ln -sf /glade/campaign/mmm/parc/zhuming/GenerateGEFS/ExternalAnalyses/30kmGEFS/${DATE_TIME} ./${DATE_TIME0}
#

cd /glade/work/zhuming/pandac/MPAS-Workflow_3.0.2/

# Source environment setup script
source env-setup/machine.csh

# Clean up and generate the new YAML file
#rm -f ./GenerateObs_${CYCLE_TIME}.yaml
#cat > script.sed << EOF
#    /  first cycle point:/c\  first cycle point: ${CYCLE_TIME0}
#    /  final cycle point:/c\  final cycle point: ${CYCLE_TIME}
#EOF
#sed -f script.sed ./test/GenerateObs.yaml > ./test/GenerateObs_${CYCLE_TIME}.yaml

# Run the Python script
#./Run.py test/GenerateObs_${CYCLE_TIME}.yaml

# Clean up and generate the new YAML file of 3dvar_OIE30km_Realtime
cat > script.sed << EOF
    /  restart cycle point:/c\  restart cycle point: ${CYCLE_TIME}
    /  final cycle point:/c\  final cycle point: ${CYCLE_TIME}
EOF

rm -f ./test/tmp/Realtime_${CYCLE_TIME}.yaml
#sed -f script.sed ./test/3dvar_OIE30km_Realtime.yaml > ./test/tmp/Realtime_${CYCLE_TIME}.yaml
#sed -f script.sed ./test/3dvar_OIE30km-allsky_Realtime.yaml > ./test/tmp/Realtime_${CYCLE_TIME}.yaml
sed -f script.sed ./test/3denvar_OIE30km_Realtime.yaml > ./test/tmp/Realtime_${CYCLE_TIME}.yaml

# Run the Python script
./Run.py test/tmp/Realtime_${CYCLE_TIME}.yaml

#rm -f ./test/3dvar_OIE30km_Realtime2_${CYCLE_TIME}.yaml
#sed -f script.sed ./test/3dvar_OIE30km_Realtime2.yaml > ./test/3dvar_OIE30km_Realtime2_${CYCLE_TIME}.yaml
#./Run.py test/3dvar_OIE30km_Realtime2_${CYCLE_TIME}.yaml
