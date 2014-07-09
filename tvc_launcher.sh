#!/bin/bash
# Launcher script for the TVC standalone pipeline to help speed up and simplify the processing of BAM files with 
# custom parameters.  You must provide a config file in the working directory, which will load up the parameters
# used in the pipeline
#
# 7/2/2014 - D Sims
###################################################################################################################
version="v0.5.1_070314"
script=$(basename $0)
debug=1
cwd=$(pwd)
now() { now=$(date +%c); echo -n "[$now]:"; }

# Set up logging for run to capture std TVC output to data dir start log in cwd and then move to results later
logfile="$(date +"%Y%m%d").tvc_sa.log.txt"
exec > >(tee $logfile)
exec 2>&1

# Check that we've loaded an output dir and a bam file to process.
if (( $# < 2 )); then
    echo "ERROR: Invalid number of arguments!"
    echo
    echo "USAGE: $script [options] <output_root_dir> <bam_file>"
    exit 1
fi

outdir_root=$1
input_bam=$2

# Get the sample name assuming <sample_name>_<rawlib>?.<bam>
sample_name=$(echo $(basename $input_bam) | perl -pe 's/(.*?)(_rawlib)?.bam/\1/')
outdir="$cwd/$outdir_root/${sample_name}_out"
ptrim_bam="${outdir}/${sample_name}_PTRIM.bam"

echo "$(now) TVC Standalone Pipeline starting..."

# Check to be sure there is no output directory already before we create one to prevent overwriting 
if [[ -d "$outdir" ]]; then 
    echo "WARNING: The output directory '$outdir' already exists.  Continuing will overwrite the data."
    echo -n "Continue? [y|n|rename]: "
    read overwrite
    case "$overwrite" in 
        y|Y)
            echo "Overwriting old results" 
            rm -r $outdir
            mkdir -p $outdir
            ;;
        n|N)
            echo "Exiting!" && exit 1
            ;;
        rename)
            echo -n "New dir name: "
            read new_dir 
            outdir="${outdir_root}/$new_dir"
            mkdir -p $outdir
            ;;
        *)
            echo "Not a valid choice! Exiting to be safe." && exit 1
            ;;
        esac
    else
        mkdir -p $outdir
fi


# Read in a config file and get input params
config_file="$cwd/config"
declare -A tvc_params

if [[ ! -e "$config_file" ]]; then 
    echo "ERROR: Can not find a configuration file in the current directory."
    exit 1;
fi

while read key value;
do
    if [[ ! $key =~ ^\ *# && -n $key ]]; then
        if [[ -e "$value" ]]; then
            tvc_params[$key]=$value
        else
            tvc_params[$key]="NULL"
        fi
    fi
done < $config_file

# Need to set up a TVC Root so that the rest of the scripts can be found
export TVC_BIN_DIR=${tvc_params[TVC_ROOT_DIR]}
if [[ ! -d "$TVC_BIN_DIR" ]]; then
    echo "ERROR: '$TVC_BIN_DIR' does not exist.  Check your TVC Root Path"
    exit 1
fi

# Add the rest of the params to the AA
tvc_params[SAMPLE]=$sample_name
tvc_params[OUTDIR]=$outdir
tvc_params[BAM]=$input_bam
tvc_params[TRIMBAM]=$ptrim_bam

if [[ $debug -eq 1 ]]; then
    echo "Params as passed to TVC:"
    for key in "${!tvc_params[@]}"; do
        printf "\t%-20s  => %s\n" $key ${tvc_params[$key]}
    done
    echo
fi

tvc_launch_cmd="python $TVC_BIN_DIR/variant_caller_pipeline.py    \
        --num-threads       "34"                                  \
        --parameters-file   "${tvc_params[TVC_PARAM]}"            \
        --input-bam         "${tvc_params[BAM]}"                  \
        --reference-fasta   "${tvc_params[REFERENCE]}"            \
        --region-bed        "${tvc_params[BED_MERGED_PLAIN]}"     \
        --primer-trim-bed   "${tvc_params[BED_UNMERGED_DETAIL]}"  \
        --hotspot-vcf       "${tvc_params[HOTSPOT_VCF]}"          \
        --output-dir        "${tvc_params[OUTDIR]}"                         
"
if [[ $debug -eq 1 ]]; then
    echo "Formatted launch cmd:"
fi

echo $tvc_launch_cmd
echo "$(now) Launching TVC..."
eval $tvc_launch_cmd
echo "$(now) TVC Pipeline complete."
mv "$logfile" "$outdir"
