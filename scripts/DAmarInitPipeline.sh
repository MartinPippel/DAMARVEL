#!/bin/bash -e

#call: DAmarInitPipeline.sh ${configFile} ${pipelineTypeID} ${pipelineStepIdx} ${pipelineRunID}"

echo "[INFO] DAmarInitPipeline.sh - called with following $# args: $@"

if [[ $# -ne 4 ]]
then 
	(>&2 echo "[ERROR] DAmarInitPipeline.sh: invalid number of arguments: $# Expected 4! ");
   		exit 1
fi

configFile=$1
pipelineTypeID=$2
pipelineStepIdx=$(prependZero $3)
pipelineRunID=$4

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] DAmarInitPipeline: cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}
### todo: how to handle more than slurm??? 
source ${SUBMIT_SCRIPTS_PATH}/slurm.cfg ${configFile}

pipelineName=$(pipelineIDToName ${pipelineTypeID}]}
pipelineStepName=$(getStepName ${pipelineName} ${pipelineTypeID} ${pipelineStepIdx})

function setFastpOptions()
{
	if [[ -z "${RAW_MASH_FASTP_THREADS}" ]]
	then 
		RAW_MASH_FASTP_THREADS=4	
	fi
}

function setJellyfishOptions()
{
	JELLYFISH_OPT=""
	
	if [[ "x$1" == "xcount" ]]
	then 
		if [[ -z "${RAW_QC_JELLYFISH_KMER}" ]]
		then 
			RAW_QC_JELLYFISH_KMER=21	
		fi
		JELLYFISH_OPT="${JELLYFISH_OPT} -m ${RAW_QC_JELLYFISH_KMER}"
		
		if [[ -z "${RAW_QC_JELLYFISH_SIZE}" ]]
		then 
			RAW_QC_JELLYFISH_SIZE=1000000000
		fi
		JELLYFISH_OPT="${JELLYFISH_OPT} -C"
		JELLYFISH_OPT="${JELLYFISH_OPT} -s ${RAW_QC_JELLYFISH_SIZE}"			
	elif [[ "x$1" == "xhisto" ]]
	then
		if [[ -z "${RAW_QC_JELLYFISH_LOWHIST}" ]]
		then 
			RAW_QC_JELLYFISH_LOWHIST=1	
		fi
		JELLYFISH_OPT="${JELLYFISH_OPT} -l ${RAW_QC_JELLYFISH_LOWHIST}"
		 
		if [[ -z "${RAW_QC_JELLYFISH_HIGHHIST}" ]]
		then 
			RAW_QC_JELLYFISH_HIGHHIST=1000000
		fi
		JELLYFISH_OPT="${JELLYFISH_OPT} -h ${RAW_QC_JELLYFISH_HIGHHIST}"
	fi 
	
	## general options, that are common in count and histo
	if [[ -z "${RAW_QC_JELLYFISH_THREADS}" ]]
	then 
		RAW_QC_JELLYFISH_THREADS=12
	fi
	
	JELLYFISH_OPT="${JELLYFISH_OPT} -t ${RAW_QC_JELLYFISH_THREADS}"
	
	if [[ -n "${RAW_QC_JELLYFISH_VERBOSE}" ]]
	then 
		JELLYFISH_OPT="${JELLYFISH_OPT} -v"
	fi	
}

function setGenomeScopeOptions()
{
	# get the kmers that were used  in JellyFish 
	setJellyfishOptions count

	##TODO set max read length ???		
	RAW_QC_GENOMESCOPE_KMER=${RAW_QC_JELLYFISH_KMER}
	
	RAW_QC_GENOMESCOPE_KMERMAX=${RAW_QC_JELLYFISH_HIGHHIST}
}

#type-0 [10x - init] 							[1-3]: longrangerBasic, longrangerToScaff10Xinput, bxcheck, createStats
#type-1 [PacBio LoFi Init] 						[1-3]: bam2fasta createDB createStats
#type-2 [PacBio HiFi Init] 						[1-3]: createSubdir ccs samtoolsMerge bam2fasta createDB createStats
#type-3 [HiC - init]							[1-1]: createStats 
#type-4 [Bionano - init]						[1-1]: createStats???
#type-5 [10x - de novo] 						[1-1]: 01_supernova
#type-6 [10x|HiC - kmer-Gsize estimate] 		[1-2]: 01_genomescope
#type-7 [allData - MASH CONTAMINATION SCREEN] 	[1-5]: 01_mashPrepare, 02_mashSketch, 03_mashCombine, 04_mashPlot, 05_mashScreen
#type-8 [10x - QV]   							[1-6]: 01_QVprepareInput, 02_QVlongrangerAlign, 03_QVcoverage, 04_QVfreebayes, 05_QVbcftools, 06_QVqv

#type-0 [10x - prepare] [1-3]: 01_longrangerBasic, 02_longrangerToScaff10Xinput, 03_bxcheck
if [[ ${pipelineTypeID} -eq 0 ]]
then
	### 01_longrangerBasic
    if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        mkdir -p ${QC_OUTDIR}
        
        ## check if 10x data is available
        if [[ -n ${TENX_PATH} && -d "${TENX_PATH}" ]]
        then
        	## we have to trim off the 10x adapter
        	
        	numR1Files=0
			for x in ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR1Files=$((${numR1Files}+1))	
				fi
			done
			
			if [[ ${numR1Files} -eq 0 ]]
	        then
	        	(>&2 echo "[ERROR] createQCendStatsPlans: Cannot read 10x R1 files with following pattern: ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz")
	        	exit 1
	   		fi
	   		
	   		numR2Files=0
			for x in ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR2Files=$((${numR2Files}+1))	
				fi
			done
			
			if [[ ${numR2Files} -eq 0 ]]
	        then
	        	(>&2 echo "[ERROR] createQCendStatsPlans: Cannot read 10x R2 files with following pattern: ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz")
	        	exit 1
	   		fi
	   		
	   		if [[ ${numR1Files} -ne ${numR2Files} ]]
	        then
	        	(>&2 echo "[ERROR] createQCendStatsPlans: 10x R1 files ${numR1Files} does not match R2 files ${numR2Files}")
	        	exit 1
	   		fi	   		
	   		
	   		if [[ -d ${QC_OUTDIR}/10x_${PROJECT_ID}_longrangerBasic ]]
	   		then 
	   			echo "mv ${QC_OUTDIR}/10x_${PROJECT_ID}_longrangerBasic ${QC_OUTDIR}/10x_${PROJECT_ID}_longrangerBasic_\$(stat --format='%Y' ${QC_OUTDIR}/10x_${PROJECT_ID}_longrangerBasic | date '+%Y-%m-%d_%H-%M-%S')"
	   		fi
	   		
	   		## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   		getSlurmRunParameter ${sName}
	   		
	   		slurmOpt="--jobmode=slurm_${SLURM_PARTITION} --maxjobs=1000 --jobinterval=500 --disable-ui --nopreflight"
			echo "cd ${QC_OUTDIR} && ${LONGRANGER_PATH}/longranger basic --id=10x_${PROJECT_ID}_longrangerBasic --fastqs=${TENX_PATH} --sample=${PROJECT_ID} ${slurmOpt} && cd ${myCWD}"	   					 
		fi > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
        
        echo "longranger basic $(${LONGRANGER_PATH}/longranger basic --version | head -n1)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
        setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara
    ## 02_longrangerToScaff10Xinput
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        longrangerOut="${QC_OUTDIR}/10x_${PROJECT_ID}_longrangerBasic/outs/barcoded.fastq.gz"
        
        if [[ ! -f ${longrangerOut} ]] 
       	then 
       		(>&2 echo "ERROR - longranger 10x data is not present at: ${longrangerOut}! Run longranger basic on 10x reads first!")
	        exit 1
       	fi
       	
   		## convert longranger single file (fastq.gz) into two separated R1 R2 files (compressed?) and add 10x-barcode to header 
    	## ? get rid of unrecognized barcode entries ?
       	echo "mkdir -p ${QC_OUTDIR}/scaff10x" > ${currentPhase}_${sID}_${sName}.plan
       	echo "gunzip -c ${longrangerOut} | paste - - - - - - - - | awk '/ BX:Z:/{print \$1\"_\"substr(\$2,6,16)\" \"\$3\" \"\$4\" \"\$5\" \"\$6\"_\"substr(\$7,6,16)\" \"\$8\" \"\$9\" \"\$10}' | tee >(cut -f 1-4 -d \" \" | tr \" \" \"\\n\" > ${QC_OUTDIR}/scaff10x/reads-1.fq) | cut -f 5-8 -d \" \" | tr \" \" \"\\n\" > ${QC_OUTDIR}/scaff10x/reads-2.fq" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
       	echo "$(awk --version | head -n1)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
        setRunInfo ${SLURM_PARTITION} sequential 1 2048 $(getPartitionMaxTime ${SLURM_PARTITION}) -1 -1 > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara	
	## 03_bxcheck   
	elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
	    (>&2 echo "03_bxcheck not implemented yet!")
        exit 1
    fi
elif [[ ${pipelineTypeID} -eq 1 ]]
then 
	#type-1 [PacBio LoFi Init] 						[1-3]: bam2fasta createDB createStats
	### create sub-directory and link input files
    if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.* 2> /dev/null)
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
			done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
			setRunInfo ${SLURM_PARTITION} sequential 1 2048 00:30:00 -1 -1 > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara
			echo "$(ln --version  | head -n1)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
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
				if [[ -z ${bgzipSlurmPara} ]]
				then
					getSlurmRunParameter bgzipSlurmPara
					echo "$(${CONDA_BASE_ENV} && bgzip --version  | head -n1 && conda deactivate)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
				else
					getSlurmRunParameter defaultSlurmPara
					echo "$(zcat --version  | head -n1)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
				fi 
				
				for x in ${PACBIO_PATH}/*fa.gz
				do
					if [[ -f ${x} ]]
					then
						if [[ -z ${bgzipSlurmPara} ]]
						then 
							echo "${CONDA_BASE_ENV} && bgzip -d -@${SLURM_RUN_PARA[1]} ${x} > ${DB_OUTDIR}/fasta/$(basename ${x%.fa.gz}).fasta && conda deactivate"
							 
						else 
							echo "zcat ${x} > ${DB_OUTDIR}/fasta/$(basename ${x%.fa.gz}).fasta"
						fi
					fi
				 done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
				 ## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   			setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara							 
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
						echo -n "${CONDA_BASE_ENV} && cd ${DB_OUTDIR}/fasta"
						if [[ ! -f ${x}.pbi ]]
						then
							echo -n " && pbindex ${x}"	
						fi
						echo -e " && bam2fasta -u -o $(basename ${x%.subreads.bam}) ${x} && cd ${myCWD} && conda deactivate" 
					done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
				else
					(>&2 echo "[ERROR] createQCandStatsPlans.sh: PACBIO_TYPE is not set to LoFi!")
					exit 1
				fi						 
			else
				(>&2 echo "[ERROR] createQCandStatsPlans.sh: Could not find any subreads.bam file in directory: ${PACBIO_PATH}!")
				exit 1
			fi
			
			echo "$(${CONDA_BASE_ENV} && bam2fasta --version && conda deactivate)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
			## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   		getSlurmRunParameter ${sName}
			setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara			
		fi        
	elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        if [[ -d ${DB_OUTDIR}/all ]]; then mv ${DB_OUTDIR}/all ${DB_OUTDIR}/all_$(stat --format='%Y' ${DB_OUTDIR}/all | date '+%Y-%m-%d_%H-%M-%S'); fi
        if [[ -d ${DB_OUTDIR}/single ]]; then mv ${DB_OUTDIR}/single ${DB_OUTDIR}/all_$(stat --format='%Y' ${DB_OUTDIR}/single | date '+%Y-%m-%d_%H-%M-%S'); fi
        if [[ -d ${DB_OUTDIR}/run ]]; then mv ${DB_OUTDIR}/run ${DB_OUTDIR}/all_$(stat --format='%Y' ${DB_OUTDIR}/run | date '+%Y-%m-%d_%H-%M-%S'); fi 
        mkdir -p ${DB_OUTDIR}/all ${DB_OUTDIR}/single ${DB_OUTDIR}/run 
               
        ## create database with all reads for coverage estimation
		echo "${DAZZLER_PATH}/bin/fasta2DB -v ${DB_OUTDIR}/all/${PROJECT_ID}_Z_LoFi_ALL ${DB_OUTDIR}/fasta/*fasta" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
		echo "${MARVEL_PATH}/bin/FA2db -x 0  ${DB_OUTDIR}/all/${PROJECT_ID}_M_LoFi_ALL ${DB_OUTDIR}/fasta/*fasta" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
		
		## create database for each bam file: for initial qc
		for x in ${DB_OUTDIR}/fasta/*fasta
		do
			echo "${MARVEL_PATH}/bin/FA2db -v ${DB_OUTDIR}/single/$(basename ${x%.fasta})_M ${x}"	
		done >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
        
    	## create actual db files for assembly 
        echo -n "cd ${DB_OUTDIR}/run && ${MARVEL_PATH}/bin/FA2db -x ${MIN_PACBIO_RLEN} -b -v ${PROJECT_ID}_M_LoFi ../fasta/*fasta && ${MARVEL_PATH}/bin/DBsplit -s${DBSPLIT_SIZE} ${PROJECT_ID}_M_LoFi && ${MARVEL_PATH}/bin/DB2fa -v ${PROJECT_ID}_M_LoFi" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
        echo -e " && ${DAZZLER_PATH}/bin/fasta2DB -v ${PROJECT_ID}_Z_LoFi *.fasta && ${DAZZLER_PATH}/bin/DBsplit -s${DBSPLIT_SIZE} ${PROJECT_ID}_Z_LoFi && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
	
		echo "MARVEL FA2db $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
        echo "DAZZLER fasta2DB $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version
		
		## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${sName}
		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara
	elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        if [[ -d ${DB_OUTDIR}/stats ]]; then mv ${DB_OUTDIR}/stats ${DB_OUTDIR}/stats_$(stat --format='%Y' ${DB_OUTDIR}/all | date '+%Y-%m-%d_%H-%M-%S'); fi 
        mkdir ${DB_OUTDIR}/stats
        
        count=0
        for x in ${DB_OUTDIR}/single/*db 
        do 
        	if [[ -f ${x} ]]
        	then
        		echo -n "echo ${count}"
        		echo -n " \$(sed -n 2p ${x} | awk '{print \$2\" \"\$3}')"
        		echo -n " \$(${MARVEL_PATH}/bin/DBstats -r ${x} | sed -n 1p)"
    			echo -n " \$((\$(${MARVEL_PATH}/bin/DBstats -r ${x} | sed -n 1p | awk '{print \$2}')/${gsize}))"
    			echo -n " \$(${MARVEL_PATH}/bin/DBstats -r ${x} | sed -n 2p | awk '{print \$2\" \"\$4\" \"\$6\" \"\$8\" \"\$2+\$8\" \"\$4+\$6}')"
    			echo -n " \$(${MARVEL_PATH}/bin/DBstats -r ${x} | sed -n 3p | awk '{print \$NF}')"
    			if [[ ${count} -eq 0 ]]
    			then
    				echo -e " > ${DB_OUTDIR}/stats/${PROJECT_ID}_singlePacBioLoFi.stats"
    			else
    				echo -e " >> ${DB_OUTDIR}/stats/${PROJECT_ID}_singlePacBioLoFi.stats"
    			fi
        		count=$((count+1))	
        	fi 
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
    	
    	x=${DB_OUTDIR}/all/${PROJECT_ID}_Z_LoFi_ALL.db
    	if [[ -f ${x} ]]
        then
        	### All reads
        	echo -n "echo \$(${DAZZLER_PATH}/bin/DBsplit -x0 -a -f -s${DBSPLIT_SIZE} ${x})"
        	echo -n " all"
        	echo -n " all"
        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 4p | awk '{print \$1}' | tr -d ,)"
        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 7p | awk '{print \$1}' | tr -d ,)"
        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 8p | awk '{print \$1}' | tr -d ,)"
        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 10p | awk '{print \$3\" \"\$4\" \"\$5\" \"\$6}' | tr -d ')(ACGT')"
        	echo -e " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 15p | awk '{print \$NF}') > ${DB_OUTDIR}/stats/${PROJECT_ID}_allPacBioLoFi.stats"
        	### Longest reads
        	for y in 1000 2000 3000 4000 5000 6000
        	do 
        		echo -n "echo \$(${DAZZLER_PATH}/bin/DBsplit -x${y} -f -s${DBSPLIT_SIZE} ${x})"
	        	echo -n " ${y}"
	        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 2p | awk '{print \$7}' | tr -d ,)"
	        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 4p | awk '{print \$1}' | tr -d ,)"
	        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 7p | awk '{print \$1}' | tr -d ,)"
	        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 8p | awk '{print \$1}' | tr -d ,)"
	        	echo -n " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 10p | awk '{print \$3\" \"\$4\" \"\$5\" \"\$6}' | tr -d ')(ACGT')"
	        	echo -e " \$(${DAZZLER_PATH}/bin/DBstats ${x} | sed -n 15p | awk '{print \$NF}') >> ${DB_OUTDIR}/stats/${PROJECT_ID}_allPacBioLoFi.stats"		
        	done        			
    	fi>> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.plan
    	
    	echo "MARVEL DBstats $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.version        
		
		## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${sName}
		setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineID}.slurmPara
    	
    fi        
#type-1 [10x - de novo] [1-1]: 01_supernova	
elif [[ ${pipelineTypeID} -eq 1 ]]
then 
	### 01_supernova
    if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls qc_01_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        ## check if 10x data is available
        if [[ -n ${TENX_PATH} && -d "${TENX_PATH}" ]]
        then
        	## we have to trim off the 10x adapter
        	
        	numR1Files=0
			for x in ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR1Files=$((${numR1Files}+1))	
				fi
			done
			
			if [[ ${numR1Files} -eq 0 ]]
	        then
	        	(>&2 echo "ERROR - cannot read 10x R1 files with following pattern: ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz")
	        	exit 1
	   		fi
	   		
	   		numR2Files=0
			for x in ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR2Files=$((${numR2Files}+1))	
				fi
			done
			
			if [[ ${numR2Files} -eq 0 ]]
	        then
	        	(>&2 echo "ERROR - cannot read 10x R2 files with following pattern: ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz")
	        	exit 1
	   		fi
	   		
	   		if [[ ${numR1Files} -ne ${numR2Files} ]]
	        then
	        	(>&2 echo "ERROR - 10x R1 files ${numR1Files} does not match R2 files ${numR2Files}")
	        	exit 1
	   		fi	   		
	   		
	   		if [[ -d 10x_${PROJECT_ID}_supernova ]]
	   		then 
	   			echo "mv 10x_${PROJECT_ID}_supernova 10x_${PROJECT_ID}_supernova_$(date '+%Y-%m-%d_%H-%M-%S')"	   			
	   		fi
	   		
	   		# set default minimum fasta record size
	   		MINSIZE=500
	   		
	   		echo "${SUPERNOVA_PATH}/supernova run --id=10x_${PROJECT_ID}_supernova --sample ${PROJECT_ID} --fastqs=${TENX_PATH} --maxreads='all'"
	   		echo "${SUPERNOVA_PATH}/supernova mkoutput --asmdir=10x_${PROJECT_ID}_supernova/outs/assembly --outprefix=10x_${PROJECT_ID}_supernova_megabubbles --style=megabubbles --minsize=${MINSIZE}"
	   		echo "${SUPERNOVA_PATH}/supernova mkoutput --asmdir=10x_${PROJECT_ID}_supernova/outs/assembly --outprefix=10x_${PROJECT_ID}_supernova_pseudohap --style=pseudohap --minsize=${MINSIZE}"
	   		echo "${SUPERNOVA_PATH}/supernova mkoutput --asmdir=10x_${PROJECT_ID}_supernova/outs/assembly --outprefix=10x_${PROJECT_ID}_supernova_pseudohap2 --style=pseudohap2 --minsize=${MINSIZE}"
	   			   					 
		fi > qc_01_supernova_single_${RAW_DB%.db}.${id}.plan
        
        echo "$(${SUPERNOVA_PATH}/supernova run --version | head -n1)" > qc_01_supernova_single_${RAW_DB%.db}.${id}.version
    fi		
#type-2 [10x|HiC - kmer-Gsize estimate] [1-1]: 01_genomescope
elif [[ ${pipelineTypeID} -eq 2 ]]
then  
	### 01_genomescope
    if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls qc_01_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
    	longrangerOut="10x_${PROJECT_ID}_longrangerBasic/outs/barcoded.fastq.gz"
        
        if [[ ! -f ${longrangerOut} ]]
        then 
        	(>&2 echo "ERROR - longranger 10x data is not present at: ${longrangerOut}! Run longranger basic on 10x reads first!")
	        exit 1
    	fi
        
    	setJellyfishOptions count
    	echo "mkdir -p genomescope"  > qc_01_genomescope_single_${RAW_DB%.db}.${id}.plan
        echo "${JELLYFISH_PATH}/jellyfish count ${JELLYFISH_OPT} <(gunzip -c ${longrangerOut}) -o genomescope/${PROJECT_ID}.jf" >> qc_01_genomescope_single_${RAW_DB%.db}.${id}.plan
        setJellyfishOptions histo
        echo "${JELLYFISH_PATH}/jellyfish histo ${JELLYFISH_OPT} genomescope/${PROJECT_ID}.jf > genomescope/${PROJECT_ID}.histo" >> qc_01_genomescope_single_${RAW_DB%.db}.${id}.plan
        setGenomeScopeOptions
        echo "Rscript ${GENOMESCOPE_PATH}/genomescope.R genomescope/${PROJECT_ID}.histo ${RAW_QC_GENOMESCOPE_KMER} 150 genomescope ${RAW_QC_GENOMESCOPE_KMERMAX}" >> qc_01_genomescope_single_${RAW_DB%.db}.${id}.plan
        
        echo "jellyfish count $(${JELLYFISH_PATH}/jellyfish count --version | head -n1)" > qc_01_genomescope_single_${RAW_DB%.db}.${id}.version
        echo "jellyfish histo $(${JELLYFISH_PATH}/jellyfish histo --version | head -n1)" >> qc_01_genomescope_single_${RAW_DB%.db}.${id}.version
        #TODO add genomescope version         
	fi

## mash contamination check
elif [[ ${pipelineTypeID} -eq 3 ]]
then 
    ### 01_mashPrepare
    if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls qc_01_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        doPacbio=0
        do10x=0
        doHic=0
        
        if [[ -n ${DB_PATH} && -d "${DB_PATH}" ]]
        then 
        	for x in ${DB_PATH}/*subreads.bam
        	do
        		if [[ -f $x ]]
        		then 
        			doPacbio=$((${doPacbio}+1))
        			of="pacbio/$(basename ${x%.subreads.bam})_mash.fasta.gz"
        			echo "PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/dextract -v -f -o $x | gzip > ${of}"
        		fi
        	done
		fi > qc_01_mashPrepare_block_${RAW_DB%.db}.${id}.plan
		
		if [[ -n ${TENX_PATH} && -d "${TENX_PATH}" ]]
        then
        	## we have to trim off the 10x adapter
        	
        	numR1Files=0
			for x in ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR1Files=$((${numR1Files}+1))	
				fi
			done
			
			if [[ ${numR1Files} -eq 0 ]]
	        then
	        	(>&2 echo "ERROR - cannot read 10x R1 files with following pattern: ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz")
	        	exit 1
	   		fi
	   		
	   		numR2Files=0
			for x in ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR2Files=$((${numR2Files}+1))	
				fi
			done
			
			if [[ ${numR2Files} -eq 0 ]]
	        then
	        	(>&2 echo "ERROR - cannot read 10x R2 files with following pattern: ${TENX_PATH}/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz")
	        	exit 1
	   		fi
	   		
	   		if [[ ${numR1Files} -ne ${numR2Files} ]]
	        then
	        	(>&2 echo "ERROR - 10x R1 files ${numR1Files} does not match R2 files ${numR2Files}")
	        	exit 1
	   		fi
	   		
	   		setFastpOptions
	   		
			for r1 in ${TENX_PATH}/${PROJECT_ID}_S[0-9]_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
			do
				do10x=$((${do10x}+1))
				id=$(dirname ${r1})
				f1=$(basename ${r1})
				f2=$(echo "${f1}" | sed -e "s:_R1_:_R2_:")
				o="${f1%_R1_???.fastq.gz}"											
				
				echo "${FASTP_PATH}fastp -i ${id}/${f1} -I ${id}/${f2} -f 23 -G -Q -j 10x/${o}.json -h 10x/${o}.html -w ${RAW_MASH_FASTP_THREADS} -o 10x/${f1} -O 10x/${f2}"				 
			done 
    	fi >> qc_01_mashPrepare_block_${RAW_DB%.db}.${id}.plan
    	
    	if [[ -n ${HIC_PATH} && -d "${HIC_PATH}" ]]
        then
        	numR1Files=0
			for x in ${HIC_PATH}/${PROJECT_ID}_*_R1.fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR1Files=$((${numR1Files}+1))	
				fi
			done
			
			if [[ ${numR1Files} -eq 0 ]]
	        then
	        	(>&2 echo "ERROR - cannot read HiC R1 files with following pattern: ${HIC_PATH}/${PROJECT_ID}_*_R1.fastq.gz")
	        	exit 1
	   		fi
			
			numR2Files=0
			for x in ${HIC_PATH}/${PROJECT_ID}_*_R2.fastq.gz
			do
				if [[ -f ${x} ]]
				then	
					numR2Files=$((${numR2Files}+1))	
				fi
			done
			
			if [[ ${numR2Files} -eq 0 ]]
	        then
	        	(>&2 echo "ERROR - cannot read HiC R2 files with following pattern: ${HIC_PATH}/${PROJECT_ID}_*_R2.fastq.gz")
	        	exit 1
	   		fi
	   		
	   		if [[ ${numR1Files} -ne ${numR2Files} ]]
	        then
	        	(>&2 echo "ERROR - HiC R1 files ${numR1Files} does not match R2 files ${numR2Files}")
	        	exit 1
	   		fi
	   		
	   		doHic=${numR1Files}
	   		for x in ${SC_HIC_READS}/${PROJECT_ID}_*_R[12].fastq.gz
			do
				echo "ln -s -r -f ${x} hic/"  
			done 
    	fi >> qc_01_mashPrepare_block_${RAW_DB%.db}.${id}.plan
    	
    	if [[ ${doPacbio} -gt 0 ]]
    	then 
    		mkdir -p pacbio	
    	fi
    	
    	if [[ ${do10x} -gt 0 ]]
    	then 
    		mkdir -p 10x	
    	fi
    	
    	if [[ ${doHic} -gt 0 ]]
    	then 
    		mkdir -p hic	
    	fi 
    ### 02_mashSketch
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls qc_02_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
    	# check which subdirs are present and contain files
    	# pacbio
    	if [[ -n ${DB_PATH} && -d "${DB_PATH}" && -d pacbio ]]
    	then 
    		for x in pacbio/*_mash.fasta.gz
    		do
    			if [[ -f ${x} ]]
    			then 
    				echo "${CONDA_BASE_ENV} && mash sketch -k 21 -s 10000 -r -m 1 -o ${x%.fasta.gz}.msh ${x} && conda deactivate"
    			fi	
    		done	
		fi > qc_02_mashSketch_block_${RAW_DB%.db}.${id}.plan
    
        # 10x
        if [[ -n ${TENX_PATH} && -d "${TENX_PATH}" && -d 10x ]]
    	then 
    		for x in 10x/${PROJECT_ID}_S*_L[0-9][0-9][0-9]_R1_[0-9][0-9][0-9].fastq.gz
    		do
    			echo "${CONDA_BASE_ENV} && zcat ${x} $(echo ${x} | sed -e "s:_R1_:_R2_:") | mash sketch -k 21 -s 10000 -r -m 2 -o $(echo ${x%.fastq.gz}.msh | sed -e "s:_R1::") - && conda deactivate"
    		done
    	fi >> qc_02_mashSketch_block_${RAW_DB%.db}.${id}.plan
    	
    	# hic
    	if [[ -n ${HIC_PATH} && -d "${HIC_PATH}" && -d hic ]]
    	then
    		for x in hic/${PROJECT_ID}_*_R1.fastq.gz
			do
				echo "${CONDA_BASE_ENV} && zcat ${x} ${x%_R1.fastq.gz}_R2.fastq.gz | mash sketch -k 21 -s 10000 -r -m 2 -o ${x%_R1.fastq.gz}.msh - && conda deactivate"
			done    		
    	fi >> qc_02_mashSketch_block_${RAW_DB%.db}.${id}.plan
    	
    	echo "mash $(${CONDA_BASE_ENV} && mash --version && conda deactivate)" > qc_02_mashSketch_block_${RAW_DB%.db}.${id}.version
    ### 03_mashCombine
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
    	### clean up plans 
        for x in $(ls qc_03_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        if [[ -d pacbio ]]
        then 
        	ls pacbio/*.msh > ${PROJECT_ID}_mash.files
    	fi
    	
    	if [[ -d 10x ]]
        then 
        	ls 10x/*.msh >> ${PROJECT_ID}_mash.files
    	fi 
    	
    	if [[ -d hic ]]
        then 
        	ls hic/*.msh >> ${PROJECT_ID}_mash.files
    	fi
    	        
        echo "${CONDA_BASE_ENV} && mash paste -l ${PROJECT_ID}.msh ${PROJECT_ID}_mash.files && conda deactivate" > qc_03_mashCombine_single_${RAW_DB%.db}.${id}.plan
        echo "${CONDA_BASE_ENV} && mash dist -t ${PROJECT_ID}.msh ${PROJECT_ID}.msh > ${PROJECT_ID}.tbl && conda deactivate" >> qc_03_mashCombine_single_${RAW_DB%.db}.${id}.plan
        echo "mash $(${CONDA_BASE_ENV} && mash --version && conda deactivate)" > qc_03_mashCombine_single_${RAW_DB%.db}.${id}.version
	### 04_mashPlot
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
    	### clean up plans 
        for x in $(ls qc_04_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
    
    	echo "head -n 1 ${PROJECT_ID}.tbl |awk '{for (i=2; i <=NF; i++) print \$i}' |awk -F "/" '{print \$NF}' |sed s/.subreads.fast[aq].gz//g |sed s/.fast[aq].gz//g |sed s/.fast[aq]//g > ${PROJECT_ID}.key" > qc_04_mashPlot_single_${RAW_DB%.db}.${id}.plan
    	echo "Rscript ${MARVEL_PATH}/scripts/mashPlot.R ${PROJECT_ID}" >> qc_04_mashPlot_single_${RAW_DB%.db}.${id}.plan
    	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > qc_04_mashPlot_single_${RAW_DB%.db}.${id}.version
    ### 05_mashScreen
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
    	### clean up plans 
        for x in $(ls qc_05_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        if [[ -z ${MASH_REF_GENOMES} || ! -f ${MASH_REF_GENOMES} ]]
        then
        	(>&2 echo "[ERROR] mash pipeline step 05 mashScreen failed. Set variable MASH_REF_GENOMES to an appropriate reference genome msh file")
        	exit 1	
    	fi
        	
        mkdir -p screen 
        
        threads=24
		if [[ "${SLURM_PARTITION}" == "gpu" ]]
		then 
			threads=40
		elif [[ "${SLURM_PARTITION}" == "bigmem" ]]
		then 
			threads=48
		fi
        
        for x in pacbio/*.fasta.gz 10x/*.fastq.gz hic/*.fastq.gz
        do
        	if [[ -f ${x} ]]
        	then
        		out=screen/$(basename ${x%.fast[aq].gz}).conta
        		echo "${CONDA_BASE_ENV} && mash screen -p ${threads} -w ${MASH_REF_GENOMES} ${x} > ${out} && conda deactivate"
        	fi
		done > qc_05_mashScreen_block_${RAW_DB%.db}.${id}.plan   
		echo "mash $(${CONDA_BASE_ENV} && mash --version && conda deactivate)" > qc_05_mashScreen_block_${RAW_DB%.db}.${id}.version     
    fi  
elif [[ ${pipelineTypeID} -eq 4 ]]
then 
	### 01_QVprepareInput
	if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls qc_01_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
                if [[ ! -f "${QV_REFFASTA}" ]]
        then
        	(>&2 echo "ERROR - set QV_REFFASTA to reference fasta file")
        	exit 1
   		fi
   		
   		echo "if [[ -d ${QV_OUTDIR}_${QV_RUNID} ]]; then mv ${QV_OUTDIR}_${QV_RUNID} ${QV_RUNID}/qv_${QV_RUNID}_$(date '+%Y-%m-%d_%H-%M-%S'); fi && mkdir -p \"${QV_OUTDIR}_${QV_RUNID}\"" > qc_01_QVprepareInput_single_${RAW_DB}.${id}.plan
		echo "mkdir -p ${QV_OUTDIR}_${QV_RUNID}/bams" >> qc_01_QVprepareInput_single_${RAW_DB}.${id}.plan
		echo "mkdir -p ${QV_OUTDIR}_${QV_RUNID}/ref" >> qc_01_QVprepareInput_single_${RAW_DB}.${id}.plan
		echo "mkdir -p ${QV_OUTDIR}_${QV_RUNID}/freebayes" >> qc_01_QVprepareInput_single_${RAW_DB}.${id}.plan		
		# get rid of any colon's, as those will cause a crash of longranger		
		echo "sed -e \"s/:/-/g\" ${QV_REFFASTA} > ${QV_OUTDIR}_${QV_RUNID}/ref/$(basename ${QV_REFFASTA})" >> qc_01_QVprepareInput_single_${RAW_DB}.${id}.plan		                
    ### 02_QVlongrangerAlign
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls qc_02_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        REFNAME=$(basename ${QV_REFFASTA})
        
        if [[ ! -f "${QV_OUTDIR}_${QV_RUNID}/ref/${REFNAME}" ]]
        then
    		(>&2 echo "ERROR - cannot find reference fasta file \"${REFNAME}\" in dir \"${QV_OUTDIR}_${QV_RUNID}/ref\"")
        	exit 1
   		fi
        
		if [[ ! -d ${TENX_PATH} ]]
        then 
        	(>&2 echo "ERROR - cannot find 10x reads. Variable TENX_PATH has to be set to a directoty containing 10x reads.")
        	exit 1
    	fi
    	
    	slurmOpt=""
    	if [[ ${SLURM_PARTITION} == "gpu" ]]
    	then
    		slurmOpt="--jobmode=slurmGPU --localcores=38 --localmem=128 --maxjobs=1000 --jobinterval=5000 --disable-ui --nopreflight"
    	elif [[ ${SLURM_PARTITION} == "long" ||  ${SLURM_PARTITION} == "batch" ]]
    	then
    		slurmOpt="--jobmode=slurmBATCH --localcores=24 --localmem=128 --maxjobs=1000 --jobinterval=5000 --disable-ui --nopreflight"
    	elif [[ ${SLURM_PARTITION} == "bigmem" ]]
    	then
    		slurmOpt="--jobmode=slurmBIGMEM --localcores=48 --localmem=128 --maxjobs=1000 --jobinterval=5000 --disable-ui --nopreflight"
    	else
    		(>&2 echo "ERROR - SLUM PARTITION: ${SLURM_PARTITION} not supported!")
        	exit 1
    	fi
    	   
        if [[ ! -d ${QV_OUTDIR}_${QV_RUNID}/ref/refdata-${REFNAME%.fasta} ]]
        then
        	echo "cd ${QV_OUTDIR}_${QV_RUNID}/ref && ${LONGRANGER_PATH}/longranger mkref ${REFNAME} && cd ../../ " 
        	echo "cd ${QV_OUTDIR}_${QV_RUNID}/bams && ${LONGRANGER_PATH}/longranger align --id=10x_${PROJECT_ID}_longrangerAlign --fastqs=${TENX_PATH} --sample=${PROJECT_ID} --reference=../ref/refdata-${REFNAME%.fasta} ${slurmOpt} && cd ../../"
    	else 
    		(>&2 echo "[WARNING] Using previously created reference file ${QV_OUTDIR}_${QV_RUNID}/ref/refdata-${REFNAME}. Please remove that folder to rerun longranger mkref" )
    		echo "cd ${QV_OUTDIR}_${QV_RUNID}/bams && ${LONGRANGER_PATH}/longranger align --id=10x_${PROJECT_ID}_longrangerAlign --fastqs=${TENX_PATH} --sample=${PROJECT_ID} --reference=../ref/refdata-${REFNAME%.fasta} ${slurmOpt} && cd ../../"
    	fi > qc_02_QVlongrangerAlign_single_${RAW_DB}.${id}.plan                
        
        echo "$(${LONGRANGER_PATH}/longranger mkref --version)" > qc_02_QVlongrangerAlign_single_${RAW_DB}.${id}.version
        echo "$(${LONGRANGER_PATH}/longranger align --version)" >> qc_02_QVlongrangerAlign_single_${RAW_DB}.${id}.version
    ### 03_QVcoverage
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls qc_03_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        REFNAME=$(basename ${QV_REFFASTA})
        
        if [[ ! -f "${QV_OUTDIR}_${QV_RUNID}/ref/${REFNAME}" ]]
        then
    		(>&2 echo "ERROR - cannot find reference fasta file \"${REFNAME}\" in dir \"${QV_OUTDIR}_${QV_RUNID}/ref\"")
        	exit 1
   		fi
   		
   		if [[ ! -d "${QV_OUTDIR}_${QV_RUNID}/bams" ]]
        then
        	(>&2 echo "ERROR - cannot access directory ${QV_OUTDIR}_${QV_RUNID}/bams!")
        	exit 1
   		fi
        
        outdir="${QV_OUTDIR}_${QV_RUNID}/"
   		if [[ ! -d "${outdir}" ]]
        then
        	(>&2 echo "ERROR - cannot access directory ${outdir}!")
        	exit 1
   		fi
   	
   	
   		ref=${QV_OUTDIR}_${QV_RUNID}/ref/refdata-${REFNAME%.fasta}/fasta/genome.fa
   		
   		if [[ ! -f "${ref}.fai" ]]
        then
        	(>&2 echo "ERROR - cannot reference fasta index file ${ref}.fai!")
        	exit 1
   		fi
   		
   		bam=${QV_OUTDIR}_${QV_RUNID}/bams/10x_${PROJECT_ID}_longrangerAlign/outs/possorted_bam.bam
   		if [[ ! -f ${bam} ]]
   		then 
   		(>&2 echo "ERROR - cannot find longranger bam file: ${bam}!")
        	exit 1
   		fi 
   		
   		echo "samtools view -F 0x100 -u $bam | bedtools genomecov -ibam - -split > ${QV_OUTDIR}_${QV_RUNID}/aligned.genomecov" > qc_03_QVcoverage_single_${RAW_DB}.${id}.plan
		echo "$(samtools --version | head -n2 | tr "\n" "-" && echo)" > qc_03_QVcoverage_single_${RAW_DB}.${id}.version        
    ### 04_QVfreebayes 
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls qc_04_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        REFNAME=$(basename ${QV_REFFASTA})
        
        if [[ ! -f "${QV_OUTDIR}_${QV_RUNID}/ref/${REFNAME}" ]]
        then
    		(>&2 echo "ERROR - cannot find reference fasta file \"${REFNAME}\" in dir \"${QV_OUTDIR}_${QV_RUNID}/ref\"")
        	exit 1
   		fi
   		
   		if [[ ! -d "${QV_OUTDIR}_${QV_RUNID}/bams" ]]
        then
        	(>&2 echo "ERROR - cannot access directory ${QV_OUTDIR}_${QV_RUNID}/bams!")
        	exit 1
   		fi
        
        outdir="${QV_OUTDIR}_${QV_RUNID}/freebayes/"
   		if [[ ! -d "${outdir}" ]]
        then
        	(>&2 echo "ERROR - cannot access directory ${outdir}!")
        	exit 1
   		fi
   	
   	
   		ref=${QV_OUTDIR}_${QV_RUNID}/ref/refdata-${REFNAME%.fasta}/fasta/genome.fa
   		
   		if [[ ! -f "${ref}.fai" ]]
        then
        	(>&2 echo "ERROR - cannot reference fasta index file ${ref}.fai!")
        	exit 1
   		fi
   		
   		bam=${QV_OUTDIR}_${QV_RUNID}/bams/10x_${PROJECT_ID}_longrangerAlign/outs/possorted_bam.bam
   		if [[ ! -f ${bam} ]]
   		then 
   			(>&2 echo "ERROR - cannot final duplicate marked bam file: ${QV_OUTDIR}_${QV_RUNID}/bams/${PROJECT_ID}_final10x.bam!")
        	exit 1
   		fi 
   		
   		echo "$(awk -v bam=${bam} -v ref=${ref} -v out=${outdir} -v condaIN="${CONDA_BASE_ENV}" '{print condaIN" && freebayes --bam "bam" --region "$1":1-"$2" -f "ref" | bcftools view --no-version -Ou -o "out$1":1-"$2".bcf && conda deactivate"}' ${ref}.fai)" > qc_04_QVfreebayes_block_${RAW_DB}.${id}.plan

		echo "freebayes $(${CONDA_BASE_ENV} && freebayes --version && conda deactivate)" > qc_04_QVfreebayes_block_${RAW_DB}.${id}.version
		echo "bcftools $(${CONDA_BASE_ENV} && bcftools --version | head -n1 | awk '{print $2}' && conda deactivate)" >> qc_04_QVfreebayes_block_${RAW_DB}.${id}.version
    ### 05_QVbcftools 
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls qc_05_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        REFNAME=$(basename ${QV_REFFASTA})
        
		ref=${QV_OUTDIR}_${QV_RUNID}/ref/refdata-${REFNAME%.fasta}/fasta/genome.fa
   		
   		if [[ ! -f "${ref}.fai" ]]
        then
        (>&2 echo "ERROR - cannot find reference fasta index file ${ref}.fai!")
        	exit 1
   		fi
   		
   		indir="${QV_OUTDIR}_${QV_RUNID}/freebayes/"
   		if [[ ! -d "${indir}" ]]
        then
        	(>&2 echo "ERROR - cannot access directory ${indir}!")
        	exit 1
   		fi
   		
   		outdir="${QV_OUTDIR}_${QV_RUNID}/"
        
    	# create list of bcf files, same order as in ref.fai
        echo "awk -v d=\"${QV_OUTDIR}_${QV_RUNID}/freebayes/\" '{print d\$1\":1-\"\$2\".bcf\"}' ${ref}.fai > ${outdir}/${PROJECT_ID}_10x_concatList.txt" > qc_05_QVbcftools_single_${RAW_DB}.${id}.plan
        echo "${CONDA_BASE_ENV} && bcftools concat -Ou -f ${outdir}/${PROJECT_ID}_10x_concatList.txt | bcftools view -Ou -e'type=\"ref\"' | bcftools norm -Ob -f $ref -o ${outdir}/${PROJECT_ID}_10x.bcf && conda deactivate" >> qc_05_QVbcftools_single_${RAW_DB}.${id}.plan
        echo "${CONDA_BASE_ENV} && bcftools index ${outdir}/${PROJECT_ID}_10x.bcf && conda deactivate" >> qc_05_QVbcftools_single_${RAW_DB}.${id}.plan
      
		echo "echo \"Num. bases affected \$(${CONDA_BASE_ENV} && bcftools view -H -i 'QUAL>1 && (GT=\"AA\" || GT=\"Aa\")' -Ov ${outdir}/${PROJECT_ID}_10x.bcf | awk -F \"\\t\" '{print \$4\"\\t\"\$5}' | awk '{lenA=length(\$1); lenB=length(\$2); if (lenA < lenB ) {sum+=lenB-lenA} else if ( lenA > lenB ) { sum+=lenA-lenB } else {sum+=lenA}} END {print sum}')\" > ${outdir}/${PROJECT_ID}_10x.numvar && conda deactivate" >> qc_05_QVbcftools_single_${RAW_DB}.${id}.plan
		echo "${CONDA_BASE_ENV} && bcftools view -i 'QUAL>1 && (GT=\"AA\" || GT=\"Aa\")' -Oz  ${outdir}/${PROJECT_ID}_10x.bcf > ${outdir}/${PROJECT_ID}_10x.changes.vcf.gz && conda deactivate" >> qc_05_QVbcftools_single_${RAW_DB}.${id}.plan
            
      	echo "bcftools $(${CONDA_BASE_ENV} && bcftools --version | head -n1 | awk '{print $2}' && conda deactivate)" > qc_05_QVbcftools_single_${RAW_DB}.${id}.version
        
    ### 06_QVqv
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls qc_06_*_*_${RAW_DB}.${id}.* 2> /dev/null)
        do            
            rm $x
        done
        
        REFNAME=$(basename ${QV_REFFASTA})
        
        if [[ ! -f "${QV_OUTDIR}_${QV_RUNID}/ref/${REFNAME}" ]]
        then
    		(>&2 echo "ERROR - cannot find reference fasta file \"${REFNAME}\" in dir \"${QV_OUTDIR}_${QV_RUNID}/ref\"")
        	exit 1
   		fi
   		
   		if [[ ! -d "${QV_OUTDIR}_${QV_RUNID}/bams" ]]
        then
        	(>&2 echo "ERROR - cannot access directory ${QV_OUTDIR}_${QV_RUNID}/bams!")
        	exit 1
   		fi
        
        outdir="${QV_OUTDIR}_${QV_RUNID}/"
   		if [[ ! -d "${outdir}" ]]
        then
        	(>&2 echo "ERROR - cannot access directory ${outdir}!")
        	exit 1
   		fi
   	
   	
   		ref=${QV_OUTDIR}_${QV_RUNID}/ref/refdata-${REFNAME%.fasta}/fasta/genome.fa
   		
   		if [[ ! -f "${ref}.fai" ]]
        then
        	(>&2 echo "ERROR - cannot reference fasta index file ${ref}.fai!")
        	exit 1
   		fi
   		
   		bam=${QV_OUTDIR}_${QV_RUNID}/bams/10x_${PROJECT_ID}_longrangerAlign/outs/possorted_bam.bam
   		if [[ ! -f ${bam} ]]
   		then 
   			(>&2 echo "ERROR - cannot find longranger bam file: ${bam}!")
        	exit 1
   		fi
        
        if [[ ! -f ${bam}.bai ]]
   		then 
   			(>&2 echo "ERROR - cannot find longranger bam file: ${bam}.bai!")
        	exit 1
   		fi
        
        summary=${QV_OUTDIR}_${QV_RUNID}/bams/10x_${PROJECT_ID}_longrangerAlign/outs/summary.csv
   		if [[ ! -f ${summary} ]]
   		then 
   			(>&2 echo "ERROR - cannot find longranger bam file: ${summary}!")
        	exit 1
   		fi
        
        echo "mean_cov=\$(tail -n1 ${summary} | awk -F \",\" '{printf \"%.0f\n\", \$17}')	# parse out the mean_cov from summary.csv" > qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "h_filter=\$((mean_cov*12))	# exclude any sites >12x" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "l_filter=3			# exclude any sites <3x" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "echo \"Get numbp between \$l_filter ~ \$h_filter x\" > ${QV_OUTDIR}_${QV_RUNID}/qv_${PROJECT_ID}.log" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		
		echo "awk -v l=\$l_filter -v h=\$h_filter '{if (\$1==\"genome\" && \$2>l && \$2<h) {numbp += \$3}} END {print numbp}' ${outdir}/aligned.genomecov > ${outdir}/${PROJECT_ID}.numbp" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "NUM_BP=\$(cat ${outdir}/${PROJECT_ID}.numbp)" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "${CONDA_BASE_ENV} && bcftools view -H -i 'QUAL>1 && (GT=\"AA\" || GT=\"Aa\") && INFO/DP>5 && (FORMAT/AD[:1]) / (FORMAT/AD[:1]+FORMAT/AD[:0]) > 0.5' -Ov ${outdir}/${PROJECT_ID}_10x.changes.vcf.gz | awk -F \"\\t\" '{print \$4\"\\t\"\$5}' | awk '{lenA=length(\$1); lenB=length(\$2); if (lenA < lenB ) {sum+=lenB-lenA} else if ( lenA > lenB ) { sum+=lenA-lenB } else {sum+=lenA}} END {print sum}' > ${outdir}/${PROJECT_ID}.numvar && conda deactivate" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "NUM_VAR=\$(cat ${outdir}/${PROJECT_ID}.numvar)" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "echo \"Total num. bases subject to change: \$NUM_VAR\" >> ${outdir}/qv_${PROJECT_ID}.log" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "QV=\$(echo "\$NUM_VAR \$NUM_BP" | awk '{print (-10*log(\$1/\$2)/log(10))}')"  >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "echo \$QV > ${outdir}/${PROJECT_ID}.qv" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		echo "echo \"QV of this genome ${PROJECT_ID}: \$QV\"" >> qc_06_QVqv_single_${RAW_DB}.${id}.plan
		
		echo "bcftools $(${CONDA_BASE_ENV} && bcftools --version | head -n1 | awk '{print $2}' && conda deactivate)" > qc_06_QVqv_single_${RAW_DB}.${id}.version
fi

exit 0