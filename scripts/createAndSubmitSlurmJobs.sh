#!/bin/bash 
# call ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${realPathConfigFile} ${pipelineIdx} ${pipelineStep} ${ID} [resumeIdx]

## TODO: sanity checks of RUN_DAMAR pipeline: for now assume that createAndSubmitSlurmJobs is only called from itself and from run_DAmar.sh where all checks were done 

configFile=$1
retrySubmit=3

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/slurm.cfg ${configFile}

pipelineIdx=$2
pipelineName=${RUN_DAMAR[${pipelineIdx}]}
pipelineType=${RUN_DAMAR[$((pipelineIdx+1))]}
pipelineIdx=$(pipelineNameToIndex ${pipelineName})
pipelineStepIdx=$(prependZero $3)
pipelineID=$4
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
echo "[INFO] createAndSubmitSlurmJobs.sh: pipeline - name ${pipelineName} pipelineIDx ${pipelineIdx} step ${pipelineStepIdx} ID ${pipelineID}"
echo "[INFO] createAndSubmitSlurmJobs.sh: working dir - ${myCWD}"

if [[ ${resumeIdx} -eq 0 ]]
then
	### create current plan 
	${SUBMIT_SCRIPTS_PATH}/createCommandPlan.sh ${configFile} ${pipelineIdx} ${pipelineStepIdx} ${pipelineID}
	if [ $? -ne 0 ]
	then 
    	(>&2 echo "[ERROR] createAndSubmitSlumJobs.sh: createCommandPlan.sh failed some how. Stop here.")
    	exit 1      
	fi 
fi

TMP="${pipelineName^^}_TYPE"
echo "[DEBUG] createAndSubmitSlurmJobs.sh: getStepName ${pipelineName} ${!TMP} $((${pipelineStepIdx}-1))"
pipelineStepName=$(getStepName ${c} ${!TMP} $((${pipelineStepIdx}-1)))

if ! ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan 1> /dev/null 2>&1;
then
    (>&2 echo "[ERROR] createAndSubmitSlumJobs.sh: missing file ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan")
    exit 1
fi

if ! ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara 1> /dev/null 2>&1;
then
    (>&2 echo "[ERROR] createAndSubmitSlumJobs.sh: missing file ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara")
    exit 1
fi

### get job name 

sType=$(getSlurmParaMode ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara)
if [[ ${sType} != "sequential" && ${sType} != "parallel" ]]
then
    (>&2 echo "[ERROR] createAndSubmitSlumJobs: unknown slurm type ${sType}. valid types: sequential, parallel")
    exit 1
fi

### create slurm submit scripts

if [[ ${resumeIdx} -eq 0 ]]
then
	### setup runtime conditions, time, memory, etc 
	MEM=$(getSlurmParaMem ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara)
	TIME=$(getSlurmParaTime ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara)
	CORES=$(getSlurmParaCores ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara)
	NTASKS_PER_NODE=$(getSlurmParaTasks ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara)
	STEPSIZE=$(getSlurmParaStep ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara)
	PARTITION=$(getSlurmParaPartition ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara)
	MEM_PER_CORE=$((${MEM}/${CORES}))
	JOBS=$(wc -l ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan | awk '{print $1}')
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
	        file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.${d}
	        sed -n ${from},${to}p ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan > ${file}.plan
	        jobs=$((${to}-${from}+1))
	        ### create slurm submit file
	        echo "#!/bin/bash
#SBATCH -J ${PROJECT_ID}_p${pipelineName}s${pipelineStepIdx}
#SBATCH -p ${PARTITION}
#SBATCH -a 1-${jobs}${STEPSIZE}
#SBATCH -c ${CORES} # Number of cores 
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${pipelineName}_${pipelineStepIdx}_${d}_%A_%a.out # Standard output 
#SBATCH -e ${log_folder}/${pipelineName}_${pipelineStepIdx}_${d}_%A_%a.err # Standard error
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
	    file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}
	    ### create slurm submit file
	    if [[ ${sType} == "parallel" ]]
	    then 
	        echo "#!/bin/bash
#SBATCH -J ${PROJECT_ID}_p${pipelineName}s${pipelineStepIdx}
#SBATCH -p ${PARTITION}
#SBATCH -a 1-${jobs}${STEPSIZE}
#SBATCH -c ${CORES} # Number of cores 
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${pipelineName}_${pipelineStepIdx}_%A_%a.out # Standard output
#SBATCH -e ${log_folder}/${pipelineName}_${pipelineStepIdx}_%A_%a.err # Standard error
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
#SBATCH -o ${log_folder}/${pipelineName}_${pipelineStepIdx}_%A.out # Standard output
#SBATCH -e ${log_folder}/${pipelineName}_${pipelineStepIdx}_%A.err # Standard error
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
		file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.${resumeIdx}
	else
		file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}
	fi		
else
	file=${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.${resumeIdx}
fi

retry=0
TMPRET=-1
wait=120
while [[ "${TMPRET}" == "-1" && ${retry} -lt ${retrySubmit} ]]
do
	if [[ ${retry} -gt 0 ]]
	then
		echo "try to restart job ${file}.slurm ${retry}/${retrySubmit} - wait $((${retry}*${wait})) seconds"
		sleep $((${retry}*${wait}))
	fi
	TMPRET=$(sbatch ${file}.slurm) && isNumber ${TMPRET##* } || TMPRET=-1            		
	retry=$((${retry}+1))
done

if [[ "${TMPRET}" == "-1" ]]
then
	(>&2 echo "Unable to submit job ${file}.slurm. Stop here.")
	exit 1
fi
echo "submit ${file}.slurm ${TMPRET##* }"
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
	if [[ -f ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.$((${resumeIdx}+1)).slurm ]]
	then 
	sbatch${appAccount} -J ${PROJECT_ID}_${pipelineName}_${pipelineStepName}_${pipelineID} -o ${pipelineName}_${pipelineStepName}_${pipelineID}.out -e ${pipelineName}_${pipelineStepName}_${pipelineID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=1g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${configFile} ${pipelineIdx} ${pipelineStepIdx} ${pipelineID} $((${resumeIdx}+1))"
		foundNext=1
	fi	
fi

cd ${DAmarRootDir}

# get next pipeline step, or get next pipeline, or nothing else to do !!!!  
nextPipelineStep=$(getNextPipelineStep ${pipelineIdx} ${pipelineStepIdx})
if $(isNumber nextPipelineStep)
then
	sbatch${appAccount} -J ${PROJECT_ID}_${pipelineName}_${nextPipelineStep}_${pipelineID} -o ${pipelineName}_${nextPipelineStep}_${pipelineID}.out -e ${pipelineName}_${nextPipelineStep}_${pipelineID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=1g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${configFile} ${pipelineIdx} ${nextPipelineStep} ${pipelineID}"
	foundNext=1
else
	nextPipelineIdx=$(getNextPipelineIndex ${pipelineIdx} ${pipelineID})
	nextPipelineName=${RUN_DAMAR[${nextPipelineIdx}]}
	nextPipelineStep=${RUN_DAMAR[$((nextPipelineIdx+2))]}
	if $(isNumber nextPipelineIdx)
	then
		sbatch${appAccount} -J ${PROJECT_ID}_${nextPipelineName}_${nextPipelineStep}_${pipelineID} -o ${nextPipelineName}_${nextPipelineStep}_${pipelineID}.out -e ${nextPipelineName}_${nextPipelineStep}_${pipelineID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=1g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitSlurmJobs.sh ${configFile} ${nextPipelineIdx} ${nextPipelineStep} ${pipelineID}"
		foundNext=1
	fi
fi 

if [[ ${foundNext} -eq 0 ]]
then
	# submit a dummy job that waits until the last real jobs sucessfully finished
	sbatch${appAccount} --job-name=${PROJECT_ID}_final -o ${pipelineName}_final_step.${pipelineID}.out -e ${pipelineName}_final_step.${pipelineID}.err -n1 -c1 -p ${SLURM_PARTITION} --time=00:15:00 --mem=1g --dependency=afterok:${RET##* } --wrap="sleep 5 && echo \"finished - all selected jobs created and submitted. Last Step: ${pipelineName} ${pipelineIdx} ${pipelineStepIdx} $pipelineID ${configFile}\""     
fi