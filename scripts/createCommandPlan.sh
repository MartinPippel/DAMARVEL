#!/bin/bash 

# call should be: createCommandPlan.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdxIdx} ${pipelineRunID}

echo "[DEBUG] createCommandPlan.sh - called with following args: $#"
configFile=$1
pipelineTypeID=$2
pipelineStepIdx=$3
pipelineRunID=$4

echo "[INFO] createCommandPlan.sh: config: ${configFile} phase: ${pipelineTypeID} step: ${pipelineStepIdx} ID: ${pipelineRunID}"
echo "[INFO] createCommandPlan.sh: cwd ${cwd}" 

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] createCommandPlan.sh: Cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}

cmd=""

if [[ ${pipelineTypeID} -eq 0 ]]
then	 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarInitPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"	
elif [[ ${pipelineTypeID} -eq 1 ]]
then	 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarMitoPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"   
elif [[ ${pipelineTypeID} -eq 2 ]]
then
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarCoveragePipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 3 ]]
then
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarRawMaskPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 4 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarReadPatchingPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 5 ]]    
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarFixMaskPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 6 ]]    
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarScrubbingPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"    
elif [[ ${pipelineTypeID} -eq 7 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarFilteringPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 8 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarTouringPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 9 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarCorrectionPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 10 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarContigAnalyzePipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 11 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPacBioPolishingPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 12 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPurgeDupsPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 13 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarIlluminaPolishingPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"    
elif [[ ${pipelineTypeID} -eq 14 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPhasingPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 15 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmar10XScaffPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 16 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarBionanoScaffPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 17 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarHicScaffPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"
else
    (>&2 echo "[ERROR] createCommandPlan.sh: unknown DAmar pipeline: ${pipelineTypeID}")
    exit 1
fi 

echo "[INFO] createCommandPlan.sh: cmd ${cmd}"
eval ${cmd}
if [ $? -ne 0 ]
then 
    (>&2 echo "${SUBMIT_SCRIPTS_PATH}/createHiCPlans.sh failed some how. Stop here.")
    exit 1      
fi          
