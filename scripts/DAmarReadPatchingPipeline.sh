#!/bin/bash -e

#call: DAmarReadPatchingPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"

echo "[INFO] DAmarReadPatchingPipeline.sh - called with following $# args: $@"

if [[ $# -ne 4 ]]
then 
	(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh.sh: invalid number of arguments: $# Expected 4! ");
   	exit 1
fi

configFile=$1
pipelineName="fix"
pipelineType=$2
pipelineStepIdx=$3
pipelineRunID=$4

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh: cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}
### todo: how to handle more than slurm??? 
source ${SUBMIT_SCRIPTS_PATH}/slurm.cfg ${configFile}

pipelineStepName=$(getStepName ${pipelineName} ${pipelineType} ${pipelineStepIdx})
echo -e "[DEBUG] DAmarReadPatchingPipeline.sh: getStepName \"${pipelineName}\" \"${pipelineType}\" \"${pipelineStepIdx}\" --> ${pipelineStepName}"

setDabaseName

if [[ ! -n "${pipelineType}" ]]
then 
    (>&2 echo "cannot create read patching scripts if variable pipelineType is not set.")
    exit 1
fi


#type-0 - steps[1-10]: 01-createSubdir, 02-daligner, 03-LAmerge, 04-LArepeat, 05-TKmerge, 06-TKcombine, 07-LAfilter, 08-LAq, 09-TKmerge, 10-LAfix
#type-1 - steps[1-10]: 01-createSubdir, 02-LAseparate, 03-repcomp, 04-LAmerge, 05-LArepeat, 06-TKmerge, 07-TKcombine, 08-LAq, 09-TKmerge, 10-LAfix
#type-2 - steps[1-17]: 01-createSubdir, 02-lassort2, 03-computeIntrinsicQV, 04_Catrack, 05_lasdetectsimplerepeats, 06_mergeAndSortRepeats, 07_lasfilteralignments, 08_mergesym2, 09_filtersym, 10_lasfilteralignmentsborderrepeats, 11_mergesym2, 12_filtersym, 13_filterchainsraw, 14_LAfilterChains, 15_LAfilter, 16_split, 16_LAmerge, 17_LAfix
#type-3 - steps[1-1]:  01_patchStats 
if [[ ${pipelineType} -eq 0 ]]
then 
	if [[ ${pipelineStepIdx} -eq 0 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        echo -e "if [[ -d ${DALIGN_OUTDIR} ]]; then mv ${DALIGN_OUTDIR} ${DALIGN_OUTDIR}_\$(stat --format='%Y' ${DALIGN_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	if [[ "${PACBIO_TYPE}" == "LoFi" ]]
       	then
       		echo -e "mkdir ${DALIGN_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.bps ${DALIGN_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.bps ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_Z}.db ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_M}.db ${DALIGN_OUTDIR}/"
       	else
       		echo -e "mkdir ${DALIGN_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.bps ${DALIGN_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.bps ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_Z}.db ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_M}.db ${DALIGN_OUTDIR}/"
       	fi >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	
       	echo "for x in .${DB_Z}.*.anno .${DB_Z}.*.data .${DB_M}.*.d2 .${DB_M}.*.a2 .${DB_M}.*.anno .${DB_M}.*.data; do if [[ -f \${x} ]]; then ln -s -r \${x} ${DALIGN_OUTDIR}/; fi; done" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "for x in \$(seq 1 ${nblocks}); do mkdir -p ${DALIGN_OUTDIR}/d\${x}; done" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		
		setRunInfo ${SLURM_PARTITION} sequential 1 2048 00:30:00 -1 -1 > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set daligner options 
        setDalignerOptions -1  ## use all available repeat tracks
        ### create daligner commands
        cmdLine=1
        for x in $(seq 1 ${nblocks})
        do 
        	if [[ "x${DALIGNER_VERSION}" == "x2" ]]
        	then
        		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.@${x}"
			else
        		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x}"
			fi
            cmdLine=$((${cmdLine}+1))
            count=0

            for y in $(seq ${x} ${nblocks})
            do  
                if [[ $count -lt ${DALIGNER_BLOCKCMP} ]]
                then
                    count=$((${count}+1))
                    if [[ "x${DALIGNER_VERSION}" != "x2" ]]
            		then    
                    	echo -n " ${DB_Z%.db}.${y}"
                    fi
                else
                	if [[ "x${DALIGNER_VERSION}" == "x2" ]]
            		then    
                   		echo -n "-$((y-1)) && mv"
                	else
                		echo -n " && mv"
                	fi
                    
                    z=${count}
		    		while [[ $z -ge 1 ]]
		    		do
						echo -n " ${DB_Z%.db}.${x}.${DB_Z%.db}.$((y-z)).las"
						z=$((z-1))
		    		done
		    		echo -n " d${x}"
				    if [[ ${DALIGNER_ASYMMETRIC} -eq 0 ]]
				    then
						z=${count}
			            while [[ $z -ge 1 ]]
		        	    do
							if [[ ${x} -ne $((y-z)) ]]
							then
		                    	echo -n " && mv ${DB_Z%.db}.$((y-z)).${DB_Z%.db}.${x}.las d$((y-z))"
							fi
		                    z=$((z-1)) 
		            	done   
				    fi
				    echo " && cd ${myCWD}"
                    if [[ "x${DALIGNER_VERSION}" == "x2" ]]
            		then
                    		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.@${y}"
                	else
                		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.${y}"
                	fi
                    cmdLine=$((${cmdLine}+1))
                    count=1
                fi
            done
	    if [[ "x${DALIGNER_VERSION}" == "x2" ]]	
	    then
            echo -n "-${y} && mv"
	    else
			echo -n " && mv"
	    fi
            z=$((count-1))
            while [[ $z -ge 0 ]]
            do
                echo -n " ${DB_Z%.db}.${x}.${DB_Z%.db}.$((y-z)).las"
                z=$((z-1))
            done
            echo -n " d${x}"
            if [[ ${DALIGNER_ASYMMETRIC} -eq 0 ]]
            then
                z=$((count-1))
                while [[ $z -ge 0 ]]
                do
                    if [[ ${x} -ne $((y-z)) ]]
                    then
                       echo -n " && mv ${DB_Z%.db}.$((y-z)).${DB_Z%.db}.${x}.las d$((y-z))"
                    fi
                    z=$((z-1))
                done
            fi
            echo " && cd ${myCWD}"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara 
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAmerge options 
        setLAmergeOptions
        ### create LAmerge commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.dalign.${x}.las d${x} && ${MARVEL_PATH}/bin/LAfilter -p -R6 ${DB_M%.db} ${DB_Z%.db}.dalign.${x}.las ${DB_Z%.db}.dalignFilt.${x}.las && rm ${DB_Z%.db}.dalign.${x}.las && cd ${myCWD}"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara 
        echo "DAmar LAmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version             	       
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        setLArepeatOptions ${pipelineName} -1
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            y=0
        	while [[ $y -lt ${#REPEAT_TRACK[@]} ]] 
        	do
            	echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${LAREPEAT_OPT} -l${REPEAT_LOWCOV[${y}]} -h${REPEAT_HGHCOV[${y}]} -c${REPEAT_COV[${y}]} -t${REPEAT_TRACK[${y}]} -b ${x} ${DB_M%.db} ${DB_Z%.db}.dalignFilt.${x}.las && cd ${myCWD}/"
            	if [[ ${REPEAT_COV[${y}]} -gt 0 ]]
            	then
            		found=0
            		z=0
            		while [[ $z -lt $y ]]
            		do
            			if [[ ${REPEAT_COV[${z}]} == ${REPEAT_COV[${y}]} ]]
            			then
            				found=1
            				break
            			fi
            			z=$((z+1))
            		done
            		if [[ ${found} -eq 0 ]]
            		then
            			repmaskCov=$(echo "${REPEAT_HGHCOV[${y}]} ${REPEAT_COV[${y}]}" | awk '{printf "%d", $1*$2}')
            			echo "cd ${DALIGN_OUTDIR} && ${DAZZLER_PATH}/bin/REPmask -v -c${repmaskCov} -n${REPEAT_TRACK[$y]} ${DB_Z%.db} ${DB_Z%.db}.dalignFilt.${x}.las && cd ${myCWD}/"
            		fi
            	fi
            	y=$((y+1))
        	done
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan 
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version        
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
		# we need the name of the repeat track, especially if the plan starts with step4
        setLArepeatOptions ${pipelineName} -1
        ### find and set TKmerge options
        setTKmergeOptions
        
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	### create TKmerge command
        	echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} ${REPEAT_TRACK[${x}]} && cp .${DB_M%.db}.${REPEAT_TRACK[${x}]}.a2 .${DB_M%.db}.${REPEAT_TRACK[${x}]}.d2 ${myCWD} && cd ${myCWD}"
        	if [[ ${REPEAT_COV[${y}]} -gt 0 ]]
            	then
            		found=0
            		z=0
            		while [[ $z -lt $y ]]
            		do
            			if [[ ${REPEAT_COV[${z}]} == ${REPEAT_COV[${y}]} ]]
            			then
            				found=1
            				break
            			fi
            			z=$((z+1))
            		done
            		if [[ ${found} -eq 0 ]]
            		then      
        				echo "cd ${DALIGN_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${TKMERGE_OPT} -f -v ${DB_Z%.db} ${REPEAT_TRACK[${x}]} && cp .${DB_Z%.db}.${REPEAT_TRACK[${x}]}.anno .${DB_Z%.db}.${REPEAT_TRACK[${x}]}.data ${myCWD}/ && cd ${myCWD}/"
        			fi
        	fi
        	x=$((x+1))
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version   
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        repeatTracks=""     
        # we need the name of the repeat track, especially if the plan starts with step5
    	setLArepeatOptions rmask -1
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	repeatTracks="${repeatTrack} ${REPEAT_TRACK[${x}]}"
        	x=$(($x+1))
        done

        setLArepeatOptions ${pipelineName} -1
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	echo -n "${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} combinedRep${x}_pType${pipelineType} ${repeatTracks} ${REPEAT_TRACK[${x}]}" 
        	echo " && ${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} combinedRep${x}_pType${pipelineType}_tan_dust combinedRep${x}_pType${pipelineType} tan dust"
        	
        	x=$(($x+1))
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        
        ### find and set TKcombine options
        setTKcombineOptions 0
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara         
        echo "DAmar TKcombine $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

        mkdir -p identity
        ### create LAfilter commands - filter out identity overlaps - has to be done because revcomp and forcealign will loose those 
        for x in $(seq 1 ${nblocks})
        do  
            echo "${MARVEL_PATH}/bin/LAfilter -p -R 3 -R 6 ${DB_M%.db} ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${x}.las identity/${DB_Z%.db}.identity.${x}.las"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		getSlurmRunParameter ${pipelineStepName}
		setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara   
    	echo "DAmar LAfilter $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version    
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
		### find and set LAq options 
        setLAqOptions
        ### create LAq commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/LAq${LAQ_OPT} -T trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} -Q q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} ${DB_M%.db} -b ${x} ${DB_Z%.db}.dalignFilt.${x}.las && cd ${myCWD}"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar LAq $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version                
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the q and trim track names, especially if the plan starts with step11
        setLAqOptions
        setTKmergeOptions
        
		### create TKmerge command
        echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} && cp .${DB_M%.db}.trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.a2 .${DB_M%.db}.trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.d2 ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} && cp .${DB_M%.db}.q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.a2 .${DB_M%.db}.q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan       
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version	
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options 
        setLAfixOptions
        
    	mkdir -p ${DALIGN_OUTDIR}/patchedReads_pType${pipelineType}
		
		addOpt=""
        for x in $(seq 1 ${nblocks})
        do 
        	if [[ -n ${LAFIX_TRIMFILE} ]]
        	then 
        		addOpt="-T${DALIGN_OUTDIR}/${LAFIX_TRIMFILE}_${x}.txt "
        	fi
            echo "${MARVEL_PATH}/bin/LAfix${LAFIX_OPT} ${addOpt}${DB_M%.db} ${DALIGN_OUTDIR}/${DB_Z%.db}.dalignFilt.${x}.las ${DALIGN_OUTDIR}/patchedReads_pType${pipelineType}/${DB_M%.db}.${x}.fasta"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
    	echo "DAmar LAfix $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    else 
        (>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - pipelineStepIdx ${pipelineStepIdx} not supported! Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType}")
        exit 1                             
    fi     
#type-1 steps   [ 1-1] :  01-createSubdir, 02-LAseparate, 03-repcomp, 04-LAmerge, 05-LArepeat, 06-TKmerge, 07-TKcombine, 08-LAq, 09-TKmerge, 10-LAfix     
elif [[ ${pipelineType} -eq 1 ]]
then
	if [[ ${pipelineStepIdx} -eq 0 ]]
    then
		### clean up plans 
	    for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
	    do            
	        rm $x
	    done
	    
	    if [[ ! -d ${DALIGN_OUTDIR} ]]
	    then 
	    	(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType} - Directory ${DALIGN_OUTDIR} not present, run previous read patching pipeline first (at least until pipelineStepIdx 2)!")
	    	exit 1
		fi  
	    
		echo -e "if [[ -d ${REPCOMP_OUTDIR} ]]; then mv ${REPCOMP_OUTDIR} ${REPCOMP_OUTDIR}_\$(stat --format='%Y' ${REPCOMP_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "mkdir ${REPCOMP_OUTDIR}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "ln -s -r .${DB_Z}.bps ${REPCOMP_OUTDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "ln -s -r .${DB_M}.bps ${REPCOMP_OUTDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "cp .${DB_Z}.idx ${DB_Z}.db ${REPCOMP_OUTDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "cp .${DB_M}.idx ${DB_M}.db ${REPCOMP_OUTDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	
       	echo "for x in .${DB_Z}.*.anno .${DB_Z}.*.data .${DB_M}.*.d2 .${DB_M}.*.a2 .${DB_M}.*.anno .${DB_M}.*.data; do if [[ -f \${x} ]]; then ln -s -r \${x} ${REPCOMP_OUTDIR}/; fi; done" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "for x in \$(seq 1 ${nblocks}); do mkdir -p ${REPCOMP_OUTDIR}/r\${x} ${REPCOMP_OUTDIR}/d\${x}_ForRepComp ${REPCOMP_OUTDIR}/d\${x}_NoRepComp; done" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
	    		
		setRunInfo ${SLURM_PARTITION} sequential 1 2048 00:30:00 -1 -1 > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
  	#### LAseparate
  	elif [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

        ### find and set LAseparate options 
        setLAseparateOptions 0 0

        for x in $(seq 1 ${nblocks}); 
        do 
            for y in $(seq 1 ${nblocks}); 
            do 
                if [[ ! -f ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ]]
                then
                    (>&2 echo "step ${pipelineStepIdx} in pipelineType ${pipelineType}: File missing ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las!!")
                    exit 1                    
                fi
                echo "${MARVEL_PATH}/bin/LAseparate${LASEPARATE_OPT} ${DB_M%.db} ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ${REPCOMP_OUTDIR}/d${x}_ForRepComp/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ${REPCOMP_OUTDIR}/d${x}_NoRepComp/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las"                
            done 
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar LAseparate $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    #### repcomp 
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set repcomp options 
        setRepcompOptions

        cmdLine=1
        for x in $(seq 1 ${nblocks}); 
        do 
            srcDir=${REPCOMP_OUTDIR}/d${x}_ForRepComp
            desDir=${REPCOMP_OUTDIR}/r${x}

            if [[ ! -d ${desDir} ]]
            then
                mkdir -p ${desDir}
            fi
            start=${x}

            for y in $(seq ${start} ${nblocks}); 
            do 
                movDir=${REPCOMP_OUTDIR}/r${y}
                if [[ -f ${srcDir}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ]]
                then 
                    echo -n "${REPCOMP_PATH}/bin/repcomp${REPCOMP_OPT} -T/tmp/${DB_Z%.db}.${x}.${y} ${desDir}/${DB_Z%.db}.repcomp.${x}.${y} ${DB_Z%.db} ${srcDir}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las"
                    cmdLine=$((${cmdLine}+1))
                    if [[ $x -eq $y ]]
                    then
                        echo ""
                    else    
                        echo " && mv ${desDir}/${DB_Z%.db}.repcomp.${x}.${y}_r.las ${movDir}/"
                    fi
                else
                    (>&2 echo "step ${pipelineStepIdx} in pipelineType ${pipelineType}: File missing ${srcDir}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las!!")
                    exit 1
                fi
            done 
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "repcomp $(git --git-dir=${REPCOMP_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version		
	### 04_LAmergeLAfilter
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLAmergeOptions
        ### create LAmerge commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.repcomp.${x}.las r${x} d${x}_ForRepComp d${x}_NoRepComp ${myCWD}/identity/${DB_Z%.db}.identity.${x}.las && ${MARVEL_PATH}/bin/LAfilter -p -R6 ${DB_M%.db} ${DB_Z%.db}.repcomp.${x}.las ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}"                                                                                                                     
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar LAmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version    	
    ### 05_LArepeat
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLArepeatOptions ${pipelineName} -1
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
        	y=0
        	while [[ ${y} -lt ${#REPEAT_TRACK[@]} ]]
        	do
	            echo "cd ${REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${LAREPEAT_OPT} -l${REPEAT_LOWCOV[${y}]} -h${REPEAT_HGHCOV[${y}]} -c${REPEAT_COV[${y}]} -t${REPEAT_TRACK[${y}]} -b ${x} ${DB_M%.db} ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}/"
				if [[ ${REPEAT_COV[${y}]} -gt 0 ]]
            	then
            		found=0
            		z=0
            		while [[ $z -lt $y ]]
            		do
            			if [[ ${REPEAT_COV[${z}]} == ${REPEAT_COV[${y}]} ]]
            			then
            				found=1
            				break
            			fi
            			z=$((z+1))
            		done
            		if [[ ${found} -eq 0 ]]
            		then      
	            	            echo "cd ${REPCOMP_OUTDIR} && ${DAZZLER_PATH}/bin/REPmask -v -c${REPEAT_COV[${y}]} -n${REPEAT_TRACK[${y}]} ${DB_Z%.db} ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}/"
	            	fi
	        	fi
	        	y=$((y+1))    
	    	done
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
    	echo "DAmar LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    	echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### 06_TKmerge         
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLArepeatOptions ${pipelineName} -1
        setTKmergeOptions
        setCatrackOptions
	
		for x in $(seq 1 ${nblocks})
        do 
        	y=0
        	while [[ ${y} -lt ${#REPEAT_TRACK[@]} ]]
        	do
        		### create TKmerge command
		        echo -e "cd ${REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} ${REPEAT_TRACK[${y}]} && cp .${DB_M%.db}.${REPEAT_TRACK[${y}]}.a2 .${DB_M%.db}.${REPEAT_TRACK[${y}]}.d2 ${myCWD} && cd ${myCWD}/"
				if [[ ${REPEAT_COV[${y}]} -gt 0 ]]
            	then
            		found=0
            		z=0
            		while [[ $z -lt $y ]]
            		do
            			if [[ ${REPEAT_COV[${z}]} == ${REPEAT_COV[${y}]} ]]
            			then
            				found=1
            				break
            			fi
            			z=$((z+1))
            		done
            		if [[ ${found} -eq 0 ]]
            		then      
		        		echo -e "cd ${REPCOMP_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${CATRACK_OPT} ${DB_Z%.db} ${REPEAT_TRACK[${y}]} && cp .${DB_Z%.db}.${REPEAT_TRACK[${y}]}.anno .${DB_Z%.db}.${REPEAT_TRACK[${y}]}.data ${myCWD}/ && cd ${myCWD}/"
			        fi
			    fi
		      	y+$((y+1))
			done
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### TKcombine   
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        repeatTracks=""     
        # we need the name of the repeat track, especially if the plan starts with step5
    	setLArepeatOptions rmask -1
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	repeatTracks="${repeatTrack} ${REPEAT_TRACK[${x}]}"
        	x=$(($x+1))
        done

        setLArepeatOptions ${pipelineName} -1
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	echo -n "${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} combinedRep${x}_pType${pipelineType} ${repeatTracks} ${REPEAT_TRACK[${x}]}" 
        	echo " && ${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} combinedRep${x}_pType${pipelineType}_tan_dust combinedRep${x}_pType${pipelineType} tan dust"
        	
        	x=$(($x+1))
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        
        ### find and set TKcombine options
        setTKcombineOptions 0
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara         
        echo "DAmar TKcombine $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    ### LAq  
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set LAq options 
        setLAqOptions
        ### create LAq commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/LAq${LAQ_OPT} -T trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} -Q q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} ${DB_M%.db} -b ${x} ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
    	echo "MARVEL LAq $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
	### 09_TKmerge    	                 
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done  
           
        # we need the name of the q and trim track names, especially if the plan starts with step11
        setLAqOptions
        setTKmergeOptions
        
        ### create TKmerge command
        echo "cd ${REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} && cp .${DB_M%.db}.trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.a2 .${DB_M%.db}.trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.d2 ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} && cp .${DB_M%.db}.q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.a2 .${DB_M%.db}.q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan       
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version	                       
   ### 10 LAfix
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then
    	### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options 
        setLAfixOptions
        
    	mkdir -p ${REPCOMP_OUTDIR}/patchedReads_pType${pipelineType}
		
		addOpt=""
        for x in $(seq 1 ${nblocks})
        do 
        	if [[ -n ${LAFIX_TRIMFILE} ]]
        	then 
        		addOpt="-T${REPCOMP_OUTDIR}/${LAFIX_TRIMFILE}_${x}.txt "
        	fi
            echo "${MARVEL_PATH}/bin/LAfix${LAFIX_OPT} ${addOpt}${DB_M%.db} ${REPCOMP_OUTDIR}/${DB_Z%.db}.repcompFilt.${x}.las ${REPCOMP_OUTDIR}/patchedReads_pType${pipelineType}/${DB_M%.db}.${x}.fasta"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
    	echo "DAmar LAfix $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version    	                                  
    else 
       	(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - pipelineStepIdx ${pipelineStepIdx} not supported! Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType}")
        exit 1        
    fi  
elif [[ ${pipelineType} -eq 2 ]]
then 
	
	fsuffix="dalignFilt"
	if [[ "${DACCORD_INDIR}" == "${REPCOMP_OUTDIR}" ]]
	then
		fsuffix="repcompFilt"
	fi	
	
    ### create sub-directory and link relevant DB and Track files
    if [[ ${pipelineStepIdx} -eq 0 ]]
    then
        ### clean up plans 
    for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done     
        
		if [[ ${fsuffix} == "dalignFilt" && ! -d ${DALIGN_OUTDIR} ]]
	    then 
	    	(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType} - Directory ${DALIGN_OUTDIR} not present, run previous read patching pipeline first (at least until pipelineStepIdx 2)!")
	    	exit 1
		fi
		
		if [[ ${fsuffix} == "repcompFilt" && ! -d ${REPCOMP_OUTDIR} ]]
	    then 
	    	(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType} - Directory ${REPCOMP_OUTDIR} not present, run previous read patching pipeline first (at least until pipelineStepIdx 3)!")
	    	exit 1
		fi  
		  
	    
		echo -e "if [[ -d ${DACCORD_OUTDIR}_${DACCORD_INDIR} ]]; then mv ${DACCORD_OUTDIR}_${DACCORD_INDIR} ${DACCORD_OUTDIR}_${DACCORD_INDIR}_\$(stat --format='%Y' ${REPCOMP_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "mkdir ${DACCORD_OUTDIR}_${DACCORD_INDIR}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "ln -s -r .${DB_Z}.bps ${DACCORD_OUTDIR}_${DACCORD_INDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "ln -s -r .${DB_M}.bps ${DACCORD_OUTDIR}_${DACCORD_INDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "cp .${DB_Z}.idx ${DB_Z}.db ${DACCORD_OUTDIR}_${DACCORD_INDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	echo -e "cp .${DB_M}.idx ${DB_M}.db ${DACCORD_OUTDIR}_${DACCORD_INDIR}/" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	
       	echo "for x in .${DB_Z}.*.anno .${DB_Z}.*.data .${DB_M}.*.d2 .${DB_M}.*.a2 .${DB_M}.*.anno .${DB_M}.*.data; do if [[ -f \${x} ]]; then ln -s -r \${x} ${DACCORD_OUTDIR}_${DACCORD_INDIR}/; fi; done" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
	    		
		setRunInfo ${SLURM_PARTITION} sequential 1 2048 00:30:00 -1 -1 > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
 	### 02-lassort
	elif [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
    	for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

		setlassortOptions
		
		for x in $(seq 1 ${nblocks})
        do
        	echo "${LASTOOLS_PATH}/bin/lassort ${LASSORT_OPT} ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}Sort.${x}.las ${DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}.${x}.las"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan    	 
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara        
        echo "LASTOOLS lassort $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### 03-computeIntrinsicQV
	elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 				
		
		setComputeIntrinsicQV2Options
		
		for x in $(seq 1 ${nblocks})
        do
        	echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ln -s -f ${DB_Z%.db}.${fsuffix}Sort.${x}.las ${DB_Z%.db}.${x}.${fsuffix}Sort.las && ${DACCORD_PATH}/bin/computeintrinsicqv2${COMPUTEINTRINSICQV_OPT} ${DB_Z%.db}.db ${DB_Z%.db}.${x}.${fsuffix}Sort.las && unlink ${DB_Z%.db}.${x}.${fsuffix}Sort.las && cd ${myCWD}"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara    	         
        echo "DACCORD computeintrinsicqv2 $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
	### 04_Catrack
	elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        setCatrackOptions
        
        echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DAZZLER_PATH}/bin/Catrack ${DB_Z%.db}.db inqual && cp .${DB_Z%.db}.inqual.anno .${DB_Z%.db}.inqual.data ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
		echo "DAZZ_DB Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version                
    ### 05_lasdetectsimplerepeats
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
               
        setLasDetectSimpleRepeatsOptions      
                   	
        for x in $(seq 1 ${nblocks})
        do
        	echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/lasdetectsimplerepeats${LASDETECTSIMPLEREPEATS_OPT} ${DB_Z%.db}.rep.${x}.data ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}Sort.${x}.las && cd ${myCWD}"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
      	echo "DACCORD lasdetectsimplerepeats $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### 06_mergeAndSortRepeats
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
       
    	echo "if [[ -f ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.data ]]; then echo \"[WARNING] - File ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.data already exists! Will be removed!\"; rm ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.data; fi" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	# create empty file !!! 
    	echo -e "touch ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.data" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "for x in $(seq 1 ${nblocks});" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "do" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "	if [[ ! -f ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.${x}.data ]];" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "   then " >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "        echo \"[ERROR] - File ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.${x}.data is missing. Stop here!\";" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "        exit 1;" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "   fi;"  >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "   cat ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.${x}.data > ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.data" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "done" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "cat ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.data | ${DACCORD_PATH}/bin/repsort ${DB_Z%.db}.db > ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.repSort.data && mv ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.repSort.data ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.rep.data" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
		getSlurmRunParameter ${pipelineStepName}
    	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DACCORD repsort $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### 07_lasfilteralignments 
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        setLasfilterAlignmentsOptions
            	
        for x in $(seq 1 ${nblocks})
        do
        	echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/lasfilteralignments ${LASFILTERALIGNMENTS_OPT} ${DB_Z%.db}.${fsuffix}SortFilt1.${x}.las ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}Sort.${x}.las && cd ${myCWD}"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
      	echo "DACCORD lasfilteralignments $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### 08_mergesym2
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/mergesym2 ${DB_Z%.db}.${fsuffix}SortFilt1.sym ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt1.*.las.sym && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && rm ${DB_Z%.db}.${fsuffix}SortFilt1.*.las.sym && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        ## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
		getSlurmRunParameter ${pipelineStepName}
    	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DACCORD mergesym2 $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version        
	### 09_filtersym
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
   	 	for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/filtersym ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt1.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt1.sym" 
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
		getSlurmRunParameter ${pipelineStepName}
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
      	echo "DACCORD filtsym $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version                 
   	### 10_lasfilteralignmentsborderrepeats
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        setLasfilterAlignmentsBorderRepeatsOptions
        
   	 	for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/lasfilteralignmentsborderrepeats${LASFILTERALIGNMENTSBORDERREPEATS_OPT} ${DB_Z%.db}.${fsuffix}SortFilt2.${x}.las ${DB_Z%.db}.db ${DB_Z%.db}.rep.data ${DB_Z%.db}.${fsuffix}SortFilt1.${x}.las && cd ${mxCWD}" 
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
      	echo "DACCORD lasfilteralignmentsborderrepeats $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
  	### 11_mergesym2
    elif [[ ${pipelineStepIdx} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/mergesym2 ${DB_Z%.db}.${fsuffix}SortFilt2.sym ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt2.*.las.sym && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && rm ${DB_Z%.db}.${fsuffix}SortFilt2.*.las.sym && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DACCORD mergesym2 $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version        
	### 12_filtersym
    elif [[ ${pipelineStepIdx} -eq 11 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
           	 	
   	 	for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/filtersym ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt2.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt2.sym && cd ${myCWD}" 
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
		getSlurmRunParameter ${pipelineStepName}
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
      	echo "DACCORD filtsym $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### 13_filterchainsraw
    elif [[ ${pipelineStepIdx} -eq 12 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        setFilterChainsRawOptions   
    	setLAfilterOptions ${pipelineName} -1    
        
        for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/filterchainsraw ${LASFILTERCHAINSRAW_OPT} ${DB_Z%.db}.${fsuffix}SortFilt2Chain.${x}.las ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt2.${x}.las && ${MARVEL_PATH}/bin/LAfilter ${LAFILTER_OPT} ${DB_M%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt2Chain.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las && cd ${myCWD}" 
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
    	echo "DACCORD filterchainsraw $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version      	
    ### 14_daccord
    elif [[ ${pipelineStepIdx} -eq 13 ]]
    then
        ### clean up plans 
    	for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
	
		setDaccordOptions        
		
		for x in $(seq 1 ${nblocks})
		do
    		echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/daccord ${DACCORD_OPT} --eprofonly -E${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.eprof ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las ${DB_Z%.db}.db && ${DACCORD_PATH}/bin/daccord ${DACCORD_OPT} -E${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.eprof ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las ${DB_Z%.db}.db > ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.dac.fasta && cd ${myCWD}"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DACCORD daccord $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
   	### 15_computeextrinsicqv
    elif [[ ${pipelineStepIdx} -eq 14 ]]
    then
        ### clean up plans 
    	for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setComputeExtrinsicQVOptions
        
        echo -e "for x in $(seq 1 ${nblocks});" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo -e "do" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo -e "  if  [[ ! -f ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.dac.fasta ]];" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo -e "  then" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo -e "    echo \"[ERROR] - File ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.dac.fasta is missing. Stop here!\";" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "    exit 1;" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo -e "  fi" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo -e "  cat ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.dac.fasta;" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	echo -e "done > ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2.dac.fasta" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo -e "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/computeextrinsicqv${COMPUTEEXTRINSICQV_OPT} ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.dac.fasta ${DB_Z%.db}.db && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan 
        setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DACCORD computeextrinsicqv $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    ### 16_split
    elif [[ ${pipelineStepIdx} -eq 15 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
		setHaploSplitOptions
		
		# create folder structure
		for x in $(seq 1 ${nblocks})
		do
			directory="${DACCORD_OUTDIR}_${DACCORD_INDIR}/${HAPLOSPLIT_BIN}_s${x}"
			if [[ -d "${directory}" ]]
			then
					mv ${directory} ${directory}_$(stat --format='%Y' ${directory} | date '+%Y-%m-%d_%H-%M-%S'); 
			fi
			
			mkdir -p ${directory}			
		done 
        
        for x in $(seq 1 ${nblocks})
		do
			for y in $(seq 0 $((HAPLOSPLIT_NBLOCKS-1)))
			do
				echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${DACCORD_PATH}/bin/${HAPLOSPLIT_BIN}${HAPLOSPLIT_OPT} -E${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.eprof -J${y},${HAPLOSPLIT_NBLOCKS} ${HAPLOSPLIT_BIN}_s${x}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2Split.${y}.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las ${DB_Z%.db}.db && cd ${myCWD}"		
			done	    		
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DACCORD ${HAPLOSPLIT_BIN} $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
	### 17_LAmerge 
    elif [[ ${pipelineStepIdx} -eq 16 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        		        
        setHaploSplitOptions
        setLAmergeOptions
        
        for x in $(seq 1 ${nblocks})
		do
			echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${MARVEL_PATH}/bin/LAmerge ${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.${fsuffix}SortFilt2Chain2_${HAPLOSPLIT_BIN}.${x}.keep.las ${HAPLOSPLIT_BIN}_s${x}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2Split.*.${x}.las ${myCWD}/identity/${DB_Z%.db}.identity.${x}.las && cd ${myCWD}"
			echo "cd ${DACCORD_OUTDIR}_${DACCORD_INDIR} && ${MARVEL_PATH}/bin/LAmerge ${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.${fsuffix}SortFilt2Chain2_${HAPLOSPLIT_BIN}.${x}.drop.las ${HAPLOSPLIT_BIN}_s${x}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2Split.*.${x}_drop.las ${myCWD}/identity/${DB_Z%.db}.identity.${x}.las && cd ${myCWD}"	
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LAmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
	### 18_LAfix    
    elif [[ ${pipelineStepIdx} -eq 17 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

		setHaploSplitOptions
        ### find and set LAfix options 
        setLAfixOptions
        
    	mkdir -p ${DACCORD_OUTDIR}_${DACCORD_INDIR}/patchedReads_pType${pipelineType}
		
		addOpt=""
        for x in $(seq 1 ${nblocks})
        do 
        	if [[ -n ${LAFIX_TRIMFILE} ]]
        	then 
        		addOpt="-T${DACCORD_OUTDIR}_${DACCORD_INDIR}/${LAFIX_TRIMFILE}_${x}.txt "
        	fi
        	echo "${MARVEL_PATH}/bin/LAfix${LAFIX_OPT} ${addopt}${DB_M%.db} ${DACCORD_OUTDIR}_${DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2_${HAPLOSPLIT_BIN}.${x}.keep.las ${DACCORD_OUTDIR}_${DACCORD_INDIR}/patchedReads_pType${pipelineType}/${DB_M%.db}.${x}.fasta"            
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LAfix $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version                
	else
        (>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - pipelineStepIdx ${pipelineStepIdx} not supported! Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType}")
        exit 1
    fi
elif [[ ${pipelineType} -eq 3 ]]
then
  	if [[ ${pipelineStepIdx} -eq 0 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done    
        
        if [[ -n ${SLURM_STATS} && ${SLURM_STATS} -gt 0 ]]
   		then
	        ### run slurm stats - on the master node !!! Because sacct is not available on compute nodes
	        if [[ $(hostname) == "falcon1" || $(hostname) == "falcon2" ]]
	        then 
	        	bash ${SUBMIT_SCRIPTS_PATH}/slurmStats.sh ${configFile}
	    	else
	        	cwd=$(pwd)
	        	ssh falcon "cd ${cwd} && bash ${SUBMIT_SCRIPTS_PATH}/slurmStats.sh ${configFile}"
	    	fi
		fi
		if [[ -n ${MARVEL_STATS} && ${MARVEL_STATS} -gt 0 ]]
   		then
	        ### create assemblyStats plan
	    	echo "${SUBMIT_SCRIPTS_PATH}/patchingStats.sh ${configFile} 1" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		fi
        echo "DAmar patchingStats.sh $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
    else
		(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - pipelineStepIdx ${pipelineStepIdx} not supported! Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType}")
        exit 1        
    fi
else
	(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh - pipelineType ${pipelineType} not supported! Current - pipelineName: ${pipelineName} pipelineType: ${pipelineType}")
    exit 1
fi

exit 0
