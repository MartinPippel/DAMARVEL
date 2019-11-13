#!/bin/bash 

configFile=$1
ID="-1" ## by default run all IDs
if [[ "x$2" != "x" && $(isNumber $2) ]]
then
  ID=$2
fi

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] DAmar_run.sh: cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}

## do some general sanity checks
	
if [[ -z "${PROJECT_ID}" ]]
then 
    (>&2 echo "[ERROR] run_DAmar.sh: You have to specify a project id. Set variable PROJECT_ID")
    exit 1
fi

if [[ -z "${RUN_DAMAR}" ]]
then 
    (>&2 echo "[ERROR] run_DAmar.sh: You have to specify a job pipeline! Set variable RUN_DAMAR")
    exit 1
fi

## find entry point
## check if pipelines are correct 
if [[ $((${#RUN_DAMAR[@]} % 5)) -ne 0 || ${#RUN_DAMAR[@]} -eq 0 ]] 
then 
	(>&2 echo "[ERROR] run_DAmar.sh: RUN_DAMAR job pipeline is corrupt! Must hav following form: pipelineName, pipelineType, fromStep, toStep, ID.")
	(>&2 echo "                      pipelineName, pipelineType, and Steps can be found in ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg")
	(>&2 echo "                      ID can be an arbitrary number. Pipelines with the same IDs run sequentially (blocking mode), and different IDs run in parallel")
    exit 1
fi
## check individual pipeline for correctness
## TODO: check if all required programs and Variables are available and set properly
for x in $(seq 0 5 ${#RUN_DAMAR[@]})
do
	## check pipelineName
	pipelineIdx=$(pipelineNameToIndex ${RUN_DAMAR[${x}]})
	## check is pipeline type and steps are proper
	if ! $(isNumber ${RUN_DAMAR[$((x+2))]})
	then
		(>&2 echo "[ERROR] run_DAmar.sh: pipeline from_step \"${RUN_DAMAR[$((x+2))]}\" must be a positive number!!")
		exit 1
	elif ! $(isNumber ${RUN_DAMAR[$((x+3))]})
	then
		(>&2 echo "[ERROR] run_DAmar.sh: pipeline to_step \"${RUN_DAMAR[$((x+3))]}\" must be a positive number!!")
		exit 1	
	elif [[ ${RUN_DAMAR[$((x+3))]} -lt ${RUN_DAMAR[$((x+2))]} ]]
	then
		(>&2 echo "[ERROR] run_DAmar.sh: pipeline from_step \"${RUN_DAMAR[$((x+2))]}\" smaller or equal to pipelien to_step \"${RUN_DAMAR[$((x+3))]}\"!!")
		exit 1
	fi 
	getStepName ${RUN_DAMAR[${x}]} ${RUN_DAMAR[$((x+1))]} ${RUN_DAMAR[$((x+2))]}) > /dev/null ## check from 
	getStepName ${RUN_DAMAR[${x}]} ${RUN_DAMAR[$((x+1))]} ${RUN_DAMAR[$((x+3))]}) > /dev/null ## check to	
	## check ID: must be a positive number 
	if ! $(isNumber ${RUN_DAMAR[$((x+4))]}) 
	then
		(>&2 echo "[ERROR] run_DAmar.sh: pipeline ID \"${RUN_DAMAR[$((x+4))]}\" must be a positive number!! ${RUN_DAMAR[${x}]} ${RUN_DAMAR[$((x+1))]} ${RUN_DAMAR[$((x+2))]} ${RUN_DAMAR[$((x+3))]} ${RUN_DAMAR[$((x+4))]}.")
		exit 1
	fi
done

runIDs=()
local realPathConfigFile=$(realpath "${configFile}")

## run the pipeline(s)
for x in $(seq 0 5 ${#RUN_DAMAR[@]})
do
	if [[ $ID -eq -1 || ${RUN_DAMAR[$((x+4))]} -eq ${ID} ]] && [[ " ${runIDs[@]} " =~ " ${RUN_DAMAR[$((x+4))]} " ]]
	then
		
		local currentPipelineIdx=$x
		local currentPipelineStep=${RUN_DAMAR[$((x+2))]}
		
		${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${realPathConfigFile} ${currentPipelineIdx} ${currentPipelineStep} ${Id}
		runIDs+=${RUN_DAMAR[$((x+4))]}
	fi
done