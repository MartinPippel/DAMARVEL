#!/bin/bash -e

configFile=$1
currentStep=$2
slurmID=$3
currentPhase="corr"


if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}

if [[ -z ${FIX_FILT_SCRUB_TYPE} ]]
then
	(>&2 echo "WARNING - Variable FIX_FILT_SCRUB_TYPE is not set. Use default mode: dalign!")
	FIX_FILT_SCRUB_TYPE=1
fi

if [[ -z "${PROJECT_ID}" ]]
then 
    (>&2 echo "ERROR - You have to specify a project id. Set variable PROJECT_ID")
    exit 1
fi

if [[ ! -n "${FIX_CORR_TYPE}" ]]
then 
    (>&2 echo "cannot create touring scripts if variable FIX_CORR_TYPE is not set.")
    exit 1
fi

if [[ ! -n ${RAW_DB} ]]
then 
    (>&2 echo "raw database unknown - You have to set the variable RAW_DB")
    exit 1
fi

if [[ ! -f ${RAW_DB%.db}.db ]]
then 
    (>&2 echo "raw database ${RAW_DB%.db}.db missing")
    exit 1 
fi

if [[ ! -n ${FIX_DB} ]]
then 
    (>&2 echo "patched database unknown - You have to set the variable FIX_DB")
    exit 1
fi

if [[ ! -f ${FIX_DB%.db}.db ]]
then 
    (>&2 echo "patched database ${FIX_DB%.db}.db missing")
    exit 1
fi

if [[ ! -n ${COR_DB} ]]
then 
    (>&2 echo "corrected database unknown - You have to set the variable COR_DB")
    exit 1
fi

function setLAfilterOptions()
{
    FILT_LAFILTER_OPT=""

    if [[ -z ${FIX_FILT_OUTDIR} ]]
    then
        FIX_FILT_OUTDIR="m1"
    fi
    
    ## its never used, but the variable is set once the function called for the first time
    FILT_LAFILTER_OPT="-v"    
}

function setpath2ridsOptions()
{
    COR_PATH2RIDS_OPT=""
    if [[ -z ${FIX_CORR_PATHS2RIDS_FILE} ]]
    then
      FIX_CORR_PATHS2RIDS_FILE=${COR_DB%.db}.tour.rids
    fi
}

function setLAqOptions()
{
    SCRUB_LAQ_OPT=""
    adaptQTRIMCUTOFF=""    

    if [[ -n ${FIX_SCRUB_LAQ_MINSEG} && ${FIX_SCRUB_LAQ_MINSEG} -ne 0 ]]
    then
        SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -s ${FIX_SCRUB_LAQ_MINSEG}"
    else 
        FIX_SCRUB_LAQ_MINSEG=25
        SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -s ${FIX_SCRUB_LAQ_MINSEG}"
    fi

    if [[ -n ${FIX_SCRUB_LAQ_QTRIMCUTOFF} && ${FIX_SCRUB_LAQ_QTRIMCUTOFF} -ne 0 ]]
    then
        if [[ -n ${RAW_FIX_DALIGNER_TRACESPACE} && ${RAW_FIX_DALIGNER_TRACESPACE} -ne 100 ]]
        then 
            adaptQTRIMCUTOFF=$(echo "${FIX_SCRUB_LAQ_QTRIMCUTOFF}*${RAW_FIX_DALIGNER_TRACESPACE}/100+1" | bc)
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"
        else
            adaptQTRIMCUTOFF=${FIX_SCRUB_LAQ_QTRIMCUTOFF}
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"            
        fi
    else 
        if [[ -n ${RAW_FIX_DALIGNER_TRACESPACE} && ${RAW_FIX_DALIGNER_TRACESPACE} -ne 100 ]]
        then 
            FIX_SCRUB_LAQ_QTRIMCUTOFF=25
            adaptQTRIMCUTOFF=$(echo "${FIX_SCRUB_LAQ_QTRIMCUTOFF}*${RAW_FIX_DALIGNER_TRACESPACE}/100+1" | bc)
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"
        else
            adaptQTRIMCUTOFF=25
            FIX_SCRUB_LAQ_QTRIMCUTOFF=25
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"            
        fi
    fi
}

function setLAcorrectOptions()
{
    COR_LACORRECT_OPT=""

    if [[ -n ${FIX_CORR_LACORRECT_VERBOSE} ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -v"
    fi
    if [[ -n ${FIX_CORR_LACORRECT_THREAD} ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -j ${FIX_CORR_LACORRECT_THREAD}"
    fi 
    if [[ -z ${FIX_CORR_PATHS2RIDS_FILE} ]]
    then 
        setpath2ridsOptions
    fi
    if [[ -z ${FILT_LAFILTER_OPT} ]]
    then
        setLAfilterOptions
    fi
    COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -r ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_CORR_PATHS2RIDS_FILE}"

    if [[ -z ${SCRUB_LAQ_OPT} ]]
    then
        setLAqOptions
    fi

    if [[ ${FIX_FILT_SCRUB_TYPE} -eq 1 ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -q q0_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_dalign"
    elif  [[ ${FIX_FILT_SCRUB_TYPE} -eq 2 ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -q q0_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_repcomp"
    elif  [[ ${FIX_FILT_SCRUB_TYPE} -eq 3 ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -q q0_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_forcealign"
    fi             
}

function setTourToFastaOptions()
{
    COR_TOURTOFASTA_OPT=""
    if [[ -n ${COR_CORR_TOURTOFASTA_SPLIT} ]]
    then
        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -s"
    fi
    
    if [[ -n ${FIX_CORR_2FASTA_TRIM} ]]
    then 
    	COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t ${FIX_CORR_2FASTA_TRIM}"
	else
	    if [[ ${FIX_FILT_SCRUB_TYPE} -eq 1 ]]
	    then
	        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_dalign"
	    elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 2 ]]
	    then
	        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_repcomp"
	    elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 3 ]]
	    then
	        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_forcealign"
	    fi
	fi
}


## ensure some paths
if [[ -z "${MARVEL_SOURCE_PATH}" || ! -d  "${MARVEL_SOURCE_PATH}" ]]
then 
    (>&2 echo "ERROR - You have to set MARVEL_SOURCE_PATH. Used to report git version.")
    exit 1
fi

fixblocks=$(getNumOfDbBlocks ${FIX_DB%.db}.db)
sName=$(getStepName Corr ${FIX_CORR_TYPE} $((${currentStep}-1)))
sID=$(prependZero ${currentStep})

myTypes=("1-paths2rids, 2-LAcorrect, 3-prepDB, 4-tour2fasta, 5-statistics")
#type-0 steps: 1-paths2rids, 2-LAcorrect, 3-prepDB, 4-tour2fasta, 5-statistics
if [[ ${FIX_CORR_TYPE} -eq 0 ]]
then 
    ### paths2rids
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        setLAfilterOptions
        setpath2ridsOptions

        # create sym links
        echo "if [[ -d ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR} ]]; then mv ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}_\$(stat --format='%Y' ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR} | date '+%Y-%m-%d_%H-%M-%S'); fi" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "mkdir -p ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/reads ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/contigs" >> ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "for x in ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour/*[0-9].tour.paths; do ln -s -r \${x} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/contigs/\$(basename \${x%.tour.paths}.tour.paths) && ln -s -r \${x%.tour.paths}.graphml ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/contigs/\$(basename \${x%.tour.paths}.graphml); done" >> ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "cat ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/contigs/*.paths | awk '{if (NF > 4) print \$0}' | ${MARVEL_PATH}/scripts/paths2rids.py - ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_CORR_PATHS2RIDS_FILE}" >> ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.version
    ### LAcorrect
    elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        setLAcorrectOptions

        for x in $(seq 1 ${fixblocks})
        do 
        echo "${MARVEL_PATH}/bin/LAcorrect${COR_LACORRECT_OPT} -b ${x} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_DB%.db} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_DAZZ_DB%.db}.filt.${x}.las ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/reads/${FIX_DB%.db}.${x}"
        done > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_${FIX_DB%.db}.${slurmID}.version
    ### prepare corrected db 
    elif [[ ${currentStep} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions
        fi

        echo "if [[ -f ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/${COR_DB%.db}.db ]]; then ${MARVEL_PATH}/bin/DBrm ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/${COR_DB%.db}; fi" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "${MARVEL_PATH}/bin/FA2db -x0 -c source -c correctionq -c postrace ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/${COR_DB%.db} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/reads/${FIX_DB%.db}.[0-9]*.[0-9]*.fasta" >> ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.version            
    elif [[ ${currentStep} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done
        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions
        fi
        setTourToFastaOptions
        for x in ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/contigs/*.tour.paths
        do 
            echo "${MARVEL_PATH}/scripts/tour2fasta.py${COR_TOURTOFASTA_OPT} -p $(basename ${x%.tour.paths}) -c ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${COR_DIR}/${COR_DB%.db} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_DB%.db} ${x%.tour.paths}.graphml ${x}" 
        done > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.version
    ### statistics
    elif [[ ${currentStep} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions
        fi
        
        run=0
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
        	echo "${SUBMIT_SCRIPTS_PATH}/assemblyStats.sh ${configFile} 7" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.version
        	run=1
    	fi    
    	
    	if [[ $run -eq 0 ]]
    	then 
    		touch ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan	
    	fi
    fi
fi

exit 0