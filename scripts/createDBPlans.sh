#!/bin/bash 

configFile=$1
currentStep=$2
slurmID=$3
currentPhase="init"

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}



if [[ ${FIX_FILT_TYPE} -eq 0 ]]
then 
    ### create sub-directory and link relevant DB and Track files
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 

        echo "if [[ -d ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE} ]]; then mv ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}_$(date '+%Y-%m-%d_%H-%M-%S'); fi && mkdir ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE} && ln -s -r .${FIX_DB%db}.* ${FIX_DB%db}.db ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.version
	fi
fi