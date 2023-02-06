#!/bin/csh -f
set analysisDir = /glade/scratch/guerrett/pandac/graphics_results/GNSSROSimulations27JAN2023
set obsspace = gnssrobndropp1d
set diagnostic = rltv_doadob
set coord = impact_height
set errortype = RelativeObsError
./relativeObsErrors.csh "$analysisDir" "$obsspace" "$diagnostic" "$coord" "$errortype"

set analysisDir = /glade/scratch/guerrett/pandac/graphics_results/GNSSROSimulations30NOV2022/Ref+Bend_3
set obsspace = gnssrorefncep
set diagnostic = rltv_doadob
set coord = alt
set errortype = RelativeObsError
./relativeObsErrors.csh "$analysisDir" "$obsspace" "$diagnostic" "$coord" "$errortype"
