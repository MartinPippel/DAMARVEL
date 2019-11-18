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

function setDBdustOptions()
{
    REPMASK_DBDUST_OPT=""
    if [[ -n ${RAW_REPMASK_DBDUST_BIAS} && ${RAW_REPMASK_DBDUST_BIAS} -ge 1 ]]
    then
        REPMASK_DBDUST_OPT="${REPMASK_DBDUST_OPT} -b"
    fi
}

function setCatrackOptions()
{
    REPMASK_CATRACK_OPT=""
    if [[ -n ${RAW_REPMASK_CATRACK_VERBOSE} && ${RAW_REPMASK_CATRACK_VERBOSE} -ge 1 ]]
    then
        REPMASK_CATRACK_OPT="${REPMASK_CATRACK_OPT} -v"
    fi
    if [[ -n ${RAW_REPMASK_CATRACK_DELETE} && ${RAW_REPMASK_CATRACK_DELETE} -ge 1 ]]
    then
        REPMASK_CATRACK_OPT="${REPMASK_CATRACK_OPT} -d"
    fi
    if [[ -n ${RAW_REPMASK_CATRACK_OVERWRITE} && ${RAW_REPMASK_CATRACK_OVERWRITE} -ge 1 ]]
    then
        REPMASK_CATRACK_OPT="${REPMASK_CATRACK_OPT} -f"
    fi
}

function setTANmaskOptions()
{
    REPMASK_TANMASK_OPT=""
    if [[ -n ${RAW_REPMASK_TANMASK_VERBOSE} && ${RAW_REPMASK_TANMASK_VERBOSE} -ge 1 ]]
    then
        REPMASK_TANMASK_OPT="${REPMASK_TANMASK_OPT} -v"
    fi
    if [[ -n ${RAW_REPMASK_TANMASK_MINLEN} && ${RAW_REPMASK_TANMASK_MINLEN} -ge 1 ]]
    then
        REPMASK_TANMASK_OPT="${REPMASK_TANMASK_OPT} -l${RAW_REPMASK_TANMASK_MINLEN}"
    fi
    if [[ -n ${RAW_REPMASK_TANMASK_TRACK} ]]
    then
        REPMASK_TANMASK_OPT="${REPMASK_TANMASK_OPT} -n${RAW_REPMASK_TANMASK_TRACK}"
    fi
}

function setDaligerOptions()
{
    REPMASK_DALIGNER_OPT=""
    if [[ -n ${RAW_REPMASK_DALIGNER_IDENTITY_OVLS} && ${RAW_REPMASK_DALIGNER_IDENTITY_OVLS} -gt 0 ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -I"
    fi
    if [[ -n ${RAW_REPMASK_DALIGNER_KMER} && ${RAW_REPMASK_DALIGNER_KMER} -gt 0 ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -k${RAW_REPMASK_DALIGNER_KMER}"
    fi
    if [[ -n ${RAW_REPMASK_DALIGNER_ERR} ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -e${RAW_REPMASK_DALIGNER_ERR}"
    fi
    if [[ -n ${RAW_REPMASK_DALIGNER_BIAS} && ${RAW_REPMASK_DALIGNER_BIAS} -eq 1 ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -b"
    fi
    if [[ -n ${RAW_REPMASK_DALIGNER_OLEN} ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -l${RAW_REPMASK_DALIGNER_OLEN}"
    fi    
    if [[ -n ${RAW_REPMASK_DALIGNER_MEM} && ${RAW_REPMASK_DALIGNER_MEM} -gt 0 ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -M${RAW_REPMASK_DALIGNER_MEM}"
    fi    
    if [[ -n ${RAW_REPMASK_DALIGNER_HITS} ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -h${RAW_REPMASK_DALIGNER_HITS}"
    fi        
    if [[ -n ${RAW_REPMASK_DALIGNER_T} ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -t${RAW_REPMASK_DALIGNER_T}"
    fi  
    if [[ -n ${RAW_REPMASK_DALIGNER_MASK} ]]
    then
        for x in ${RAW_REPMASK_DALIGNER_MASK}
        do 
            REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -m${x}"
        done
    fi
    if [[ -n ${RAW_REPMASK_DALIGNER_TRACESPACE} && ${RAW_REPMASK_DALIGNER_TRACESPACE} -gt 0 ]]
    then
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -s${RAW_REPMASK_DALIGNER_TRACESPACE}"
    fi
    if [[ -n ${THREADS_daligner} ]]
    then 
        REPMASK_DALIGNER_OPT="${REPMASK_DALIGNER_OPT} -T${THREADS_daligner}"
    fi
}

function setLArepeatOptions()
{
    idx=$1
    REPMASK_LAREPEAT_OPT=""
    if [[ -n ${RAW_REPMASK_LAREPEAT_LOW} ]]
    then
        REPMASK_LAREPEAT_OPT="${REPMASK_LAREPEAT_OPT} -l ${RAW_REPMASK_LAREPEAT_LOW}"
    fi
    if [[ -n ${RAW_REPMASK_LAREPEAT_HGH} ]]
    then
        REPMASK_LAREPEAT_OPT="${REPMASK_LAREPEAT_OPT} -h ${RAW_REPMASK_LAREPEAT_HGH}"
    fi
    if [[ -n ${RAW_REPMASK_LAREPEAT_OLEN} ]]
    then
        REPMASK_LAREPEAT_OPT="${REPMASK_LAREPEAT_OPT} -o ${RAW_REPMASK_LAREPEAT_OLEN}"
    fi
    if [[ -n ${RAW_REPMASK_LAREPEAT_REPEATTRACK} ]]
    then
        if [[ -z ${idx} ]]
        then
          RAW_REPMASK_REPEATTRACK=${RAW_REPMASK_LAREPEAT_REPEATTRACK}
          REPMASK_LAREPEAT_OPT="${REPMASK_LAREPEAT_OPT} -t ${RAW_REPMASK_REPEATTRACK}"
        else 
            if [[ ${#RAW_REPMASK_LAREPEAT_COV[*]} -lt ${idx} ]]
            then 
                (>&2 echo "RAW_REPMASK_LAREPEAT_COV has lower the ${idx} elements")
                exit 1
            elif [[ ${#RAW_REPMASK_BLOCKCMP[*]} -lt ${idx} ]]
            then 
                (>&2 echo "RAW_REPMASK_BLOCKCMP has lower the ${idx} elements")
                exit 1
            fi
            RAW_REPMASK_REPEATTRACK=${RAW_REPMASK_LAREPEAT_REPEATTRACK}_B${RAW_REPMASK_BLOCKCMP[${idx}]}C${RAW_REPMASK_LAREPEAT_COV[${idx}]}
            REPMASK_LAREPEAT_OPT="${REPMASK_LAREPEAT_OPT} -t ${RAW_REPMASK_REPEATTRACK}"
        fi
    fi
    if [[ -n ${RAW_REPMASK_LAREPEAT_COV} ]]
    then
        if [[ -z ${idx} ]]
        then
            REPMASK_LAREPEAT_OPT="${REPMASK_LAREPEAT_OPT} -c ${RAW_REPMASK_LAREPEAT_COV}"
        else
            if [[ ${#RAW_REPMASK_LAREPEAT_COV[*]} -lt ${idx} ]]
            then 
                (>&2 echo "RAW_REPMASK_LAREPEAT_COV has lower the ${idx} elements")
                exit 1
            fi
            REPMASK_LAREPEAT_OPT="${REPMASK_LAREPEAT_OPT} -c ${RAW_REPMASK_LAREPEAT_COV[${idx}]}"
        fi 
    fi
}

function setTKmergeOptions()
{
    REPMASK_TKMERGE_OPT=""
    if [[ -n ${RAW_REPMASK_TKMERGE_DELETE} && ${RAW_REPMASK_TKMERGE_DELETE} -ge 1 ]]
    then
        REPMASK_TKMERGE_OPT="${REPMASK_TKMERGE_OPT} -d"
    fi
    if [ ! -n ${RAW_REPMASK_LAREPEAT_REPEATTRACK} ] ### fall back to default value!!!
    then
        RAW_REPMASK_LAREPEAT_REPEATTRACK="repeats"
    fi
}

function setDatanderOptions()
{
    ### find and set datander options 
    REPMASK_DATANDER_OPT=""
    if [[ -n ${RAW_REPMASK_DATANDER_THREADS} ]]
    then
        REPMASK_DATANDER_OPT="${REPMASK_DATANDER_OPT} -T${RAW_REPMASK_DATANDER_THREADS}"
    fi
    if [[ -n ${RAW_REPMASK_DATANDER_MINLEN} ]]
    then
        REPMASK_DATANDER_OPT="${REPMASK_DATANDER_OPT} -l${RAW_REPMASK_DATANDER_MINLEN}"
    fi
}


if [[ -n ${PACBIO_TYPE} ]] 
then 
	if [[ "${PACBIO_TYPE}" == "LoFi" ]]
	then
		# check if DB's are available 
        if [[ ! ../${INIT_DIR}/pacbio/lofi/db/run/${PROJECT_ID}_M_LoFi.db ]]
        then 
    		(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh: Could not find database: ../${INIT_DIR}/pacbio/lofi/db/run/${PROJECT_ID}_M_LoFi.db! Run init first!!!");
   			exit 1        	
    	fi
    	
    	if [[ ! ../${INIT_DIR}/pacbio/lofi/db/run/${PROJECT_ID}_Z_LoFi.db ]]
        then 
    		(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh: Could not find database: ../${INIT_DIR}/pacbio/lofi/db/run/${PROJECT_ID}_Z_LoFi.db! Run init first!!!");
   			exit 1        	
    	fi
		
		DB_Z=${PROJECT_ID}_Z_LoFi
		DB_M=${PROJECT_ID}_M_LoFi				
	elif [[ "${PACBIO_TYPE}" == "HiFi" ]]
	then
		# check if DB's are available 
    	if [[ ! ../${INIT_DIR}/pacbio/hifi/db/run/${PROJECT_ID}_M_HiFi.db ]]
        then 
    		(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh: Could not find database: ../${INIT_DIR}/pacbio/hifi/db/run/${PROJECT_ID}_M_HiFi.db! Run init first!!!");
   			exit 1        	
    	fi
    	
    	if [[ ! ../${INIT_DIR}/pacbio/hifi/db/run/${PROJECT_ID}_Z_HiFi.db ]]
        then 
    		(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh: Could not find database: ../${INIT_DIR}/pacbio/hifi/db/run/${PROJECT_ID}_Z_HiFi.db! Run init first!!!");
   			exit 1        	
    	fi
		
		DB_Z=${PROJECT_ID}_Z_HiFi
		DB_M=${PROJECT_ID}_M_HiFi
	else
		(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh: PACBIO_TYPE: ${PACBIO_TYPE} is unknwon! Must be set to either LoFi or HiFi!");
   		exit 1
	fi
else
	(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh: Variable PACBIO_TYPE must be set to either LoFi or HiFi!");
   	exit 1
fi

# type_0 - stepsp[1-14}: 01_createSubdir, 02_DBdust, 03_Catrack, 04_datander, 05_TANmask, 06_Catrack, 07_daligner, 08_LAmerge, 09_LArepeat, 10_TKmerge, 11-daligner, 12-LAmerge, 13-LArepeat, 14-TKmerge
if [[ ${pipelineType} -eq 0 ]]
then
	if [[ ${pipelineStepIdx} -eq 0 ]]
    then
		### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
                        
        echo -e "if [[ -d ${RAW_REPMASK_OUTDIR} ]]; then mv ${RAW_REPMASK_OUTDIR} ${RAW_REPMASK_OUTDIR}_\$(stat --format='%Y' ${RAW_REPMASK_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi"
       	if [[ "${PACBIO_TYPE}" == "LoFi" ]]
       	then
       		echo -e "mkdir ${RAW_REPMASK_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.bps ${RAW_REPMASK_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.bps ${RAW_REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_Z}.db ${RAW_REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_M}.db ${RAW_REPMASK_OUTDIR}/"
       		echo -e "cd ${myCWD}"
        else
       		echo -e "mkdir ${RAW_REPMASK_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.bps ${RAW_REPMASK_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.bps ${RAW_REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_Z}.db ${RAW_REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_M}.db ${RAW_REPMASK_OUTDIR}/"
       		echo -e "åcd ${myCWD}"       		
       	fi > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
       	
       	setRunInfo ${SLURM_PARTITION} sequential 1 2048 00:30:00 -1 -1 > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set DBdust options 
        setDBdustOptions
        
        ### create DBdust commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/DBdust${REPMASK_DBDUST_OPT} ${DB_M%.db}.${x} && cd ${myCWD}"
            echo "cd ${RAW_REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/DBdust${REPMASK_DBDUST_OPT} ${DB_Z%.db}.${x} && cd ${myCWD}"
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL DBdust $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER DBdust $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set Catrack options 
        setCatrackOptions
        ### create Catrack command
        echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/Catrack${REPMASK_CATRACK_OPT} ${DB_M%.db} dust && cp .${DB_M%.db}.dust.anno .${DB_M%.db}.dust.data ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${RAW_REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${REPMASK_CATRACK_OPT} ${DB_Z%.db} dust && cp .${DB_Z%.db}.dust.anno .${DB_Z%.db}.dust.data ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        
        ## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara                 
        echo "MARVEL Catrack $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then 
        ### clean up plans 
		for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        ### find and set datander options 
        setDatanderOptions
        
        ### create datander commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/datander${REPMASK_DATANDER_OPT} ${DB_Z%.db}.${x} && cd ${myCWD}"
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara                 
        echo "DAZZLER datander $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
             
        ### find and set TANmask options         
        setTANmaskOptions
        ### create TANmask commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/TANmask${REPMASK_TANMASK_OPT} ${DB_Z%.db} TAN.${DB_Z%.db}.${x}.las && cd ${myCWD}" 
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAZZLER TANmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set Catrack options
        if [[ -z ${REPMASK_CATRACK_OPT} ]] 
        then
            setCatrackOptions
        fi
        ### create Catrack command
        echo "cd ${RAW_REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${REPMASK_CATRACK_OPT} ${DB_Z%.db} ${RAW_REPMASK_TANMASK_TRACK} && cp .${DB_Z%.db}.${RAW_REPMASK_TANMASK_TRACK}.anno .${DB_Z%.db}.${RAW_REPMASK_TANMASK_TRACK}.data ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${RAW_REPMASK_OUTDIR} && ${LASTOOLS_PATH}/bin/viewmasks ${DB_Z%.db} ${RAW_REPMASK_TANMASK_TRACK} > ${DB_Z%.db}.${RAW_REPMASK_TANMASK_TRACK}.txt && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
      	echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/txt2track -m ${DB_M%.db} ${DB_Z%.db}.${RAW_REPMASK_TANMASK_TRACK}.txt ${RAW_REPMASK_TANMASK_TRACK} && cp .${DB_M%.db}.${RAW_REPMASK_TANMASK_TRACK}.a2 .${DB_M%.db}.${RAW_REPMASK_TANMASK_TRACK}.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
      	echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKcombine ${DB_M%.db} ${RAW_REPMASK_TANMASK_TRACK}_dust ${RAW_REPMASK_TANMASK_TRACK} dust && cp .${DB_M%.db}.${RAW_REPMASK_TANMASK_TRACK}_dust.a2 .${DB_M%.db}.${RAW_REPMASK_TANMASK_TRACK}_dust.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan 
        
        ## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "LASTOOLS viewmasks $(git --git-dir=${LASTOOLS_SOURCE_PATH}/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version    
        echo "DAMAR txt2track $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAMAR TKcombine $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set daligner options 
        setDaligerOptions
		
		## create job directories before daligner runs
		for x in $(seq 1 ${nblocks})
		do
			if [[ -d ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]} ]]
			then
				mv ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]} ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}_$(stat --format='%Y' ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]} | date '+%Y-%m-%d_%H-%M-%S')	
			fi
			mkdir -p ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}	
		done

        bcmp=${RAW_REPMASK_BLOCKCMP[0]}
		
        ### create daligner commands
        n=${bcmp}
        for x in $(seq 1 ${nblocks})
        do
            if [[ $(echo "$x%${bcmp}" | bc) -eq 1 || ${bcmp} -eq 1 ]]
            then 
              n=${bcmp}
            fi 
            if [[ -n ${RAW_REPMASK_REPEATTRACK} ]]
            then
                REP="-m${RAW_REPMASK_REPEATTRACK}"
            fi
            if [[ -n ${RAW_REPMASK_DALIGNER_NUMACTL} && ${RAW_REPMASK_DALIGNER_NUMACTL} -gt 0 ]] && [[ "x${SLURM_NUMACTL}" == "x" || ${SLURM_NUMACTL} -eq 0 ]]
            then
                if [[ $((${x} % 2)) -eq  0 ]]
                then
                    NUMACTL="numactl -m0 -N0 "
                else
                    NUMACTL="numactl -m1 -N1 "    
                fi
            else
                NUMACTL=""
            fi
            echo -n "cd ${RAW_REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${NUMACTL}${DAZZLER_PATH}/bin/daligner${REPMASK_DALIGNER_OPT} ${REP} ${DB_Z%.db}.${x}"
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
                echo -n " && mv ${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las mask_${x}_B${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}"
            done 
            
            n=$((${n}-1))

            echo " && cd ${myCWD}"
   		done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
   		
   		## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
		
        ### create LAmerge commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge -n 32 ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}.las mask_${x}_B${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]} && cd ${myCWD}"            
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version  
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        ### find and set LArepeat options 
        setLArepeatOptions 0
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${REPMASK_LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}.las && cd ${myCWD}/" 
            echo "cd ${RAW_REPMASK_OUTDIR} && ln -s -f ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}.las ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}.${x}.las && ${DAZZLER_PATH}/bin/REPmask -v -c${RAW_REPMASK_LAREPEAT_COV[0]} -n${RAW_REPMASK_REPEATTRACK} ${DB_Z%.db} ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}.${x}.las && unlink ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[0]}C${RAW_REPMASK_LAREPEAT_COV[0]}.${x}.las && cd ${myCWD}/"
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set TKmerge options 
        setTKmergeOptions
        setLArepeatOptions 0
        ### create TKmerge commands
        echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${REPMASK_TKMERGE_OPT} ${DB_M%.db} ${RAW_REPMASK_REPEATTRACK} && cp .${DB_M%.db}.${RAW_REPMASK_REPEATTRACK}.a2 .${DB_M%.db}.${RAW_REPMASK_REPEATTRACK}.d2 ${myCWD}/ && cd ${myCWD}/" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${RAW_REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${REPMASK_TKMERGE_OPT} -f -v ${DB_Z%.db} ${RAW_REPMASK_REPEATTRACK} && cp .${DB_Z%.db}.${RAW_REPMASK_REPEATTRACK}.anno .${DB_Z%.db}.${RAW_REPMASK_REPEATTRACK}.data ${myCWD}/ && cd ${myCWD}/" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        ## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version    
    elif [[ ${pipelineStepIdx} -eq 10 && ${#RAW_REPMASK_BLOCKCMP[*]} -eq 2 && ${#RAW_REPMASK_LAREPEAT_COV[*]} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set daligner options 
        setDaligerOptions
		
        setLArepeatOptions 0
        bcmp=${RAW_REPMASK_BLOCKCMP[1]}
			
		## create job directories before daligner runs
		for x in $(seq 1 ${nblocks})
		do
			if [[ -d ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]} ]]
			then
				mv ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]} ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}_$(stat --format='%Y' ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]} | date '+%Y-%m-%d_%H-%M-%S')	
			fi
			mkdir -p ${RAW_REPMASK_OUTDIR}/mask_${x}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}	
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
            if [[ -n ${RAW_REPMASK_DALIGNER_NUMACTL} && ${RAW_REPMASK_DALIGNER_NUMACTL} -gt 0 ]] && [[ "x${SLURM_NUMACTL}" == "x" || ${SLURM_NUMACTL} -eq 0 ]]
            then
                if [[ $((${x} % 2)) -eq  0 ]]
                then
                    NUMACTL="numactl -m0 -N0 "
                else
                    NUMACTL="numactl -m1 -N1 "    
                fi
            else
                NUMACTL=""
            fi

			if [[ "x${DALIGNER_VERSION}" == "x2" ]]
			then
				echo -n "cd ${RAW_REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${NUMACTL}${DAZZLER_PATH}/bin/daligner${REPMASK_DALIGNER_OPT} ${REP} ${DB_Z%.db}.${x} ${DB_Z%.db}.@${x}"
			else
				echo -n "cd ${RAW_REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${NUMACTL}${DAZZLER_PATH}/bin/daligner${REPMASK_DALIGNER_OPT} ${REP} ${DB_Z%.db}.${x}"
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
            echo -n " mask_${x}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}"
            
            
			if [[ -z "${RAW_REPMASK_DALIGNER_ASYMMETRIC}" || ${RAW_REPMASK_DALIGNER_ASYMMETRIC} -ne 0 ]]
			then
				
				for y in $(seq $((x+1)) $((x+n-1)))
            	do
                	if [[ ${y} -gt ${nblocks} ]]
                	then
                    	break
                	fi
                	echo -n " && mv ${DB_Z%.db}.${y}.${DB_Z%.db}.${x}.las mask_${y}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}"
            	done
        	fi
 
            echo " && cd ${myCWD}"
            n=$((${n}-1))
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara 
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 11 && ${#RAW_REPMASK_BLOCKCMP[*]} -eq 2 && ${#RAW_REPMASK_LAREPEAT_COV[*]} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

        ### create LAmerge commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge -n 32 ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}.las mask_${x}_B${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]} && cd ${myCWD}"            
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LAmerge  $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 12 && ${#RAW_REPMASK_BLOCKCMP[*]} -eq 2 && ${#RAW_REPMASK_LAREPEAT_COV[*]} -eq 2 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set LArepeat options 
        setLArepeatOptions 1
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${REPMASK_LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}.las && cd ${myCWD}/" 
            echo "cd ${RAW_REPMASK_OUTDIR} && ln -s -f ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}.las ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}.${x}.las && ${DAZZLER_PATH}/bin/REPmask -v -c${RAW_REPMASK_LAREPEAT_COV[1]} -n${RAW_REPMASK_REPEATTRACK} ${DB_Z%.db} ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}.${x}.las && unlink ${DB_Z%.db}.${x}.maskB${RAW_REPMASK_BLOCKCMP[1]}C${RAW_REPMASK_LAREPEAT_COV[1]}.${x}.las && cd ${myCWD}/"
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 13 && ${#RAW_REPMASK_BLOCKCMP[*]} -eq 2 && ${#RAW_REPMASK_LAREPEAT_COV[*]} -eq 2 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set TKmerge options 
        setTKmergeOptions
        setLArepeatOptions 1
        ### create TKmerge commands
        echo "cd ${RAW_REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${REPMASK_TKMERGE_OPT} ${DB_M%.db} ${RAW_REPMASK_REPEATTRACK} && cp .${DB_M%.db}.${RAW_REPMASK_REPEATTRACK}.a2 .${DB_M%.db}.${RAW_REPMASK_REPEATTRACK}.d2 ${myCWD}/ && cd ${myCWD}/" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${RAW_REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${REPMASK_TKMERGE_OPT} -f -v ${DB_Z%.db} ${RAW_REPMASK_REPEATTRACK} && cp .${DB_Z%.db}.${RAW_REPMASK_REPEATTRACK}.anno .${DB_Z%.db}.${RAW_REPMASK_REPEATTRACK}.data ${myCWD}/ && cd ${myCWD}/" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        ## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
	fi
fi

exit 0
