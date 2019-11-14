#!/bin/bash 

# call should be: createCommandPlan.sh ${configFile} ${pipelineTypeID} ${pipelineType} ${pipelineStepIdxIdx} ${pipelineRunID}

echo "[DEBUG] createCommandPlan.sh - called with following $# args: $@"
configFile=$1
pipelineTypeID=$2
pipelineType=$3
pipelineStepIdx=$4
pipelineRunID=$5

echo "[INFO] createCommandPlan.sh: config: ${configFile} pipelineType: ${pipelineType} pipelineTypeID: ${pipelineTypeID} step: ${pipelineStepIdx} ID: ${pipelineRunID}"
echo "[INFO] createCommandPlan.sh: cwd $(pwd)" 

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] createCommandPlan.sh: Cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}

cmd=""

if [[ ${pipelineTypeID} -eq 0 ]]
then	 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarInitPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"	
elif [[ ${pipelineTypeID} -eq 1 ]]
then	 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarMitoPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"   
elif [[ ${pipelineTypeID} -eq 2 ]]
then
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarCoveragePipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 3 ]]
then
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarRawMaskPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 4 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarReadPatchingPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 5 ]]    
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarFixMaskPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 6 ]]    
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarScrubbingPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"    
elif [[ ${pipelineTypeID} -eq 7 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarFilteringPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 8 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarTouringPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 9 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarCorrectionPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 10 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarContigAnalyzePipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 11 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPacBioPolishingPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 12 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPurgeDupsPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 13 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarIlluminaPolishingPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"    
elif [[ ${pipelineTypeID} -eq 14 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPhasingPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 15 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmar10XScaffPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 16 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarBionanoScaffPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
elif [[ ${pipelineTypeID} -eq 17 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarHicScaffPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
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
