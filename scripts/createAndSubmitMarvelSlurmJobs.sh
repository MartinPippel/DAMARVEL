#!/bin/bash 

configFile=$1
currentPhase=$2
currentStep=$3
id=$4
if [[ -n $5 ]]
then 
	resumeIdx=$5
else
	resumeIdx=0
fi

retrySubmit=3

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/slurm.cfg ${configFile}

echo "createAndSubmitMarvelSlurmJobs.sh cfg: ${configFile} cPhase: ${currentPhase} cStep: ${currentStep} ID: ${id}"
echo "createAndSubmitMarvelSlurmJobs.sh cwd: ${myCWD}"


if [[ ${resumeIdx} -eq 0 ]]
then
	### create current plan 
	${SUBMIT_SCRIPTS_PATH}/createCommandPlan.sh ${configFile} ${currentPhase} ${currentStep} ${id}
	if [ $? -ne 0 ]
	then 
    	(>&2 echo "[ERROR] createAndSubmitMarvelSlumJobs.sh: createCommandPlan.sh failed some how. Stop here.")
    	exit 1      
	fi 
fi
 
prefix=$(getPhaseFilePrefix)
sID=$(prependZero ${currentStep})
TMP="${prefix^^}_TYPE"
sName=$(getStepName ${prefix} ${!TMP} $((${currentStep}-1)))

if ! ls ${prefix}_${sID}_${sName}.${id}.plan 1> /dev/null 2>&1;
then
    (>&2 echo "[ERROR] createAndSubmitMarvelSlumJobs.sh: missing file ${prefix}_${sID}_${sName}.${id}.plan")
    exit 1
fi

if ! ls ${prefix}_${sID}_${sName}.${id}.slurmPara 1> /dev/null 2>&1;
then
    (>&2 echo "[ERROR] createAndSubmitMarvelSlumJobs.sh: missing file ${prefix}_${sID}_${sName}.${id}.slurmPara")
    exit 1
fi

### get job name 

sType=$(getSlurmParaMode ${prefix}_${sID}_${sName}.${id}.slurmPara)
if [[ ${sType} != "sequential" && ${sType} != "parallel" ]]
then
    (>&2 echo "[ERROR] createAndSubmitMarvelSlumJobs: unknown slurm type ${sType}. valid types: sequential, parallel")
    exit 1
fi

### create submit scripts

if [[ ${resumeIdx} -eq 0 ]]
then
	### setup runtime conditions, time, memory, etc 
	MEM=$(getSlurmParaMode ${prefix}_${sID}_${sName}.${id}.slurmPara)
	TIME=$(getSlurmParaTime ${prefix}_${sID}_${sName}.${id}.slurmPara)
	CORES=$(getSlurmParaCores ${prefix}_${sID}_${sName}.${id}.slurmPara)
	NTASKS_PER_NODE=$(getSlurmParaTasks ${prefix}_${sID}_${sName}.${id}.slurmPara)
	STEPSIZE=$(getSlurmParaStep ${prefix}_${sID}_${sName}.${id}.slurmPara)
	PARITION=$(getSlurmParaPartition ${prefix}_${sID}_${sName}.${id}.slurmPara)
	
	JOBS=$(wc -l ${prefix}_${sID}_${sName}_${sType}.${id}.plan | awk '{print $1}')
	log_folder=log_${prefix}_${sName}
	mkdir -p ${log_folder}
	first=1
	if [[ ${JOBS} -gt 9999 && ${sType} == "parallel" ]]
	then
	    from=1
	    to=9999
	    d=1
	    while [[ $from -lt ${JOBS} ]]
	    do
	        file=${prefix}_${sID}_${sName}.${id}.${d}
	        sed -n ${from},${to}p ${prefix}_${sID}_${sName}.${id}.plan > ${file}.plan
	        jobs=$((${to}-${from}+1))
	        ### create slurm submit file
	        echo "#!/bin/bash
#SBATCH -J ${PROJECT_ID}_p${currentPhase}s${currentStep}
#SBATCH -p ${PARTITION}
#SBATCH -a 1-${jobs}${STEPSIZE}
#SBATCH -c ${CORES} # Number of cores 
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${prefix}_${sID}_${d}_%A_%a.out # Standard output 
#SBATCH -e ${log_folder}/${prefix}_${sID}_${d}_%A_%a.err # Standard error
#SBATCH --time=${TIME}
#SBATCH --mem-per-cpu=$((${MEM}/${CORES}))
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
			
            echo "export PATH=${MARVEL_PATH}/bin:\$PATH
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
	        to=$((${to}+9999))
	        if [[ $to -gt ${JOBS} ]]
	        then
	            to=${JOBS}
	        fi
	        sleep 5
	    done
	else ## less then 9999 jobs 
	    jobs=${JOBS}
	    file=${prefix}_${sID}_${sName}.${id}
	    ### create slurm submit file
	    if [[ ${sType} == "parallel" ]]
	    then 
	        echo "#!/bin/bash
#SBATCH -J ${PROJECT_ID}_p${currentPhase}s${currentStep}
#SBATCH -p ${PARTITION}
#SBATCH -a 1-${jobs}${STEPSIZE}
#SBATCH -c ${CORES} # Number of cores 
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${prefix}_${sID}_%A_%a.out # Standard output
#SBATCH -e ${log_folder}/${prefix}_${sID}_%A_%a.err # Standard error
#SBATCH --time=${TIME}
#SBATCH --mem-per-cpu=$((${MEM}/${CORES}))
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
	        	
	        echo "export PATH=${MARVEL_PATH}/bin:\$PATH
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
#SBATCH -J ${PROJECT_ID}_p${currentPhase}s${currentStep}
#SBATCH -p ${PARTITION}
#SBATCH -c ${CORES} # Number of cores
#SBATCH -n 1 # number of nodes
#SBATCH -o ${log_folder}/${prefix}_${sID}_%A.out # Standard output
#SBATCH -e ${log_folder}/${prefix}_${sID}_%A.err # Standard error
#SBATCH --time=${TIME}
#SBATCH --mem-per-cpu=$((${MEM}/${CORES}))
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

			echo "export PATH=${MARVEL_PATH}/bin:\$PATH
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
	if [[ ${JOBS} -gt 9999 && ${sType} == "block" ]]
	then
		resumeIdx=1
		file=${prefix}_${sID}_${sName}.${id}.${resumeIdx}
	else
		file=${prefix}_${sID}_${sName}.${id}
	fi		
else
	file=${prefix}_${sID}_${sName}.${id}.${resumeIdx}
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
	if [[ -f ${prefix}_${sID}_${sName}_${sType}.${id}.$((${resumeIdx}+1)).slurm ]]
	then 
		sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s${currentStep+1} -o ${prefix}_step${currentStep}_${id}.out -e ${prefix}_step${currentStep}_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} ${currentStep} $id $((${resumeIdx}+1))"
		foundNext=1
	fi	
fi

if [[ ${currentPhase} -eq -2 ]]
then
	if [[ $((${currentStep}+1)) -le ${INIT_SUBMIT_TO} ]]
    then
    	sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
	else
		### we have to create the coverage directory and change into that dir 
		if [[ $(echo "$(pwd)" | awk -F \/ '{print $NF}') -eq ${MASH_DIR} ]]
		then
			if [[ ${RAW_MITO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_MITO_SUBMIT_SCRIPTS_FROM} -le ${RAW_MITO_SUBMIT_SCRIPTS_TO} ]]
			then
				cd ../
				mkdir -p ${MITO_DIR}
				cd ${MITO_DIR}
				currentPhase=-1
				prefix=$(getPhaseFilePrefix)
				currentStep=$((${RAW_MITO_SUBMIT_SCRIPTS_FROM}-1))
			elif [[ ${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM} -le ${RAW_DASCOVER_SUBMIT_SCRIPTS_TO} ]]
			then
				cd ../
				mkdir -p ${DASCOVER_DIR}
				cd ${DASCOVER_DIR}
				currentPhase=0
				prefix=$(getPhaseFilePrefix)
				currentStep=$((${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM}-1))				
			elif [[ ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${RAW_REPMASK_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${RAW_PATCH_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_PATCH_SUBMIT_SCRIPTS_FROM} -le ${RAW_PATCH_SUBMIT_SCRIPTS_TO} ]]
			then
				cd ../
				mkdir -p ${PATCHING_DIR}
				cd ${PATCHING_DIR}
				
				if [[ ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${RAW_REPMASK_SUBMIT_SCRIPTS_TO} ]]
				then
					currentPhase=1
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${RAW_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        		else
        			currentPhase=2
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${RAW_PATCH_SUBMIT_SCRIPTS_FROM}-1))
        		fi												
			elif [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]] ||
		  	 	[[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]] ||		   		
		   		[[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]		   		
			then
				cd ../	
			
		        if [[ -z "${FIX_REPMASK_USELAFIX_PATH}" ]]
				then 
					(>&2 echo "WARNING - Variable FIX_REPMASK_USELAFIX_PATH is not set.Try to use default path: patchedReads_dalign")
					FIX_REPMASK_USELAFIX_PATH="patchedReads_dalign"
				fi
				mkdir -p ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				cd ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				
				if [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]]
				then
					currentPhase=3
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=4
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_SCRUB_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=5
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_FILT_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]]  
        		then
        			currentPhase=6
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_TOUR_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] 
        		then 
        			currentPhase=7
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_CORR_SUBMIT_SCRIPTS_FROM}-1))
        		elif ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=8
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${COR_CONTIG_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=9
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${PB_ARROW_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=10
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=11
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=12
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PHASE_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=13
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_10X_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=14
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_BIONANO_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=15
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_HIC_SUBMIT_SCRIPTS_FROM}-1))			
        		else
        			currentPhase=100 ## nothing to do, set phase to invalid value
				fi				
			fi 
		fi
	fi
fi

if [[ ${currentPhase} -eq -1 ]]
then
	if [[ $((${currentStep}+1)) -le ${RAW_MITO_SUBMIT_SCRIPTS_TO} ]]
    then
    	sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
	else
		### we have to create the coverage directory and change into that dir 
		if [[ $(echo "$(pwd)" | awk -F \/ '{print $NF}') -eq ${MITO_DIR} ]]
		then
			if [[ ${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM} -le ${RAW_DASCOVER_SUBMIT_SCRIPTS_TO} ]]
			then
				cd ../
				mkdir -p ${DASCOVER_DIR}
				cd ${DASCOVER_DIR}
				currentPhase=0
				prefix=$(getPhaseFilePrefix)
				currentStep=$((${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM}-1))				
			elif [[ ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${RAW_REPMASK_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${RAW_PATCH_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_PATCH_SUBMIT_SCRIPTS_FROM} -le ${RAW_PATCH_SUBMIT_SCRIPTS_TO} ]]
			then
				cd ../
				mkdir -p ${PATCHING_DIR}
				cd ${PATCHING_DIR}
				
				if [[ ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${RAW_REPMASK_SUBMIT_SCRIPTS_TO} ]]
				then
					currentPhase=1
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${RAW_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        		else
        			currentPhase=2
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${RAW_PATCH_SUBMIT_SCRIPTS_FROM}-1))
        		fi												
			elif [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]] ||
		  	 	[[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]] ||		   		
		   		[[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]		   		
			then
				cd ../	
			
		        if [[ -z "${FIX_REPMASK_USELAFIX_PATH}" ]]
				then 
					(>&2 echo "WARNING - Variable FIX_REPMASK_USELAFIX_PATH is not set.Try to use default path: patchedReads_dalign")
					FIX_REPMASK_USELAFIX_PATH="patchedReads_dalign"
				fi
				mkdir -p ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				cd ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				
				if [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]]
				then
					currentPhase=3
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=4
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_SCRUB_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=5
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_FILT_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]]  
        		then
        			currentPhase=6
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_TOUR_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] 
        		then 
        			currentPhase=7
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_CORR_SUBMIT_SCRIPTS_FROM}-1))
        		elif ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=8
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${COR_CONTIG_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=9
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${PB_ARROW_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=10
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=11
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=12
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PHASE_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=13
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_10X_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=14
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_BIONANO_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=15
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_HIC_SUBMIT_SCRIPTS_FROM}-1))			
        		else
        			currentPhase=100 ## nothing to do, set phase to invalid value
				fi				
			fi 
		fi
	fi
fi

if [[ ${currentPhase} -eq 0 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -le ${RAW_DASCOVER_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=1
        currentStep=$((${RAW_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
		### we have to create the patching directory and change into that dir 
		if [[ $(echo "$(pwd)" | awk -F \/ '{print $NF}') -eq ${MITO_DIR} ]] || [[ $(echo "$(pwd)" | awk -F \/ '{print $NF}') -eq ${COVERAGE_DIR} ]]
		then
			if [[ ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${RAW_REPMASK_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${RAW_PATCH_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_PATCH_SUBMIT_SCRIPTS_FROM} -le ${RAW_PATCH_SUBMIT_SCRIPTS_TO} ]]
			then
				cd ../
				mkdir -p ${PATCHING_DIR}
				cd ${PATCHING_DIR}
				
				if [[ ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${RAW_REPMASK_SUBMIT_SCRIPTS_TO} ]]
				then
					currentPhase=1
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${RAW_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        		else
        			currentPhase=2
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${RAW_PATCH_SUBMIT_SCRIPTS_FROM}-1))
        		fi												
			elif [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]] ||
		  	 	[[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]] ||		   		
		   		[[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]		   		
			then
				cd ../	
			
		        if [[ -z "${FIX_REPMASK_USELAFIX_PATH}" ]]
				then 
					(>&2 echo "WARNING - Variable FIX_REPMASK_USELAFIX_PATH is not set.Try to use default path: patchedReads_dalign")
					FIX_REPMASK_USELAFIX_PATH="patchedReads_dalign"
				fi
				mkdir -p ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				cd ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				
				if [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]]
				then
					currentPhase=3
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=4
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_SCRUB_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=5
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_FILT_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]]  
        		then
        			currentPhase=6
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_TOUR_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] 
        		then 
        			currentPhase=7
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_CORR_SUBMIT_SCRIPTS_FROM}-1))
        		elif ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=8
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${COR_CONTIG_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=9
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${PB_ARROW_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=10
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=11
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=12
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PHASE_SUBMIT_SCRIPTS_FROM}-1))
				elif [[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=13
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_10X_SUBMIT_SCRIPTS_FROM}-1))  
        		elif [[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=14
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_BIONANO_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=15
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_HIC_SUBMIT_SCRIPTS_FROM}-1))        				      			
        		else
        			currentPhase=100 ## nothing to do, set phase to invalid value
				fi				
			fi
		fi
    fi
fi

if [[ ${currentPhase} -eq 1  && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${RAW_REPMASK_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=2
        currentStep=$((${RAW_PATCH_SUBMIT_SCRIPTS_FROM}-1))
    fi
fi  

if [[ ${currentPhase} -eq 2 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${RAW_PATCH_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=3
        currentStep=$((${FIX_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        ### we have to create the assembly directory and change into that dir 
		if [[ $(echo "$(pwd)" | awk -F \/ '{print $NF}') -eq ${MITO_DIR} ]] || [[ $(echo "$(pwd)" | awk -F \/ '{print $NF}') -eq ${COVERAGE_DIR} ]] || [[ $(echo "$(pwd)" | awk -F \/ '{print $NF}') -eq ${PATCHING_DIR} ]]
		then
			if [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]] ||
		  	 	[[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]] ||		   		
		   		[[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]] ||
		   		[[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]		   		
			then
				cd ../	
			
		        if [[ -z "${FIX_REPMASK_USELAFIX_PATH}" ]]
				then 
					(>&2 echo "WARNING - Variable FIX_REPMASK_USELAFIX_PATH is not set.Try to use default path: patchedReads_dalign")
					FIX_REPMASK_USELAFIX_PATH="patchedReads_dalign"
				fi
				mkdir -p ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				cd ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
				
				if [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]]
				then
					currentPhase=3
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_REPMASK_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=4
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_SCRUB_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=5
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_FILT_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]]  
        		then
        			currentPhase=6
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_TOUR_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 && ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]] 
        		then 
        			currentPhase=7
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${FIX_CORR_SUBMIT_SCRIPTS_FROM}-1))
        		elif ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 && ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=8
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${COR_CONTIG_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 && ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=9
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${PB_ARROW_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=10
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]]
        		then 
        			currentPhase=11
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 && ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=12
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${CT_PHASE_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_10X_SUBMIT_SCRIPTS_FROM} -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=13
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_10X_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=14
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_BIONANO_SUBMIT_SCRIPTS_FROM}-1))
        		elif [[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 && ${SC_HIC_SUBMIT_SCRIPTS_FROM} -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]
        		then
        			currentPhase=15
					prefix=$(getPhaseFilePrefix)
					currentStep=$((${SC_HIC_SUBMIT_SCRIPTS_FROM}-1))		
        		else
        			currentPhase=100 ## nothing to do, set phase to invalid value
				fi				
			fi
		fi
    fi 
fi  

if [[ ${currentPhase} -eq 3 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${FIX_REPMASK_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=4
        currentStep=$((${FIX_SCRUB_SUBMIT_SCRIPTS_FROM}-1))
    fi
fi

if [[ ${currentPhase} -eq 4 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${FIX_SCRUB_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=5
        currentStep=$((${FIX_FILT_SUBMIT_SCRIPTS_FROM}-1))
    fi 
fi     

if [[ ${currentPhase} -eq 5 && ${foundNext} -eq 0 ]]
then 
    if [[ ${FIX_FILT_TYPE} -eq 0 && ${currentStep} -eq 2 && -n ${FIX_FILT_LAFILTER_RMSYMROUNDS} && ${FIX_FILT_LAFILTER_RMSYMROUNDS} -gt 0 && ! -f filt_02_LAfilter_block.${id}.plan ]]
    then                 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s${currentStep} -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} ${currentStep} $id"
        foundNext=1
    elif [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${FIX_FILT_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=6
        currentStep=$((${FIX_TOUR_SUBMIT_SCRIPTS_FROM}-1))
    fi 
fi

if [[ ${currentPhase} -eq 6 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${FIX_TOUR_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=7
        currentStep=$((${FIX_CORR_SUBMIT_SCRIPTS_FROM}-1))
    fi
fi 

if [[ ${currentPhase} -eq 7 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${FIX_CORR_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=8
        currentStep=$((${COR_CONTIG_SUBMIT_SCRIPTS_FROM}-1))    
    fi
fi

if [[ ${currentPhase} -eq 8 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${COR_CONTIG_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
	else 
        currentPhase=9
        currentStep=$((${PB_ARROW_SUBMIT_SCRIPTS_FROM}-1))        
    fi
fi

if [[ ${currentPhase} -eq 9 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${PB_ARROW_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
	else 
        currentPhase=10
        currentStep=$((${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM}-1))                
    fi
fi

if [[ ${currentPhase} -eq 10 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
	else 
        currentPhase=11
        currentStep=$((${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM}-1))                        
    fi
fi

if [[ ${currentPhase} -eq 11 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${CT_FREEBAYES_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
	else 
        currentPhase=12
        currentStep=$((${CT_PHASE_SUBMIT_SCRIPTS_FROM}-1))        
    fi
fi

if [[ ${currentPhase} -eq 12 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${CT_PHASE_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=13
        currentStep=$((${SC_10X_SUBMIT_SCRIPTS_FROM}-1))    
    fi
fi                        

if [[ ${currentPhase} -eq 13 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${SC_10X_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=14
        currentStep=$((${SC_BIONANO_SUBMIT_SCRIPTS_FROM}-1))    
    fi
fi

if [[ ${currentPhase} -eq 14 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${SC_BIONANO_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    else 
        currentPhase=15
        currentStep=$((${SC_HIC_SUBMIT_SCRIPTS_FROM}-1))    
    fi
fi   

if [[ ${currentPhase} -eq 15 && ${foundNext} -eq 0 ]]
then 
    if [[ $((${currentStep}+1)) -gt 0 && $((${currentStep}+1)) -le ${SC_HIC_SUBMIT_SCRIPTS_TO} ]]
    then 
        sbatch${appAccount} --job-name=${PROJECT_ID}_p${currentPhase}s$((${currentStep+1})) -o ${prefix}_step$((${currentStep}+1))_${id}.out -e ${prefix}_step$((${currentStep}+1))_${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=01:00:00 --mem-per-cpu=6g --dependency=afterok:${RET##* } --wrap="bash ${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${configFile} ${currentPhase} $((${currentStep}+1)) $id"
        foundNext=1
    fi
fi                     
                        

if [[ ${foundNext} -eq 0 ]]
then
	# submit a dummy job that waits until the last real jobs sucessfully finished
sbatch${appAccount} --job-name=${PROJECT_ID}_final -o ${prefix}_final_step.${id}.out -e ${prefix}_final_step.${id}.err -n1 -c1 -p ${SLURM_PARTITION} --time=00:15:00 --mem=1g --dependency=afterok:${RET##* } --wrap="sleep 5 && echo \"finished - all selected jobs created and submitted. Last Step: ${prefix} ${currentPhase} ${currentStep} $id ${configFile}\""     
fi