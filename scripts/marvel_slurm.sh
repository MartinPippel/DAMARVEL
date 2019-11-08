#!/bin/bash 

configFile=$1
Id=$2
if [[ -z "$Id" ]]
then
  Id=1
fi

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] DAmar_slurm: cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}

## do some general sanity checks
	
if [[ -z "${PROJECT_ID}" ]]
then 
    (>&2 echo "[ERROR] DAmar_slurm: You have to specify a project id. Set variable PROJECT_ID")
    exit 1
fi

## find entry point to create first plan and submit that stuff 
if [[ ${INIT_SUBMIT_FROM} -gt 0 ]] 
then 
    currentPhase=0
    currentStep=${INIT_SUBMIT_FROM}
elif [[ ${RAW_MITO_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=1
    currentStep=${RAW_MITO_SUBMIT_SCRIPTS_FROM}    
elif [[ ${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=2
    currentStep=${RAW_DASCOVER_SUBMIT_SCRIPTS_FROM}    
elif [[ ${RAW_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=3
    currentStep=${RAW_REPMASK_SUBMIT_SCRIPTS_FROM}    
elif [[ ${RAW_PATCH_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=4
    currentStep=${RAW_PATCH_SUBMIT_SCRIPTS_FROM} 
elif [[ ${FIX_REPMASK_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=5
    currentStep=${FIX_REPMASK_SUBMIT_SCRIPTS_FROM}    
    
elif [[ ${FIX_SCRUB_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=6
    currentStep=${FIX_SCRUB_SUBMIT_SCRIPTS_FROM}        
elif [[ ${FIX_FILT_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=7
    currentStep=${FIX_FILT_SUBMIT_SCRIPTS_FROM}        
elif [[ ${FIX_TOUR_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=8
    currentStep=${FIX_TOUR_SUBMIT_SCRIPTS_FROM}        
elif [[ ${FIX_CORR_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=9
    currentStep=${FIX_CORR_SUBMIT_SCRIPTS_FROM}        
elif [[ ${COR_CONTIG_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=10
    currentStep=${COR_CONTIG_SUBMIT_SCRIPTS_FROM}        
elif [[ ${PB_ARROW_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=11
    currentStep=${PB_ARROW_SUBMIT_SCRIPTS_FROM}
elif [[ ${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=12
    currentStep=${CT_PURGEHAPLOTIGS_SUBMIT_SCRIPTS_FROM}
elif [[ ${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=13
    currentStep=${CT_FREEBAYES_SUBMIT_SCRIPTS_FROM}                                           
elif [[ ${CT_PHASE_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=14
    currentStep=${CT_PHASE_SUBMIT_SCRIPTS_FROM}
elif [[ ${SC_10X_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=15
    currentStep=${SC_10X_SUBMIT_SCRIPTS_FROM}
elif [[ ${SC_BIONANO_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=16
    currentStep=${SC_BIONANO_SUBMIT_SCRIPTS_FROM}
elif [[ ${SC_HIC_SUBMIT_SCRIPTS_FROM} -gt 0 ]] 
then 
    currentPhase=17
    currentStep=${SC_HIC_SUBMIT_SCRIPTS_FROM}        
else 
    echo "nothing to do"
    exit 0
fi

realPathConfigFile=$(realpath "${configFile}")

if [[ ${currentPhase} -eq 0 ]]
then
	if [[ -z "${INIT_DIR}" ]]
	then 
    	(>&2 echo "[ERROR] DAmar_slurm: You have to set INIT_DIR")
    	exit 1
	fi 
	
	mkdir -p ${INIT_DIR}
	cd ${INIT_DIR}
	${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${realPathConfigFile} ${currentPhase} ${currentStep} ${Id}
	cd ${myCWD}
elif [[ ${currentPhase} -eq 1 ]]
then 
	if [[ -z "${MITO_DIR}" ]]
	then 
    	(>&2 echo "[ERROR] DAmar_slurm: You have to set MITO_DIR.")
    	exit 1
	fi
	
	mkdir -p ${MITO_DIR}
	cd ${MITO_DIR}
	${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${realPathConfigFile} ${currentPhase} ${currentStep} ${Id}
	cd ${myCWD}
elif [[ ${currentPhase} -eq 2 ]]
then 
	if [[ -z "${COVERAGE_DIR}" ]]
	then 
    	(>&2 echo "[ERROR] DAmar_slurm: You have to set COVERAGE_DIR.")
    	exit 1
	fi

	if [[ -z "${DB_PATH}" ]]
	then 
    	(>&2 echo "[ERROR] DAmar_slurm: You have to set DB_PATH. Location of the initial databases MARVEL and DAZZLER.")
    	exit 1
	fi
	mkdir -p ${COVERAGE_DIR}
	cd ${COVERAGE_DIR}
	${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${realPathConfigFile} ${currentPhase} ${currentStep} ${Id}
	cd ${myCWD}
elif [[ ${currentPhase} -lt 5 ]]
then 

	if [[ -z "${PATCHING_DIR}" ]]
	then 
	    (>&2 echo "[ERROR] DAmar_slurm: You have to set PATCHING_DIR.")
	    exit 1
	fi

	if [[ -z "${DB_PATH}" ]]
	then 
    	(>&2 echo "[ERROR] DAmar_slurm: You have to set DB_PATH. Location of the initial databases MARVEL and DAZZLER.")
    	exit 1
	fi
	mkdir -p ${PATCHING_DIR}
	cd ${PATCHING_DIR}
	${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${realPathConfigFile} ${currentPhase} ${currentStep} ${Id}
	cd ${myCWD}
elif [[ ${currentPhase} -lt 18 ]]
then

	if [[ -z "${PATCHING_DIR}" ]]
	then 
    	(>&2 echo "[ERROR] DAmar_slurm: You have to set PATCHING_DIR.")
    	exit 1
	fi

	if [[ -z "${ASSMEBLY_DIR}" ]]
	then 
	    (>&2 echo "[ERROR] DAmar_slurm: You have to set ASSMEBLY_DIR")
	    exit 1
	fi
	
	if [[ "${ASSMEBLY_DIR}" == "${PATCHING_DIR}" ]]
	then 
	    (>&2 echo "[ERROR] DAmar_slurm: PATCHING_DIR must be different from ASSMEBLY_DIR")
	    exit 1
	fi
	
	if [[ -z "${DB_PATH}" ]]
	then 
	    (>&2 echo "[ERROR] DAmar_slurm: You have to set DB_PATH. Location of the initial databases MARVEL and DAZZLER.")
	    exit 1
	fi
	
	if [[ -z "${FIX_REPMASK_USELAFIX_PATH}" ]]
	then 
		(>&2 echo "[WARNING] DAmar_slurm: Variable FIX_REPMASK_USELAFIX_PATH is not set.Try to use default path: patchedReads_dalign")
		FIX_REPMASK_USELAFIX_PATH="patchedReads_dalign"
	fi
		
	mkdir -p ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
	cd ${ASSMEBLY_DIR}_${FIX_REPMASK_USELAFIX_PATH}
	${SUBMIT_SCRIPTS_PATH}/createAndSubmitMarvelSlurmJobs.sh ${realPathConfigFile} ${currentPhase} ${currentStep} ${Id}
	cd ${myCWD}
fi
