#!/bin/bash 
# call ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${realPathConfigFile} ${pipelineIdx} ${pipelineStep} ${pipelineRunID} [resumeIdx]

## TODO: sanity checks of RUN_DAMAR pipeline: for now assume that createAndSubmitSlurmJobs is only called from itself and from run_DAmar.sh where all checks were done 

echo "[DEBUG] createAndSubmitSlurmJobs.sh: call arguments $@"

configFile=$1
retrySubmit=${Slurm_NumSubmitRetry}

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/slurm.cfg ${configFile}

pipelineIdx=$2   ## pipeline index in RUN_DAMAR array
pipelineName=${RUN_DAMAR[${pipelineIdx}]}
echo "[DEBUG] createAndSubmitSlurmJobs.sh: pipelineName: \"${pipelineName}\""
pipelineType=${RUN_DAMAR[$((pipelineIdx+1))]}
echo "[DEBUG] createAndSubmitSlurmJobs.sh: pipelineType: \"${pipelineType}\""
pipelineTypeID=$(pipelineNameToID ${pipelineName})		### pipeline identifier: e.g. 01 - init, 02 - mito etc
echo "[DEBUG] createAndSubmitSlurmJobs.sh: pipelineTypeID: \"${pipelineTypeID}\""
pipelineStepIdx=$(prependZero $3)
TMP="${pipelineName^^}_TYPE"
echo -n "[DEBUG] createAndSubmitSlurmJobs.sh: getStepName ${pipelineName} ${!TMP} ${pipelineStepIdx}"
pipelineStepName=$(getStepName ${pipelineName} ${!TMP} ${pipelineStepIdx})
echo -e " -> ${pipelineStepName}"
pipelineRunID=$4

if [[ -n $5 ]]
then 
	resumeIdx=$5
else
	resumeIdx=0
fi

## create (if neccessary) and enter pipeline directory
DAmarRootDir=$(pwd)
ensureAndEnterPipelineDir ${pipelineIdx}

echo "[INFO] createAndSubmitSlurmJobs.sh: assembly config file - ${configFile}"
echo "[INFO] createAndSubmitSlurmJobs.sh: pipeline - name ${pipelineName} pipelineTypeID ${pipelineTypeID} pipelineType ${pipelineType} step ${pipelineStepIdx} ID ${pipelineRunID}"
echo "[INFO] createAndSubmitSlurmJobs.sh: working dir - $(pwd)"

if [[ ${resumeIdx} -eq 0 ]]
then
	### create current plan 
	echo "[DEBUG] call ${SUBMIT_SCRIPTS_PATH}/createCommandPlan.sh ${configFile} ${pipelineTypeID} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"
	${SUBMIT_SCRIPTS_PATH}/createCommandPlan.sh ${configFile} ${pipelineTypeID} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}
	if [ $? -ne 0 ]
	then 
    	(>&2 echo "[ERROR] createAndSubmitSlumJobs.sh: createCommandPlan.sh failed some how. Stop here.")
    	exit 1      
	fi 
fi

if ! ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan 1> /dev/null 2>&1;
then
    (>&2 echo "[ERROR] createAndSubmitSlumJobs.sh: missing file ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan")
    exit 1
fi

if ! ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara 1> /dev/null 2>&1;
then
    (>&2 echo "[ERROR] createAndSubmitSlumJobs.sh: missing file ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara")
    exit 1
fi

### get slurm running mode: parallel or sequential
sType=$(getSlurmParaMode ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara)
if [[ ${sType} != "sequential" && ${sType} != "parallel" ]]
then
    (>&2 echo "[ERROR] createAndSubmitSlumJobs: unknown slurm type ${sType}. valid types: sequential, parallel")
    exit 1
fi

### create slurm submit scripts

if [[ ${resumeIdx} -eq 0 ]]
then
	### setup runtime conditions, time, memory, etc 
	MEM=$(getSlurmParaMem ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara)
	TIME=$(getSlurmParaTime ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara)
	CORES=$(getSlurmParaCores ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara)
	NTASKS_PER_NODE=$(getSlurmParaTasks ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara)
	STEPSIZE=$(getSlurmParaStep ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara)
	PARTITION=$(getSlurmParaPartition ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara)
	MEM_PER_CORE=$((${MEM}/${CORES}))
	JOBS=$(wc -l ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan | awk '{print $1}')
	log_folder=log_${pipelineName}_${pipelineStepName}
	mkdir -p ${log_folder}
	first=1
	if [[ ${JOBS} -gt ${Slurm_MaxArrayCount} && ${sType} == "parallel" ]]
	then
	    from=1
	    to=${Slurm_MaxArrayCount}
	    d=1
	    while [[ $from -lt ${JOBS} ]]
	    do
	        file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.${d}
	        sed -n ${from},${to}p ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan > ${file}.plan
	        jobs=$((${to}-${from}+1))
	        ### create slurm submit file
	        echo "#!/bin/bash
#SBATCH -J ${PROJECT_ID}_p${pipelineName}s${pipelineStepIdx}
#SBATCH -p ${PARTITION}
#SBATCH -a 1-${jobs}${STEPSIZE}
#SBATCH -c ${CORES} # Number of cores 
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${pipelineName}_${pipelineRunID}_${pipelineStepIdx}_${d}_%A_%a.out # Standard output 
#SBATCH -e ${log_folder}/${pipelineName}_${pipelineRunID}_${pipelineStepIdx}_${d}_%A_%a.err # Standard error
#SBATCH --time=${TIME}
#SBATCH --mem-per-cpu=${MEM_PER_CORE}
#SBATCH --mail-user=pippel@mpi-cbg.de
#SBATCH --mail-type=FAIL" > ${file}.slurm
            if [[ -n ${NTASKS_PER_NODE} ]]
            then
                echo "#SBATCH --ntasks-per-node=${NTASKS_PER_NODE}" >> ${file}.slurm
            fi 
        	if [[ -n ${SLURM_NUMACTL} && ${SLURM_NUMACTL} -gt 0  ]]
			then	
				echo -e "#SBATCH --mem_bind=verbose,local" >> ${file}.slurm			
			fi
            if [[ -n ${SLURM_ACCOUNT} ]]
            then
                echo "#SBATCH -A ${SLURM_ACCOUNT}" >> ${file}.slurm
            fi
			
            echo "
export PATH=${MARVEL_PATH}/scripts:\$PATH
export PYTHONPATH=${MARVEL_PATH}/lib.python:\$PYTHONPATH

FIRSTJOB=0
LASTJOB=\$(wc -l ${file}.plan | awk '{print \$1}')

beg=\$(date +%s)
echo \"${file}.plan beg $beg\"

i=0;
while [[ \$i -lt \$SLURM_ARRAY_TASK_STEP ]]
do
  index=\$((\$SLURM_ARRAY_TASK_ID+\$i+\${FIRSTJOB}))
  echo \"i \$i index: \$index\"
  if [[ \$index -le \$LASTJOB ]]
  then
    echo \"eval line \$index\"
    eval \$(sed -n \${index}p ${file}.plan) || exit 100
  fi
  i=\$((\$i+1))
done

end=\$(date +%s)
echo \"${file}.plan end \$end\"
echo \"${file}.plan run time: \$((\${end}-\${beg}))\"" >> ${file}.slurm
	        d=$(($d+1))
	        from=$((${to}+1))
	        to=$((${to}+${Slurm_MaxArrayCount}))
	        if [[ $to -gt ${JOBS} ]]
	        then
	            to=${JOBS}
	        fi
	        sleep 5
	    done
	else ## less then ${Slurm_MaxArrayCount} jobs 
	    jobs=${JOBS}
	    file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}
	    ### create slurm submit file
	    if [[ ${sType} == "parallel" ]]
	    then 
	        echo "#!/bin/bash
#SBATCH -J ${PROJECT_ID}_p${pipelineName}s${pipelineStepIdx}
#SBATCH -p ${PARTITION}
#SBATCH -a 1-${jobs}${STEPSIZE}
#SBATCH -c ${CORES} # Number of cores 
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${pipelineName}_${pipelineRunID}_${pipelineStepIdx}_%A_%a.out # Standard output
#SBATCH -e ${log_folder}/${pipelineName}_${pipelineRunID}_${pipelineStepIdx}_%A_%a.err # Standard error
#SBATCH --time=${TIME}
#SBATCH --mem-per-cpu=${MEM_PER_CORE}
#SBATCH --mail-user=pippel@mpi-cbg.de
#SBATCH --mail-type=FAIL" > ${file}.slurm
	        if [[ -n ${NTASKS_PER_NODE} ]]
	        then
	            echo "#SBATCH --ntasks-per-node=${NTASKS_PER_NODE}" >> ${file}.slurm
	        fi 
	        if [[ -n ${SLURM_NUMACTL} && ${SLURM_NUMACTL} -gt 0  ]]
			then	
				echo -e "#SBATCH --mem_bind=verbose,local" >> ${file}.slurm			
			fi
            if [[ -n ${SLURM_ACCOUNT} ]]
            then
                echo "#SBATCH -A ${SLURM_ACCOUNT}" >> ${file}.slurm
            fi	        
	        	
	        echo "
export PATH=${MARVEL_PATH}/scripts:\$PATH
export PYTHONPATH=${MARVEL_PATH}/lib.python:\$PYTHONPATH

FIRSTJOB=0
LASTJOB=\$(wc -l ${file}.plan | awk '{print \$1}')

beg=\$(date +%s)
echo \"${file}.plan beg $beg\"

i=0;
while [ \$i -lt \$SLURM_ARRAY_TASK_STEP ]
do
  index=\$((\$SLURM_ARRAY_TASK_ID+\$i+\${FIRSTJOB}))
  echo \"i \$i index: \$index\"
  if [[ \$index -le \$LASTJOB ]]
  then
    echo \"eval line \$index\"
    eval \$(sed -n \${index}p ${file}.plan) || exit 100
  fi
  i=\$((\$i+1))
done

end=\$(date +%s)
echo \"${file}.plan end \$end\"
echo \"${file}.plan run time: \$((\${end}-\${beg}))\"" >> ${file}.slurm
	    else
	        echo "#!/bin/bash
#SBATCH -J ${PROJECT_ID}_p${pipelineName}s${pipelineStepIdx}
#SBATCH -p ${PARTITION}
#SBATCH -c ${CORES} # Number of cores
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${pipelineName}_${pipelineRunID}_${pipelineStepIdx}_%A.out # Standard output
#SBATCH -e ${log_folder}/${pipelineName}_${pipelineRunID}_${pipelineStepIdx}_%A.err # Standard error
#SBATCH --time=${TIME}
#SBATCH --mem-per-cpu=${MEM_PER_CORE}
#SBATCH --mail-user=pippel@mpi-cbg.de
#SBATCH --mail-type=FAIL" > ${file}.slurm

			if [[ -n ${SLURM_NUMACTL} && ${SLURM_NUMACTL} -gt 0  ]]
			then	
				echo -e "#SBATCH --mem_bind=verbose,local" >> ${file}.slurm			
			fi
            if [[ -n ${SLURM_ACCOUNT} ]]
            then
                echo "#SBATCH -A ${SLURM_ACCOUNT}" >> ${file}.slurm
            fi

			echo "
export PATH=${MARVEL_PATH}/scripts:\$PATH
export PYTHONPATH=${MARVEL_PATH}/lib.python:\$PYTHONPATH

FIRSTJOB=1
LASTJOB=\$(wc -l ${file}.plan | awk '{print \$1}')

beg=\$(date +%s)
echo \"${file}.plan beg \$beg\"

i=\${FIRSTJOB};
while [[ \$i -le \${LASTJOB} ]]
do
  echo \"eval line \$i\"
  eval \$(sed -n \${i}p ${file}.plan) || exit 100
  i=\$((\$i+1))
done

end=\$(date +%s)
echo \"${file}.plan end \$end\"
echo \"${file}.plan run time: \$((\${end}-\${beg}))\"" >> ${file}.slurm
	    fi
	fi
fi

if [[ ${resumeIdx} -eq 0 ]]
then
	if [[ ${JOBS} -gt ${Slurm_MaxArrayCount} && ${sType} == "block" ]]
	then
		resumeIdx=1
		file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.${resumeIdx}
	else
		file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}
	fi		
else
	file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.${resumeIdx}
fi

retry=0
TMPRET=-1
wait=120
while [[ "${TMPRET}" == "-1" && ${retry} -lt ${retrySubmit} ]]
do
	if [[ ${retry} -gt 0 ]]
	then
		echo "[INFO] createAndSubmitSlurmJobs: try to restart job ${file}.slurm ${retry}/${retrySubmit} - wait $((${retry}*${wait})) seconds"
		sleep $((${retry}*${wait}))
	fi
	echo "[INFO] createAndSubmitSlurmJobs: run: sbatch ${file}.slurm"
	TMPRET=$(sbatch ${file}.slurm) 
	echo "[INFO] createAndSubmitSlurmJobs: ${TMPRET}"
	if ! $(isNumber ${TMPRET##* })
	then
		echo "[WARNING] createAndSubmitSlurmJobs: job submission failed" 
		TMPRET=-1
	fi	
	retry=$((${retry}+1))
done

if [[ "${TMPRET}" == "-1" ]]
then
	(>&2 echo "[ERROR] createAndSubmitSlurmJobs - Unable to submit job ${file}.slurm. Stop here.")
	(>&2 echo "[DEBUG] createAndSubmitSlurmJobs - DAmarRootDir: ${DAmarRootDir}")
	(>&2 echo "[DEBUG] createAndSubmitSlurmJobs - cwd: $(pwd)")
	exit 1
fi
echo "[INFO] createAndSubmitSlurmJobs submit ${file}.slurm ${TMPRET##* }"
RET="${TMPRET##* }"

foundNext=0 
### add if account is necessary
appAccount=""
if [[ -n ${SLURM_ACCOUNT} ]]
then
	appAccount=" -A ${SLURM_ACCOUNT}"
fi

if [[ ${resumeIdx} -gt 0 ]]
then 
	if [[ -f ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.$((${resumeIdx}+1)).slurm ]]
	then 
		sbatch${appAccount} -J ${PROJECT_ID}_${pipelineName}_${pipelineStepName}_${pipelineRunID} -o ${pipelineName}_${pipelineStepName}_${pipelineRunID}.out -e ${pipelineName}_${pipelineStepName}_${pipelineRunID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=1g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${configFile} ${pipelineIdx} ${pipelineStepIdx} ${pipelineRunID} $((${resumeIdx}+1))"
		foundNext=1
	fi	
fi

cd ${DAmarRootDir}

### todo: verify next pipeline getters 

# get next pipeline step, or get next pipeline, or nothing else to do !!!!  
nextPipelineStep=$(getNextPipelineStep ${pipelineIdx} ${pipelineStepIdx})
if $(isNumber nextPipelineStep)
then
	sbatch${appAccount} -J ${PROJECT_ID}_${pipelineName}_${nextPipelineStep}_${pipelineRunID} -o ${pipelineName}_${nextPipelineStep}_${pipelineRunID}.out -e ${pipelineName}_${nextPipelineStep}_${pipelineRunID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=1g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${configFile} ${pipelineIdx} ${nextPipelineStep} ${pipelineRunID}"
	foundNext=1
else
	nextPipelineLineIdx=$(getNextPipelineIndex ${pipelineIdx} ${pipelineRunID})
	nextPipelineName=${RUN_DAMAR[${nextPipelineLineIdx}]}
	nextPipelineStep=${RUN_DAMAR[$((nextPipelineLineIdx+2))]}
	if $(isNumber nextPipelineLineIdx)
	then
		sbatch${appAccount} -J ${PROJECT_ID}_${nextPipelineName}_${nextPipelineStep}_${pipelineRunID} -o ${nextPipelineName}_${nextPipelineStep}_${pipelineRunID}.out -e ${nextPipelineName}_${nextPipelineStep}_${pipelineRunID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=1g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${configFile} ${nextPipelineLineIdx} ${nextPipelineStep} ${pipelineRunID}"
		foundNext=1
	fi
fi 

if [[ ${foundNext} -eq 0 ]]
then
	# submit a dummy job that waits until the last real jobs sucessfully finished
	sbatch${appAccount} --job-name=${PROJECT_ID}_final -o ${pipelineName}_final_step.${pipelineRunID}.out -e ${pipelineName}_final_step.${pipelineRunID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=00:15:00 --mem=1g --dependency=afterok:${RET##* } --wrap="sleep 5 && echo \"finished - all selected jobs created and submitted. Last Step: ${pipelineName} ${pipelineIdx} ${pipelineStepIdx} $pipelineRunID ${configFile}\""     
fi