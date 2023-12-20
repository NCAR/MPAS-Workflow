#!/bin/csh -f
set analysisDir = /glade/campaign/mmm/parc/liuz/pandac_common/obs/2ndDoaDob
set obsspace = gnssrobndropp1d
set diagnostic = rltv_doadob
set coord = impact_height
set errortype = RelativeObsError
./relativeObsErrors.csh "$analysisDir" "$obsspace" "$diagnostic" "$coord" "$errortype"

set analysisDir = /glade/campaign/mmm/parc/liuz/pandac_common/obs/Ref_1stDoaDob
set obsspace = gnssrorefncep
set diagnostic = rltv_doadob
set coord = alt
set errortype = RelativeObsError
./relativeObsErrors.csh "$analysisDir" "$obsspace" "$diagnostic" "$coord" "$errortype"
