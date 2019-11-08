#!/bin/bash 

configFile=$1
currentStep=$2
slurmID=$3
currentPhase="init"

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}

if [[ -z ${PACBIO_PATH} || ! -d ${PACBIO_PATH} ]]
then
	(>&2 echo "[ERROR] createDBPlans.sh: Cannot find PacBio read path. Set variable PACBIO_PATH!")
    exit 1	
fi

sName=$(getStepName InitR ${RAW_INITR_TYPE} $((${currentStep}-1)))
sID=$(prependZero ${currentStep})

if [[ ${RAW_INITR_TYPE} -eq 0 ]]
then 
	### create sub-directory and link input files
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 

        if [[ -d ${DB_OUTDIR} ]]; then mv ${DB_OUTDIR} ${DB_OUTDIR}_$(stat --format='%Y' ${DB_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi 
        mkdir -p ${DB_OUTDIR}/fasta
        
        intype=""
		fnum=0
		# check for fasta files *fasta 
		for x in ${PACBIO_PATH}/*fasta
		do
			if [[ -f ${x} ]]
			then
				intype="fasta"
				fnum=$((fnum+1))	
			fi
		done
		
		if [[ "${intype}" == "fasta" ]]
		then
			mkdir -p ${DB_OUTDIR}/fasta
			for x in ${PACBIO_PATH}/*fasta
			do
				if [[ -f ${x} ]]
				then
					echo "ln -s -f -r ${x} ${DB_OUTDIR}/fasta"
				fi
			done > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.plan
		fi
	
		# check for zipped fasta files *fa.gz
		if [[ -z ${intype} ]]
		then
			for x in ${PACBIO_PATH}/*fa.gz
			do
				if [[ -f ${x} ]]
				then
					intype="fa.gz"
					fnum=$((fnum+1))
				fi
			done 
			
			if [[ "${intype}" == "fa.gz" ]]
			then
				for x in ${PACBIO_PATH}/*fa.gz
				do
					if [[ -f ${x} ]]
					then
						echo "zcat ${x} > ${DB_OUTDIR}/fasta/$(basename ${x%.fa.gz}).fasta"
					fi
				done > ${currentPhase}_${sID}_${sName}_block_${FIX_DB%.db}.${slurmID}.plan
			fi
		fi
		
		# check for subreads.bam files
		if [[ -z ${intype} ]]
		then
			for x in ${PACBIO_PATH}/*subreads.bam
			do
				if [[ -f ${x} ]]
				then
					intype="subreads.bam"
					fnum=$((fnum+1))
				fi
			done
			
			if [[ "${intype}" == "subreads.bam" ]]
			then
				if [[ ${PACBIO_TYPE} == "LoFi" ]]
				then					
					for x in ${PACBIO_PATH}/*subreads.bam
					do
						echo "${CONDA_BASE_ENV} && cd ${DB_OUTDIR}/fasta && bam2fasta -u -o $(basename ${x%.subreads.bam}) ${x} && cd ${myCWD} && conda deactivate" 
					done > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
				fi						 
			fi
		fi
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.version
	elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        if [[ -d ${DB_OUTDIR}/all ]]; then mv ${DB_OUTDIR}/all ${DB_OUTDIR}/all_$(stat --format='%Y' ${DB_OUTDIR}/all | date '+%Y-%m-%d_%H-%M-%S'); fi 
        mkdir ${DB_OUTDIR}/all ${DB_OUTDIR}/single ${DB_OUTDIR}/single 
               
        ## create database with all reads for coverage estimation
		echo "cd ${DB_OUTDIR}/all && ${DAZZLER_PATH}/bin/fasta2DB -v ${PROJECT_ID}_Z_LoFi_ALL ${DB_OUTDIR}/fasta/*fasta && cd ${myCWD}" > ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
		echo "cd ${DB_OUTDIR}/all && ${MARVEL_PATH}/bin/FA2db -x 0  ${PROJECT_ID}_M_LoFi_ALL ${DB_OUTDIR}/fasta/*fasta && cd ${myCWD}" >> ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan >> ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
		
		## create database for each bam file: for initial qc
		for x in ${DB_OUTDIR}/fasta/*fasta
		do
			echo "cd ${DB_OUTDIR}/single && ${DAZZLER_PATH}/bin/fasta2DB -v $(basename ${x%.fasta})_M ${x} && cd ${myCWD}"	
		done >> ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
        
    	## create actual db files for assembly 
        echo -n "cd ${DB_OUTDIR}/all && ${MARVEL_PATH}/bin/FA2db -x ${MIN_PACBIO_RLEN} -b -v ${PROJECT_ID}_M_LoFi ${DB_OUTDIR}/fasta/*fasta && ${MARVEL_PATH}/bin/DBsplit -s${DBSPLIT_SIZE} ${PROJECT_ID}_M_LoFi && ${MARVEL_PATH}/bin/DB2fa -v ${PROJECT_ID}_M_LoFi" >> ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
        echo -e " && ${DAZZLER_PATH}/bin/fasta2DB -v ${PROJECT_ID}_Z_LoFi *.fasta && ${DAZZLER_PATH}/bin/DBsplit -s${DBSPLIT_SIZE} ${PROJECT_ID}_Z_LoFi" >> ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
		
	
	
	
elif [[ ${RAW_INITR_TYPE} -eq 1 ]]
then 
	### create sub-directory and link input files
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 

        if [[ -d ${DB_OUTDIR} ]]; then mv ${DB_OUTDIR} ${DB_OUTDIR}_$(stat --format='%Y' ${DB_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi 
        mkdir ${DB_OUTDIR}
        
        intype=""
		fnum=0
		# check for fasta files *fasta 
		for x in ${PACBIO_PATH}/*fasta
		do
			if [[ -f ${x} ]]
			then
				intype="fasta"
				fnum=$((fnum+1))	
			fi
		done
		
		if [[ "${intype}" == "fasta" ]]
		then
			mkdir -p ${DB_OUTDIR}/fasta
			for x in ${PACBIO_PATH}/*fasta
			do
				if [[ -f ${x} ]]
				then
					echo "ln -s -f -r ${x} ${DB_OUTDIR}/fasta"
				fi
			done > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
		fi
	
		# check for zipped fasta files *fa.gz
		if [[ -z ${intype} ]]
		then
			for x in ${PACBIO_PATH}/*fa.gz
			do
				if [[ -f ${x} ]]
				then
					intype="fa.gz"
					fnum=$((fnum+1))
				fi
			done 
			
			if [[ "${intype}" == "fa.gz" ]]
			then
				mkdir -p ${DB_OUTDIR}/fa.gz
				for x in ${PACBIO_PATH}/*fa.gz
				do
					if [[ -f ${x} ]]
					then
						echo "ln -s -f -r ${x} ${DB_OUTDIR}/fa.gz"
					fi
				done > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
			fi
		fi
		
		# check for subreads.bam files
		if [[ -z ${intype} ]]
		then
			for x in ${PACBIO_PATH}/*subreads.bam
			do
				if [[ -f ${x} ]]
				then
					intype="subreads.bam"
					fnum=$((fnum+1))
				fi
			done
			
			if [[ "${intype}" == "subreads.bam" ]]
			then
				if [[ ${PACBIO_TYPE} == "LoFi" ]]
				then
					mkdir -p ${DB_OUTDIR}/fa.gz
					
					for x in ${PACBIO_PATH}/*subreads.bam
					do
						echo "${CONDA_BASE_ENV} && cd ${DB_OUTDIR}/fa.gz && bam2fasta -o $(basename ${x%.subreads.bam}) ${x} && cd ${myCWD} && conda deactivate" 
					done > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
				elif [[ ${PACBIO_TYPE} == "HiFi" ]] 
				then 
					mkdir -p ${DB_OUTDIR}/ccs
					
					OPT=""
						
					if [[ -n ${CCS_MINRQ} ]]
					then
						OPT="${OPT} --min-rq ${CCS_MINRQ}"	
					fi
					if [[ -n ${CCS_MINLEN} ]]
					then
						OPT="${OPT} --min-length ${CCS_MINLEN}"	
					fi
					if [[ -n ${CCS_MAXLEN} ]]
					then
						OPT="${OPT} --max-length ${CCS_MAXLEN}"	
					fi 
					if [[ -n ${CCS_MINPASSES} ]]
					then
						OPT="${OPT} --min-passes ${CCS_MINPASSES}"	
					fi
					if [[ -n ${CCS_MINSNR} ]]
					then
						OPT="${OPT} --min-snr ${CCS_MINSNR}"	
					fi
					if [[ -n ${CCS_THREADS} ]]
					then
						OPT="${OPT} --num-threads ${CCS_THREADS}"	
					fi
					
					for x in ${PACBIO_PATH}/*subreads.bam
					do
						for y in $(seq 1 ${CCS_NCHUNKS})
						do
							cname=$(basename ${x%.subreads.bam})
							echo "${CONDA_BASE_ENV} && cd ${DB_OUTDIR}/ccs && ccs${OPT} --report-file ${cname}.${y}.report.txt --chunk ${y}/${CCS_NCHUNKS} ${x} ${cname}.${y}.ccs.bam && cd ${myCWD} && conda deactivate"
						done 
					done > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.plan
				else
					(>&2 echo "[ERROR] createDBPlans.sh: Unknwon PACBIO_TYPE: ${PACBIO_TYPE}! Supported Types: LoFi or HiFi")
    				exit 1	
				fi							 
			fi
		fi
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${currentPhase}_${sID}_${sName}_block_${RAW_DB%.db}.${slurmID}.version
	elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${currentPhase}_${sID}_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        if [[ -d ${DB_OUTDIR}/all ]]; then mv ${DB_OUTDIR}/all ${DB_OUTDIR}/all_$(stat --format='%Y' ${DB_OUTDIR}/all | date '+%Y-%m-%d_%H-%M-%S'); fi 
        mkdir ${DB_OUTDIR}/all
        
        if [[ ${PACBIO_TYPE} != "LoFi" && ${PACBIO_TYPE} != "HiFi" ]]
		then
			(>&2 echo "[ERROR] createDBPlans.sh (${sName}): Unknwon PACBIO_TYPE: ${PACBIO_TYPE}! Supported Types: LoFi or HiFi")
			exit 1	
		fi
        
		if [[ -d ${DB_OUTDIR}/fasta ]]
		then
			echo "cd ${DB_OUTDIR}/all && ${DAZZLER_PATH}/bin/fasta2DB -v ${PROJECT_ID}_Z_${PACBIO_TYPE}_ALL ${DB_OUTDIR}/fasta/*fasta && cd ${myCWD}" > ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan
			echo "cd ${DB_OUTDIR}/all && ${MARVEL_PATH}/bin/FA2db -x 0  ${PROJECT_ID}_M_${PACBIO_TYPE}_ALL ${DB_OUTDIR}/fasta/*fasta && cd ${myCWD}" >> ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan 
		elif [[ -d ${DB_OUTDIR}/fa.gz ]]
		then
			echo -n "cd ${DB_OUTDIR}/all" > ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan
			for x in ${DB_OUTDIR}/fa.gz/*.fa.gz
			do
				echo -n " && zcat ${x} | ${DAZZLER_PATH}/bin/fasta2DB -v ${PROJECT_ID}_Z_${PACBIO_TYPE}_ALL -i$(basename ${x%.fa.gz})"				
			done >> ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan
			echo -e "&& cd ${myCWD}" >> ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan
			
			echo -n "cd ${DB_OUTDIR}/all" >> ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan
			for x in ${DB_OUTDIR}/fa.gz/*.fa.gz
			do
				echo -n " && zcat ${x} $(basename ${x%.fa.gz}).fasta && ${MARVEL_PATH}/bin/FA2db -v -x0 ${PROJECT_ID}_M_${PACBIO_TYPE}_ALL $(basename ${x%.fa.gz}).fasta && rm $(basename ${x%.fa.gz}).fasta"				
			done >> ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan
			echo -e "&& cd ${myCWD}" >> ${currentPhase}_${sID}_${sName}_block_${RAW_DBM%.db}.${slurmID}.plan
		elif [[ -d ${DB_OUTDIR}/ccs ]]
		then
			
			for x in ${DB_OUTDIR}/ccs/*.1.ccs.bam
			do
				name=$(basename ${x%.1.ccs.bam})
				echo -n "${CONDA_BASE_ENV} && samtools merge -@8 ${DB_OUTDIR}/ccs/${name}.css.bam ${DB_OUTDIR}/ccs/${name}.[0-9]*.css.bam && pbindex ${DB_OUTDIR}/ccs/${name}.css.bam"
				echo -n " && bam2fasta -o ${DB_OUTDIR}/fa.gz/${name}.ccs ${DB_OUTDIR}/ccs/${name}.css.bam && "
				echo -n " && rm ${DB_OUTDIR}/ccs/${name}.[0-9]*.css.bam"
				
				for y in $(seq 1 ${CCS_NCHUNKS})
				do
					cname=$(basename ${x%.subreads.bam})
					echo "${CONDA_BASE_ENV} && ccs${OPT} --report-file ${cname}.${y}.report.txt --chunk ${y}/${CCS_NCHUNKS} ${x} ${cname}.${y}.ccs.bam && cd ${myCWD} && conda deactivate"
				done 
			done
			
			
				
		fi
        
	fi
fi	
fi