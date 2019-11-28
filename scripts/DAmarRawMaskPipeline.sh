#!/bin/bash -e

#call: DAmarRawMaskPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"

echo "[INFO] DAmarRawMaskPipeline.sh - called with following $# args: $@"

if [[ $# -ne 4 ]]
then 
	(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh: invalid number of arguments: $# Expected 4! ");
   	exit 1
fi

configFile=$1
pipelineName="rmask"
pipelineType=$2
pipelineStepIdx=$3
pipelineRunID=$4

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] DAmarRawMaskPipeline: cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}
### todo: how to handle more than slurm??? 
source ${SUBMIT_SCRIPTS_PATH}/slurm.cfg ${configFile}

pipelineStepName=$(getStepName ${pipelineName} ${pipelineType} ${pipelineStepIdx})
echo -e "[DEBUG] DAmarRawMaskPipeline: getStepName \"${pipelineName}\" \"${pipelineType}\" \"${pipelineStepIdx}\" --> ${pipelineStepName}"

setDabaseName

# type_0 - stepsp[1-14}: 01_createSubdir, 02_DBdust, 03_Catrack, 04_datander, 05_TANmask, 06_Catrack, 07_daligner, 08_LAmerge, 09_LArepeat, 10_TKmerge, 11-daligner, 12-LAmerge, 13-LArepeat, 14-TKmerge
if [[ ${pipelineType} -eq 0 ]]
then
	if [[ ${pipelineStepIdx} -eq 0 ]]
    then
		### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
                        
        echo -e "if [[ -d ${REPMASK_OUTDIR} ]]; then mv ${REPMASK_OUTDIR} ${REPMASK_OUTDIR}_\$(stat --format='%Y' ${REPMASK_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	if [[ "${PACBIO_TYPE}" == "LoFi" ]]
       	then
       		echo -e "mkdir ${REPMASK_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.bps . && ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.bps ${REPMASK_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.bps . && ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.bps ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_Z}.db . && ln -s -r .${DB_Z}.idx ${DB_Z}.db ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_M}.db . && ln -s -r .${DB_M}.idx ${DB_M}.db ${REPMASK_OUTDIR}/"
       		echo -e "cd ${myCWD}"
        else
       		echo -e "mkdir ${REPMASK_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.bps . && ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.bps ${REPMASK_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.bps . && ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.bps ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_Z}.db . && ln -s -r .${DB_Z}.idx ${DB_Z}.db ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_M}.db . && ln -s -r .${DB_M}.idx ${DB_M}.db ${REPMASK_OUTDIR}/"
       		echo -e "cd ${myCWD}"       		
       	fi > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	
       	setRunInfo ${SLURM_PARTITION} sequential 1 2048 00:30:00 -1 -1 > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set DBdust options 
        setDBdustOptions
        
        ### create DBdust commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/DBdust${DBDUST_OPT} ${DB_M%.db}.${x} && cd ${myCWD}"
            echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/DBdust${DBDUST_OPT} ${DB_Z%.db}.${x} && cd ${myCWD}"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL DBdust $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER DBdust $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set Catrack options 
        setCatrackOptions
        ### create Catrack command
        echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/Catrack${CATRACK_OPT} ${DB_M%.db} dust && cp .${DB_M%.db}.dust.anno .${DB_M%.db}.dust.data ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${CATRACK_OPT} ${DB_Z%.db} dust && cp .${DB_Z%.db}.dust.anno .${DB_Z%.db}.dust.data ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        
	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara                 
        echo "MARVEL Catrack $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then 
        ### clean up plans 
		for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        ### find and set datander options 
        setDatanderOptions
        
        ### create datander commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} datander${DATANDER_OPT} ${DB_Z%.db}.${x} && cd ${myCWD}"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara                 
        echo "DAZZLER datander $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
             
        ### find and set TANmask options         
        setTANmaskOptions
        ### create TANmask commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/TANmask${TANMASK_OPT} ${DB_Z%.db} TAN.${DB_Z%.db}.${x}.las && cd ${myCWD}" 
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAZZLER TANmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set Catrack options
        setCatrackOptions
        
        ### create Catrack command
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${CATRACK_OPT} ${DB_Z%.db} tan && cp .${DB_Z%.db}.tan.anno .${DB_Z%.db}.tan.data ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${LASTOOLS_PATH}/bin/viewmasks ${DB_Z%.db} tan > ${DB_Z%.db}.tan.txt && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
      	echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/txt2track -m ${DB_M%.db} ${DB_Z%.db}.tan.txt tan && cp .${DB_M%.db}.tan.a2 .${DB_M%.db}.tan.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
      	echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKcombine ${DB_M%.db} tan_dust tan dust && cp .${DB_M%.db}.tan_dust.a2 .${DB_M%.db}.tan_dust.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan 
        
	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "LASTOOLS viewmasks $(git --git-dir=${LASTOOLS_SOURCE_PATH}/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version    
        echo "DAMAR txt2track $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAMAR TKcombine $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
		setDalignerOptions 0
		
		## create job directories before daligner runs
		for x in $(seq 1 ${nblocks})
		do
			if [[ -d ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]} ]]
			then
				mv ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]} ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}_$(stat --format='%Y' ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]} | date '+%Y-%m-%d_%H-%M-%S')	
			fi
			mkdir -p ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}
		done

        bcmp=${REPEAT_BLOCKCMP[0]}
		
        ### create daligner commands
        n=${bcmp}
        for x in $(seq 1 ${nblocks})
        do
            if [[ $((x%bcmp)) -eq 1 || ${bcmp} -eq 1 ]]
            then 
              n=${bcmp}
            fi 
            echo -n "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x}"
            for y in $(seq ${x} $((${x}+${n}-1)))
            do
                if [[ ${y} -gt ${nblocks} ]]
                then
                    break
                fi
                echo -n " ${DB_Z%.db}.${y}"
            done 

			for y in $(seq ${x} $((${x}+${n}-1)))
            do
                if [[ ${y} -gt ${nblocks} ]]
                then
                    break
                fi
                echo -n " && mv ${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las mask_${x}_B${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}"
            done 
            
            n=$((${n}-1))

            echo " && cd ${myCWD}"
   		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
   		
   		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
		
		setDalignerOptions 0
		
        ### create LAmerge commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge -n 255 ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}.las mask_${x}_B${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]} && cd ${myCWD}"            
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version  
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        ### find and set LArepeat options 
        setREPmaskOptions ${pipelineName} 0
        
		### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}.las && cd ${myCWD}/" 
            echo "cd ${REPMASK_OUTDIR} && ln -s -f ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}.las ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}.${x}.las && ${DAZZLER_PATH}/bin/REPmask${REPMASK_OPT} ${DB_Z%.db} ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}.${x}.las && unlink ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[0]}C${REPEAT_COV[0]}.${x}.las && cd ${myCWD}/"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set TKmerge options 
        setCatrackOptions
        setLArepeatOptions ${pipelineName} 0
        ### create TKmerge commands
        echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${REPMASK_TKMERGE_OPT} ${DB_M%.db} ${REPEAT_TRACK[0]} && cp .${DB_M%.db}.${REPEAT_TRACK[0]}.a2 .${DB_M%.db}.${REPEAT_TRACK[0]}.d2 ${myCWD}/ && cd ${myCWD}/" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${REPMASK_TKMERGE_OPT} -f -v ${DB_Z%.db} ${REPEAT_TRACK[0]} && cp .${DB_Z%.db}.${REPEAT_TRACK[0]}.anno .${DB_Z%.db}.${REPEAT_TRACK[0]}.data ${myCWD}/ && cd ${myCWD}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version    
    elif [[ ${pipelineStepIdx} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setDalignerOptions 1 

		if [[ ${#REPEAT_BLOCKCMP[@]} -lt 2 || ${#REPEAT_COV[@]} -lt 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
			(>&2 echo "                                - found REPEAT_BLOCKCMP: \"${REPEAT_BLOCKCMP[@]}\" and REPEAT_COV: \"${REPEAT_COV[@]}\"")
        	exit 1
		fi
		
		if [[ ${REPEAT_BLOCKCMP[0]} -eq ${REPEAT_BLOCKCMP[1]} && ${REPEAT_COV[0]} -eq ${REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi

        bcmp=${REPEAT_BLOCKCMP[1]}
			
		## create job directories before daligner runs
		for x in $(seq 1 ${nblocks})
		do
			if [[ -d ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]} ]]
			then
				mv ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]} ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}_$(stat --format='%Y' ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]} | date '+%Y-%m-%d_%H-%M-%S')	
			fi
			mkdir -p ${REPMASK_OUTDIR}/mask_${x}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}	
		done		

        ### create daligner commands
        n=${bcmp}
        for x in $(seq 1 ${nblocks})
        do
            if [[ $(echo "$x%${bcmp}" | bc) -eq 1 || ${bcmp} -eq 1 ]]
            then 
              n=$((${bcmp}))
            fi 
            if [[ -n ${RAW_REPMASK_REPEATTRACK} ]]
            then
                REP="-m${RAW_REPMASK_REPEATTRACK}"
            fi

			if [[ "x${DALIGNER_VERSION}" == "x2" ]]
			then
				echo -n "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.@${x}"
			else
				echo -n "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x}"
			fi			
			
            for y in $(seq ${x} $((${x}+${n}-1)))
            do
                if [[ ${y} -gt ${nblocks} ]]
                then
                	y=$((y-1))
                    break
                fi
                if [[ "x${DALIGNER_VERSION}" != "x2" ]]
				then
					echo -n " ${DB_Z%.db}.${y}"
				fi			
                                
            done 
            
            if [[ "x${DALIGNER_VERSION}" == "x2" ]]
			then
				echo -n "-${y} && mv"
			else
				echo -n " && mv"
			fi			
            
            for y in $(seq ${x} $((${x}+${n}-1)))
            do
                if [[ ${y} -gt ${nblocks} ]]
                then
                    break
                fi
                echo -n " ${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las"
            done
            echo -n " mask_${x}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}"
            
            
			if [[ -z "${DALIGNER_ASYMMETRIC}" || ${DALIGNER_ASYMMETRIC} -ne 0 ]]
			then
				
				for y in $(seq $((x+1)) $((x+n-1)))
            	do
                	if [[ ${y} -gt ${nblocks} ]]
                	then
                    	break
                	fi
                	echo -n " && mv ${DB_Z%.db}.${y}.${DB_Z%.db}.${x}.las mask_${y}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}"
            	done
        	fi
 
            echo " && cd ${myCWD}"
            n=$((${n}-1))
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara 
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 11 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setDalignerOptions 1

		if [[ ${#REPEAT_BLOCKCMP[@]} -ne 2 || ${#REPEAT_COV[@]} -ne 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
        	exit 1
		fi
		
		if [[ ${REPEAT_BLOCKCMP[0]} -eq ${REPEAT_BLOCKCMP[1]} && ${REPEAT_COV[0]} -eq ${REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi

        ### create LAmerge commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge -n 255 ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}.las mask_${x}_B${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]} && cd ${myCWD}"            
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LAmerge  $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 12 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setREPmaskOptions ${pipelineName} 1		 

		if [[ ${#REPEAT_BLOCKCMP[@]} -ne 2 || ${#REPEAT_COV[@]} -ne 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
        	exit 1
		fi
		
		if [[ ${REPEAT_BLOCKCMP[0]} -eq ${REPEAT_BLOCKCMP[1]} && ${REPEAT_COV[0]} -eq ${REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi
        
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}.las && cd ${myCWD}/" 
            echo "cd ${REPMASK_OUTDIR} && ln -s -f ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}.las ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}.${x}.las && ${DAZZLER_PATH}/bin/REPmask${REPMASK_OPT} ${DB_Z%.db} ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}.${x}.las && unlink ${DB_Z%.db}.${x}.maskB${REPEAT_BLOCKCMP[1]}C${REPEAT_COV[1]}.${x}.las && cd ${myCWD}/"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 13 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setREPmaskOptions ${pipelineName} 1		
        
		if [[ ${#REPEAT_BLOCKCMP[@]} -ne 2 || ${#REPEAT_COV[@]} -ne 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
        	exit 1
		fi
		
		if [[ ${REPEAT_BLOCKCMP[0]} -eq ${REPEAT_BLOCKCMP[1]} && ${REPEAT_COV[0]} -eq ${REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPEAT_BLOCKCMP and/or REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi
        
        ### find and set TKmerge options 
        setCatrackOptions
        setLArepeatOptions ${pipelineName} 1
        ### create TKmerge commands
        echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${CATRACK_OPT} ${DB_M%.db} ${REPEAT_TRACK[1]} && cp .${DB_M%.db}.${REPEAT_TRACK[1]}.a2 .${DB_M%.db}.${REPEAT_TRACK[1]}.d2 ${myCWD}/ && cd ${myCWD}/" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${CATRACK_OPT} ${DB_Z%.db} ${REPEAT_TRACK[1]} && cp .${DB_Z%.db}.${REPEAT_TRACK[1]}.anno .${DB_Z%.db}.${REPEAT_TRACK[1]}.data ${myCWD}/ && cd ${myCWD}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan

	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
	fi
fi

exit 0
