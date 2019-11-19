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
	### available options: window threshold minLen bias
	DBDUST_OPT=""
	
	para=$(getJobPara ${pipelineName} DBdust window)
	if [[ "x${para}" != "x" && $(isNumber ${para}) ]]
	then 
		DBDUST_OPT="${DBDUST_OPT} -w${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} DBdust threshold)
	if [[ "x${para}" != "x" && $(isFloatNumber ${para}) ]]
	then 
		DBDUST_OPT="${DBDUST_OPT} -t${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} DBdust minLen)
	if [[ "x${para}" != "x" && $(isNumber ${para}) ]]
	then 
		DBDUST_OPT="${DBDUST_OPT} -t${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} DBdust bias)
	if [[ "x${para}" != "x" && $(isNumber ${para}) && ${para} -gt 0 ]]
	then 
		DBDUST_OPT="${DBDUST_OPT} -b"	
	fi
}

function setCatrackOptions()
{
	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	getSlurmRunParameter ${pipelineStepName}
	
	### current rmask JobPara can overrule general SLURM_RUN_PARA
	para=$(getJobPara ${pipelineName} Catrack partition)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[0]=${para}			
	fi
	para=$(getJobPara ${pipelineName} Catrack mem)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[2]=${para}				
	fi
	
	
	### available options: verbose delete force
	CATRACK_OPT=""
	
	para=$(getJobPara ${pipelineName} Catrack verbose)
	if [[ "x${para}" != "x" && $(isNumber ${para}) && ${para} -gt 0 ]]
	then 
		CATRACK_OPT="${CATRACK_OPT} -v"	
	fi
	
	para=$(getJobPara ${pipelineName} Catrack delete)
	if [[ "x${para}" != "x" && $(isNumber ${para}) && ${para} -gt 0 ]]
	then 
		CATRACK_OPT="${CATRACK_OPT} -d"	
	fi
	
	para=$(getJobPara ${pipelineName} Catrack force)
	if [[ "x${para}" != "x" && $(isNumber ${para}) && ${para} -gt 0 ]]
	then 
		CATRACK_OPT="${CATRACK_OPT} -f"	
	fi
}

function setDatanderOptions()
{
	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	getSlurmRunParameter ${pipelineStepName}
	
	### current rmask JobPara can overrule general SLURM_RUN_PARA
	para=$(getJobPara ${pipelineName} datander partition)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[0]=${para}			
	fi
	para=$(getJobPara ${pipelineName} datander mem)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[2]=${para}				
	fi
	
	### available options: verbose kmer window hits threads tmpDir err minLen trace
	DATANDER_OPT=""
	
	para=$(getJobPara ${pipelineName} datander verbose)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DATANDER_OPT="${DATANDER_OPT} -v"	
	fi
	
	para=$(getJobPara ${pipelineName} datander kmer)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DATANDER_OPT="${DATANDER_OPT} -k${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} datander window)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DATANDER_OPT="${DATANDER_OPT} -w${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} datander hits)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DATANDER_OPT="${DATANDER_OPT} -h${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} datander threads)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DATANDER_OPT="${DATANDER_OPT} -T${para}"	
		SLURM_RUN_PARA[1]=${para}
	fi
	
	para=$(getJobPara ${pipelineName} datander err)
	if $(isFloatNumber ${para})
	then 
		DATANDER_OPT="${DATANDER_OPT} -e${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} datander tmpDir)
	if [[ "x${para}" != "x" ]]
	then 
		DATANDER_OPT="${DATANDER_OPT} -P${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} datander minLen)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DATANDER_OPT="${DATANDER_OPT} -l${para}"	
	fi
	
	para=$(getJobPara ${pipelineName} datander trace)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DATANDER_OPT="${DATANDER_OPT} -s${para}"	
	fi	
}

function setTANmaskOptions()
{
	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	getSlurmRunParameter ${pipelineStepName}
	   	        
    ### current rmask JobPara can overrule general SLURM_RUN_PARA
	para=$(getJobPara ${pipelineName} TANmask partition)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[0]=${para}			
	fi
	para=$(getJobPara ${pipelineName} TANmask mem)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[2]=${para}				
	fi
	
	### available options: verbose minLen 
	TANMASK_OPT=""
	
	para=$(getJobPara ${pipelineName} TANmask verbose)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		TANMASK_OPT="${TANMASK_OPT} -v"	
	fi
	para=$(getJobPara ${pipelineName} TANmask minLen)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		TANMASK_OPT="${TANMASK_OPT} -n${para}"	
	fi	
}

function setDaligerOptions()
{
	### find and set daligner options 
    getSlurmRunParameter ${pipelineStepName}
    
    ### current rmask JobPara can overrule general SLURM_RUN_PARA
	para=$(getJobPara ${pipelineName} daligner partition)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[0]=${para}			
	fi
	para=$(getJobPara ${pipelineName} daligner threads)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[1]=${para}			
	fi
	para=$(getJobPara ${pipelineName} daligner mem)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[2]=${para}				
	fi
	
	### available options: verbose identity kmer err minLen	mem	hits trace mask
	DALIGNER_OPT=""
	
	para=$(getJobPara ${pipelineName} daligner verbose)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -v"	
	fi
    para=$(getJobPara ${pipelineName} daligner identity)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -I"	
	fi
	para=$(getJobPara ${pipelineName} daligner kmer)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -k${para}"	
	fi
    para=$(getJobPara ${pipelineName} daligner err)
	if $(isFloatNumber ${para})
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -e${para}"	
	fi
	para=$(getJobPara ${pipelineName} daligner minLen)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -l${para}"	
	fi
	para=$(getJobPara ${pipelineName} daligner mem)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -M$((${para}/1024))"				
	fi
	para=$(getJobPara ${pipelineName} daligner hits)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -h${para}"				
	fi
	para=$(getJobPara ${pipelineName} daligner trace)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -t${para}"				
	fi
	para=$(getJobPara ${pipelineName} daligner threads)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		DALIGNER_OPT="${DALIGNER_OPT} -T${para}"					
	fi
	
	para=$(getJobPara ${pipelineName} daligner mask)
	for x in ${para}
	do
		if [[ "$x" =~ ^LArepeatJobPara_[0-9] ]]; 
		then
			blocks_cov=($(getJobPara ${pipelineName} LArepeat blocks_cov))
			id=$(echo $x | sed -e "s:LArepeatJobPara_::")
			m=rep_B$(echo ${blocks_cov[${id}]} | sed -e "s:_:C:")
			DALIGNER_OPT="${DALIGNER_OPT} -m${m}"
		else
			DALIGNER_OPT="${DALIGNER_OPT} -m${x}"
		fi
	done	
	
	## set block comparisons
	REPMASK_BLOCKCMP=()
	REPMASK_REPEAT_COV=()
	
	blocks_cov=($(getJobPara ${pipelineName} LArepeat blocks_cov))
	local c=0
	for x in ${blocks_cov}
	do
		REPMASK_BLOCKCMP[$c]=$(echo ${x} | awk -F _ '{print $1}')
		REPMASK_REPEAT_COV[$c]=$(echo ${x} | awk -F _ '{print $2}')
		c=$((c+1))
	done	 
}

function setREPmaskOptions()
{
    idx=$1
    
    ## set variable REPMASK_BLOCKCMP and REPMASK_REPEAT_COV via setDaligerOptions 
	setDaligerOptions
    
    ### find and set daligner options 
    getSlurmRunParameter ${pipelineStepName}
    
    ### current rmask JobPara can overrule general SLURM_RUN_PARA
	para=$(getJobPara ${pipelineName} REPmask partition)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[0]=${para}			
	fi
	para=$(getJobPara ${pipelineName} REPmask threads)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[1]=${para}			
	fi
	para=$(getJobPara ${pipelineName} REPmask mem)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[2]=${para}				
	fi
	
	### available options: verbose repCov
	REPMASK_OPT=""
	
	para=$(getJobPara ${pipelineName} REPmask verbose)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		REPMASK_OPT="${REPMASK_OPT} -v"					
	fi
	para=$(getJobPara ${pipelineName} REPmask repCov)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		REPMASK_OPT="${REPMASK_OPT} -c${para}"					
	fi
	
	REPEAT_TRACK=rep_B${REPMASK_BLOCKCMP[${idx}]}C${REPMASK_LAREPEAT_COV[${idx}]}
	
	REPMASK_OPT="${REPMASK_OPT} -n${REPEAT_TRACK}"
}

function setLArepeatOptions()
{
    idx=$1
    
    ## set variable REPMASK_BLOCKCMP and REPMASK_REPEAT_COV via setDaligerOptions 
	setDaligerOptions
    
    ### find and set daligner options 
    getSlurmRunParameter ${pipelineStepName}
    
    ### current rmask JobPara can overrule general SLURM_RUN_PARA
	para=$(getJobPara ${pipelineName} LArepeat partition)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[0]=${para}			
	fi
	para=$(getJobPara ${pipelineName} LArepeat threads)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[1]=${para}			
	fi
	para=$(getJobPara ${pipelineName} LArepeat mem)
	if [[ "x${para}" != "x" ]]
	then 
		SLURM_RUN_PARA[2]=${para}				
	fi
	
	### available options: hghCov lowCov minLen identity ecov maxCov
	LAREPEAT_OPT=""
	
	para=$(getJobPara ${pipelineName} LArepeat hghCov)
	if $(isFloatNumber ${para})
	then 
		LAREPEAT_OPT="${LAREPEAT_OPT} -h${para}"	
	fi
	para=$(getJobPara ${pipelineName} LArepeat lowCov)
	if $(isFloatNumber ${para})
	then 
		LAREPEAT_OPT="${LAREPEAT_OPT} -l${para}"	
	fi
	para=$(getJobPara ${pipelineName} LArepeat minLen)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		LAREPEAT_OPT="${LAREPEAT_OPT} -o${para}"	
	fi
	para=$(getJobPara ${pipelineName} LArepeat identity)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		LAREPEAT_OPT="${LAREPEAT_OPT} -I"	
	fi
	para=$(getJobPara ${pipelineName} LArepeat ecov)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		LAREPEAT_OPT="${LAREPEAT_OPT} -c${para}"
		
		hghCov=$(getJobPara ${pipelineName} LArepeat hghCov)
		if $(isFloatNumber ${hghCov})
		then 
			hghCov=$((${hghCov%.*}+1))
		else 
			hghCov=3
		fi
		
		if [[ $((para*hghCov)) -gt 100 ]]
		then 
			LAREPEAT_OPT="${LAREPEAT_OPT} -M$((para*hghCov))"
		fi 
	fi
	para=$(getJobPara ${pipelineName} LArepeat maxCov)
	if $(isNumber ${para}) && [ ${para} -gt 0 ]
	then 
		LAREPEAT_OPT="${LAREPEAT_OPT} -M${para}"
	fi
	
	REPEAT_TRACK=rep_B${REPMASK_BLOCKCMP[${idx}]}C${REPMASK_LAREPEAT_COV[${idx}]}
	
	LAREPEAT_OPT="${LAREPEAT_OPT} -t${REPEAT_TRACK}"
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
		nblocks=$(getNumOfDbBlocks ../${INIT_DIR}/pacbio/lofi/db/run/${PROJECT_ID}_M_LoFi.db)			
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
		nblocks=$(getNumOfDbBlocks ../${INIT_DIR}/pacbio/hifi/db/run/${PROJECT_ID}_M_HiFi.db)
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
                        
        echo -e "if [[ -d ${REPMASK_OUTDIR} ]]; then mv ${REPMASK_OUTDIR} ${REPMASK_OUTDIR}_\$(stat --format='%Y' ${REPMASK_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi"
       	if [[ "${PACBIO_TYPE}" == "LoFi" ]]
       	then
       		echo -e "mkdir ${REPMASK_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.bps ${REPMASK_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.bps ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_Z}.db ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_M}.db ${REPMASK_OUTDIR}/"
       		echo -e "cd ${myCWD}"
        else
       		echo -e "mkdir ${REPMASK_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.bps ${REPMASK_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.bps ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_Z}.db ${REPMASK_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_M}.db ${REPMASK_OUTDIR}/"
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
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/DBdust${DBDUST_OPT} ${DB_M%.db}.${x} && cd ${myCWD}"
            echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/DBdust${DBDUST_OPT} ${DB_Z%.db}.${x} && cd ${myCWD}"
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
        echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/Catrack${CATRACK_OPT} ${DB_M%.db} dust && cp .${DB_M%.db}.dust.anno .${DB_M%.db}.dust.data ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${CATRACK_OPT} ${DB_Z%.db} dust && cp .${DB_Z%.db}.dust.anno .${DB_Z%.db}.dust.data ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        
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
            echo "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/datander${DATANDER_OPT} ${DB_Z%.db}.${x} && cd ${myCWD}"
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	
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
            echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/TANmask${TANMASK_OPT} ${DB_Z%.db} TAN.${DB_Z%.db}.${x}.las && cd ${myCWD}" 
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
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
        setCatrackOptions
        
        ### create Catrack command
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${CATRACK_OPT} ${DB_Z%.db} tan && cp .${DB_Z%.db}.tan.anno .${DB_Z%.db}.tan.data ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${LASTOOLS_PATH}/bin/viewmasks ${DB_Z%.db} tan > ${DB_Z%.db}.tan.txt && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
      	echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/txt2track -m ${DB_M%.db} ${DB_Z%.db}.tan.txt tan && cp .${DB_M%.db}.tan.a2 .${DB_M%.db}.tan.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
      	echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKcombine ${DB_M%.db} tan_dust tan dust && cp .${DB_M%.db}.tan_dust.a2 .${DB_M%.db}.tan_dust.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan 
        
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
		setDaligerOptions
		
		## create job directories before daligner runs
		for x in $(seq 1 ${nblocks})
		do
			if [[ -d ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[0]}C${REPMASK_REPEAT_COV[0]} ]]
			then
				mv ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[0]}C${REPMASK_REPEAT_COV[0]} ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[0]}C${REPMASK_REPEAT_COV[0]}_$(stat --format='%Y' ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[0]}C${REPMASK_REPEAT_COV[0]} | date '+%Y-%m-%d_%H-%M-%S')	
			fi
			mkdir -p ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[0]}C${REPMASK_REPEAT_COV[0]}
		done

        bcmp=${REPMASK_BLOCKCMP[0]}
		
        ### create daligner commands
        n=${bcmp}
        for x in $(seq 1 ${nblocks})
        do
            if [[ $((x%bcmp)) -eq 1 || ${bcmp} -eq 1 ]]
            then 
              n=${bcmp}
            fi 
            echo -n "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DALIGNER_OPT} ${DB_Z%.db}.${x}"
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
                echo -n " && mv ${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las mask_${x}_B${REPMASK_BLOCKCMP[0]}C${REPMASK_LAREPEAT_COV[0]}"
            done 
            
            n=$((${n}-1))

            echo " && cd ${myCWD}"
   		done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
   		
   		setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
		
		## set variable REPMASK_BLOCKCMP and REPMASK_REPEAT_COV via setDaligerOptions 
		setDaligerOptions
		
        ### create LAmerge commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge -n 255 ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[0]}C${REPMASK_REPEAT_COV[0]}.las mask_${x}_B${REPMASK_BLOCKCMP[0]}C${REPMASK_REPEAT_COV[0]} && cd ${myCWD}"            
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
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
        setREPmaskOptions 0
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[0]}C${REPMASK_LAREPEAT_COV[0]}.las && cd ${myCWD}/" 
            echo "cd ${REPMASK_OUTDIR} && ln -s -f ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[0]}C${REPMASK_LAREPEAT_COV[0]}.las ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[0]}C${REPMASK_LAREPEAT_COV[0]}.${x}.las && ${DAZZLER_PATH}/bin/REPmask${REPMASK_OPT} ${DB_Z%.db} ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[0]}C${REPMASK_LAREPEAT_COV[0]}.${x}.las && unlink ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[0]}C${REPMASK_LAREPEAT_COV[0]}.${x}.las && cd ${myCWD}/"
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
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
        echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${REPMASK_TKMERGE_OPT} ${DB_M%.db} ${REPEAT_TRACK} && cp .${DB_M%.db}.${REPEAT_TRACK}.a2 .${DB_M%.db}.${REPEAT_TRACK}.d2 ${myCWD}/ && cd ${myCWD}/" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${REPMASK_TKMERGE_OPT} -f -v ${DB_Z%.db} ${REPEAT_TRACK} && cp .${DB_Z%.db}.${REPEAT_TRACK}.anno .${DB_Z%.db}.${REPEAT_TRACK}.data ${myCWD}/ && cd ${myCWD}/" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version    
    elif [[ ${pipelineStepIdx} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        setLArepeatOptions 0   # implictly calls setDalignerOptions, that sets variables REPMASK_BLOCKCMP and REPMASK_REPEAT_COV

		if [[ ${#REPMASK_BLOCKCMP[@]} -ne 2 || ${#REPMASK_REPEAT_COV[@]} -ne 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
        	exit 1
		fi
		
		if [[ ${REPMASK_BLOCKCMP[0]} -eq ${REPMASK_BLOCKCMP[1]} && ${REPMASK_REPEAT_COV[0]} -eq ${REPMASK_REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi

        bcmp=${REPMASK_BLOCKCMP[1]}
			
		## create job directories before daligner runs
		for x in $(seq 1 ${nblocks})
		do
			if [[ -d ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]} ]]
			then
				mv ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]} ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}_$(stat --format='%Y' ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]} | date '+%Y-%m-%d_%H-%M-%S')	
			fi
			mkdir -p ${REPMASK_OUTDIR}/mask_${x}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}	
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
				echo -n "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.@${x}"
			else
				echo -n "cd ${REPMASK_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DALIGNER_OPT} ${DB_Z%.db}.${x}"
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
            echo -n " mask_${x}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}"
            
            
			if [[ -z "${RAW_REPMASK_DALIGNER_ASYMMETRIC}" || ${RAW_REPMASK_DALIGNER_ASYMMETRIC} -ne 0 ]]
			then
				
				for y in $(seq $((x+1)) $((x+n-1)))
            	do
                	if [[ ${y} -gt ${nblocks} ]]
                	then
                    	break
                	fi
                	echo -n " && mv ${DB_Z%.db}.${y}.${DB_Z%.db}.${x}.las mask_${y}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}"
            	done
        	fi
 
            echo " && cd ${myCWD}"
            n=$((${n}-1))
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara 
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 11 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLArepeatOptions 0   # implictly calls setDalignerOptions, that sets variables REPMASK_BLOCKCMP and REPMASK_REPEAT_COV

		if [[ ${#REPMASK_BLOCKCMP[@]} -ne 2 || ${#REPMASK_REPEAT_COV[@]} -ne 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
        	exit 1
		fi
		
		if [[ ${REPMASK_BLOCKCMP[0]} -eq ${REPMASK_BLOCKCMP[1]} && ${REPMASK_REPEAT_COV[0]} -eq ${REPMASK_REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi

        ### create LAmerge commands 
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge -n 255 ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}.las mask_${x}_B${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]} && cd ${myCWD}"            
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
    	## this sets the global array variable SLURM_RUN_PARA (partition, nCores, mem, time, step, tasks)
	   	getSlurmRunParameter ${pipelineStepName}
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LAmerge  $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 12 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLArepeatOptions 1   # implictly calls setDalignerOptions, that sets variables REPMASK_BLOCKCMP and REPMASK_REPEAT_COV
		setREPmaskOptions 1

		if [[ ${#REPMASK_BLOCKCMP[@]} -ne 2 || ${#REPMASK_REPEAT_COV[@]} -ne 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
        	exit 1
		fi
		
		if [[ ${REPMASK_BLOCKCMP[0]} -eq ${REPMASK_BLOCKCMP[1]} && ${REPMASK_REPEAT_COV[0]} -eq ${REPMASK_REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi
        
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}.las && cd ${myCWD}/" 
            echo "cd ${REPMASK_OUTDIR} && ln -s -f ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}.las ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}.${x}.las && ${DAZZLER_PATH}/bin/REPmask${REPMASK_OPT} ${DB_Z%.db} ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}.${x}.las && unlink ${DB_Z%.db}.${x}.maskB${REPMASK_BLOCKCMP[1]}C${REPMASK_LAREPEAT_COV[1]}.${x}.las && cd ${myCWD}/"
    	done > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
	   	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
    elif [[ ${pipelineStepIdx} -eq 13 && ${#REPMASK_BLOCKCMP[*]} -eq 2 && ${#REPMASK_LAREPEAT_COV[*]} -eq 2 ]]
    then 
        ### clean up plans 
        for x in $(ls ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
		if [[ ${#REPMASK_BLOCKCMP[@]} -ne 2 || ${#REPMASK_REPEAT_COV[@]} -ne 2 ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV are not set with a second repeat parameter!")
			(>&2 echo "                                - You have to specify a second block and cov argument in your assembly.cfg file. e.g.: LArepeatJobPara+=(rmask blocks_cov 2_10)")
        	exit 1
		fi
		
		if [[ ${REPMASK_BLOCKCMP[0]} -eq ${REPMASK_BLOCKCMP[1]} && ${REPMASK_REPEAT_COV[0]} -eq ${REPMASK_REPEAT_COV[1]} ]]
		then 
			(>&2 echo "[ERROR] DAmarRawMaskPipeline.sh - Array variables REPMASK_BLOCKCMP and/or REPMASK_REPEAT_COV contain the same arguments for first and second repeat mask!")
        	exit 1
		fi
        
        ### find and set TKmerge options 
        setCatrackOptions
        setLArepeatOptions 1
        ### create TKmerge commands
        echo "cd ${REPMASK_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${CATRACK_OPT} ${DB_M%.db} ${REPEAT_TRACK} && cp .${DB_M%.db}.${REPEAT_TRACK}.a2 .${DB_M%.db}.${REPEAT_TRACK}.d2 ${myCWD}/ && cd ${myCWD}/" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${REPMASK_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${CATRACK_OPT} ${DB_Z%.db} ${REPEAT_TRACK} && cp .${DB_Z%.db}.${REPEAT_TRACK}.anno .${DB_Z%.db}.${REPEAT_TRACK}.data ${myCWD}/ && cd ${myCWD}/" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.plan

	   	setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_${pipelineStepIdx}_${pipelineStepName}.${pipelineRunID}.version
	fi
fi

exit 0
