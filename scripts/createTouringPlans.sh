#!/bin/bash -e

configFile=$1
currentStep=$2
slurmID=$3
currentPhase="tour"

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

if [[ ! -n "${FIX_TOUR_TYPE}" ]]
then 
    (>&2 echo "cannot create touring scripts if variable FIX_TOUR_TYPE is not set.")
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

function setOGbuildOptions()
{
    TOUR_OGBUILD_OPT=""
    
    if [[ -n ${FIX_TOUR_OGBUILD_CONT} && ${FIX_TOUR_OGBUILD_CONT} -ne 0 ]]
    then
        TOUR_OGBUILD_OPT="${TOUR_OGBUILD_OPT} -c ${FIX_TOUR_OGBUILD_CONT}"
    fi
    if [[ -n ${FIX_TOUR_OGBUILD_SPLIT} && ${FIX_TOUR_OGBUILD_SPLIT} -ne 0 ]]
    then
        TOUR_OGBUILD_OPT="${TOUR_OGBUILD_OPT} -s "
    fi
    if [[ -n ${FIX_TOUR_OGBUILD_TRIM} && ${FIX_TOUR_OGBUILD_TRIM} -ne 0 ]]
    then
        if [[ -z ${SCRUB_LAQ_OPT} ]]
        then 
            setLAqOptions
        fi

        if [ -n ${FIX_FILT_SCRUB_TYPE} ]
        then
            if [[ ${FIX_FILT_SCRUB_TYPE} -eq 1 ]]
            then 
                TOUR_OGBUILD_OPT="${TOUR_OGBUILD_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_dalign"
            elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 2 ]]
            then 
                TOUR_OGBUILD_OPT="${TOUR_OGBUILD_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_repcomp"
            elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 3 ]]
            then 
                TOUR_OGBUILD_OPT="${TOUR_OGBUILD_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_forcealign"
            fi
        else
            TOUR_OGBUILD_OPT="${TOUR_OGBUILD_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}"
        fi
    fi
}

function setOGtourOptions()
{
    TOUR_OGTOUR_OPT=""
    if [[ -n ${FIX_TOUR_OGTOUR_CIRCULAR} && ${FIX_TOUR_OGTOUR_CIRCULAR} -ne 0 ]]
    then
        TOUR_OGTOUR_OPT="${TOUR_OGTOUR_OPT} -c"
    fi
    if [[ -n ${FIX_TOUR_OGTOUR_DROPINV} && ${FIX_TOUR_OGTOUR_DROPINV} -ne 0 ]]
    then
        TOUR_OGTOUR_OPT="${TOUR_OGTOUR_OPT} -d"
    fi    
    if [[ -n ${FIX_TOUR_OGTOUR_LOOKAHAED} && ${FIX_TOUR_OGTOUR_LOOKAHAED} -gt 0 ]]
    then
        TOUR_OGTOUR_OPT="${TOUR_OGTOUR_OPT} -l ${FIX_TOUR_OGTOUR_LOOKAHAED}"
    fi
    
    if [[ -n ${FIX_TOUR_OGTOUR_MAXBACKBONEDIST} && ${FIX_TOUR_OGTOUR_MAXBACKBONEDIST} -gt 1 ]]
    then
        TOUR_OGTOUR_OPT="${TOUR_OGTOUR_OPT} -b ${FIX_TOUR_OGTOUR_MAXBACKBONEDIST}"
    fi  
    
    if [[ -n ${FIX_TOUR_OGTOUR_DEBUG} && ${FIX_TOUR_OGTOUR_DEBUG} -ne 0 ]]
    then
        TOUR_OGTOUR_OPT="${TOUR_OGTOUR_OPT} --debug"
    fi
      
}


function setLAfilterOptions()
{
    FILT_LAFILTER_OPT=""

    if [[ -z ${FIX_FILT_OUTDIR} ]]
    then
        FIX_FILT_OUTDIR="m1"
    fi
    
    ## its never used, but the variable is set once the function is called for the first time
    FILT_LAFILTER_OPT="-v"
}

function settour2fastaOptions()
{
    TOUR_2FASTA_OPT=""
    if [[ -n ${FIX_TOUR_2FASTA_SPLIT} && ${FIX_TOUR_2FASTA_SPLIT} -ne 0 ]]
    then
        TOUR_2FASTA_OPT="${TOUR_2FASTA_OPT} -s"
    fi
    if [[ -n ${FIX_TOUR_2FASTA_TRIM} && ${FIX_TOUR_2FASTA_TRIM} -ne 0 ]]
    then
        if [[ -z ${SCRUB_LAQ_OPT} ]]
        then 
            setLAqOptions
        fi

        if [[ ${FIX_FILT_SCRUB_TYPE} -eq 1 ]]
        then 
            TOUR_2FASTA_OPT="${TOUR_2FASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_dalign"
        elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 2 ]]
        then 
            TOUR_2FASTA_OPT="${TOUR_2FASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_repcomp"
        elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 3 ]]
        then 
            TOUR_2FASTA_OPT="${TOUR_2FASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_forcealign"
        fi        
    fi
}

function setOGlayoutOptions()
{
    TOUR_OGLAYOUT_OPT=""

    if [[ -n ${FIX_TOUR_OGLAYOUT_VERBOSE} && ${FIX_TOUR_OGLAYOUT_VERBOSE} -ne 0 ]]
    then
        TOUR_OGLAYOUT_OPT="${TOUR_OGLAYOUT_OPT} -v"
    fi
    if [[ -n ${FIX_TOUR_OGLAYOUT_DIST} && ${FIX_TOUR_OGLAYOUT_DIST} -ne 0 ]]
    then
        TOUR_OGLAYOUT_OPT="${TOUR_OGLAYOUT_OPT} -d ${FIX_TOUR_OGLAYOUT_DIST}"
    fi
    if [[ -n ${FIX_TOUR_OGLAYOUT_RMREVERSEEDGE} && ${FIX_TOUR_OGLAYOUT_RMREVERSEEDGE} -ne 0 ]]
    then
        TOUR_OGLAYOUT_OPT="${TOUR_OGLAYOUT_OPT} -R"
    fi
    
    if [[  "x${FIX_TOUR_OGLAYOUT_OUTPUTFORMAT}" == "x" ]]
    then
    	FIX_TOUR_OGLAYOUT_OUTPUTFORMAT="graphml"        
    fi    
}

## ensure some paths
if [[ -z "${MARVEL_SOURCE_PATH}" || ! -d  "${MARVEL_SOURCE_PATH}" ]]
then 
    (>&2 echo "ERROR - You have to set MARVEL_SOURCE_PATH. Used to report git version.")
    exit 1
fi

fixblocks=$(getNumOfDbBlocks ${FIX_DB%.db}.db)
sName=$(getStepName Tour ${FIX_TOUR_TYPE} $((${currentStep}-1)))
sID=$(prependZero ${currentStep})

myTypes=("1-OGbuild, 2-OGtour, 3-tour2fasta, 4-OGlayout, 5-statistics")
#type-0 steps: 1-OGbuild, 2-OGtour, 3-tour2fasta, 4-OGlayout, 5-statistics
if [[ ${FIX_TOUR_TYPE} -eq 0 ]]
then 
    ### OGbuild
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLAfilterOptions
        ### find and set OGbuild options 
        setOGbuildOptions
        ### create OGbuild commands
        echo "if [[ -d ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour ]]; then mv ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour_$(date '+%Y-%m-%d_%H-%M-%S'); fi" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "mkdir -p ${FIX_FILT_OUTDIR}/tour" >> ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan        
        echo "${MARVEL_PATH}/bin/OGbuild${TOUR_OGBUILD_OPT} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_DB%.db} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_DAZZ_DB%.db}.filt.las ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour/${PROJECT_ID}_${FIX_FILT_OUTDIR}" >> ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_single_${FIX_DB%.db}.${slurmID}.version
    ### OGtour
    elif [[ ${currentStep} -eq 2 ]]
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
        ### find and set OGbuild options 
        setOGtourOptions
        ### create OGbuild commands    
        for x in ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour/*[0-9].graphml; 
        do 
            if [[ -s ${x} ]]
            then
                echo "${MARVEL_PATH}/scripts/OGtour.py${TOUR_OGTOUR_OPT} ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_DB} $x"
            fi 
    	done > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.plan
    	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.version        
    ### tour2fasta
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
        ### find and set OGbuild options 
        settour2fastaOptions
        for x in ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour/*[0-9].tour.paths;
        do 
            if [[ -s ${x} ]]
            then
                echo "${MARVEL_PATH}/scripts/tour2fasta.py${TOUR_2FASTA_OPT} -p$(basename ${x%.tour.paths}) ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/${FIX_DB} ${x%.tour.paths}.graphml $x"
            fi
    	done > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.plan
    	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.version
    ### OGlayout
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
        ### find and set OGbuild options 
        setOGlayoutOptions   

        for x in ${FIX_FILT_OUTDIR}_${FIX_SCRUB_NAME}_FTYPE${FIX_FILT_TYPE}/tour/*[0-9].tour.paths; 
        do 
            if [[ -s ${x} ]]
            then
                echo "${MARVEL_PATH}/bin/OGlayout${TOUR_OGLAYOUT_OPT} ${x%.paths}.graphml ${x%.paths}.layout.${FIX_TOUR_OGLAYOUT_OUTPUTFORMAT}" 
            fi
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
	        echo "${SUBMIT_SCRIPTS_PATH}/assemblyStats.sh ${configFile} 6" > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.plan
		fi
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.version
    fi
fi

exit 0