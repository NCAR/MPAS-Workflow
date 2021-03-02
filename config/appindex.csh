#!/bin/csh -f

## application indices
#  enables re-use of common components for similar applications

set applicationIndex = ( variational hofx )
set applicationObsIndent = ( 2 0 )

set index = 0
foreach application (${applicationIndex})
  @ index++
  if ( $application == variational ) then
    set variationalIndex = $index
  endif
  if ( $application == hofx ) then
    set hofxIndex = $index
  endif
end

## ABI super-obbing footprint, set independently
#  for variational and hofx using applicationIndex
#OPTIONS: 15X15, 59X59
set ABISuperOb = (59X59 59X59)

## AHI super-obbing footprint set independently
#  for variational and hofx using applicationIndex
#OPTIONS: 15X15, 101X101
set AHISuperOb = (101X101 101X101)
