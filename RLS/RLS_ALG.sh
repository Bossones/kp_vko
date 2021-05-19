#!/bin/bash
declare -a targets
targetDirectory='/tmp/GenTargets/Targets'
targetsNames=`ls -t $targetDirectory`
echo $targetsNames
# for (( i = 0; i < 30; i++ ))
# do
# 	targets[i]=
# done