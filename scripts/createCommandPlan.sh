#!/bin/bash 

# call should be: createCommandPlan.sh ${configFile} ${pipelineIdx} ${pipelineStep} ${pipelineID}

configFile=$1
pipelineIdx=$2
pipelineStep=$3
pipelineID=$4

echo "[INFO] createCommandPlan.sh: config: ${configFile} phase: ${pipelineIdx} step: ${pipelineStep} ID: ${pipelineID}"
echo "[INFO] createCommandPlan.sh: cwd ${cwd}" 

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] createCommandPlan.sh: Cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}

local cmd=""

if [[ ${pipelineIdx} -eq 0 ]]
then	 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarInitPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"	
elif [[ ${pipelineIdx} -eq 1 ]]
then	 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarMitoPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"   
elif [[ ${pipelineIdx} -eq 2 ]]
then
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarCoveragePipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 3 ]]
then
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarRawMaskPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 4 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarReadPatchingPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 5 ]]    
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarFixMaskPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 6 ]]    
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarScrubbingPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"    
elif [[ ${pipelineIdx} -eq 7 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarFilteringPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 8 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarTouringPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 9 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarCorrectionPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 10 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarContigAnalyzePipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 11 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPacBioPolishingPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 12 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPurgeDupsPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 13 ]]
then 
	cmd="${SUBMIT_SCRIPTS_PATH}/DAmarIlluminaPolishingPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"    
elif [[ ${pipelineIdx} -eq 14 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarPhasingPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 15 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmar10XScaffPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 16 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarBionanoScaffPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
elif [[ ${pipelineIdx} -eq 17 ]]
then 
    cmd="${SUBMIT_SCRIPTS_PATH}/DAmarHicScaffPipeline.sh ${configFile} ${pipelineIdx} ${pipelineStep}"
else
    (>&2 echo "[ERROR] createCommandPlan.sh: unknown DAmar pipeline: ${pipelineIdx}")
    exit 1
fi 

echo "[INFO] createCommandPlan.sh: cmd ${cmd}"
eval ${cmd}
if [ $? -ne 0 ]
then 
    (>&2 echo "${SUBMIT_SCRIPTS_PATH}/createHiCPlans.sh failed some how. Stop here.")
    exit 1      
fi          
