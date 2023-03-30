#!/bin/csh -f
set analysisDir = /glade/scratch/guerrett/pandac/graphics_results/GNSSROSimulations27JAN2023/2ndDoaDob
set obsspace = gnssrobndropp1d
set diagnostic = rltv_doadob
set coord = impact_height
set errortype = RelativeObsError
./relativeObsErrors.csh "$analysisDir" "$obsspace" "$diagnostic" "$coord" "$errortype"

set analysisDir = /glade/scratch/guerrett/pandac/graphics_results/GNSSROSimulations27JAN2023/Ref_1stDoaDob
set obsspace = gnssrorefncep
set diagnostic = rltv_doadob
set coord = alt
set errortype = RelativeObsError
./relativeObsErrors.csh "$analysisDir" "$obsspace" "$diagnostic" "$coord" "$errortype"
