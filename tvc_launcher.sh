#!/bin/bash
# Launcher script for the TVC standalone pipeline to help speed up and simplify the processing of BAM files with 
# custom parameters.  You must provide a config file in the working directory, which will load up the parameters
# used in the pipeline
#
# 7/2/2014 - D Sims
###################################################################################################################
version="v1.1.0_032415"
script=$(basename $0)
debug=1
usage="$( cat <<EOT
$script [options] <output_root_dir> <bam_file>

Launcher script for standalone version of TVC created to make adjusting parameters and batch running a little
more simple.  

Script will read a default config file located in the current working directory by default.  If a custom config 
is desired, one can be fed to the script using the '-c' option.  The file must out line the following parameters:

    TVC_ROOT_DIR        : Location of the TVC binaries
    REFERENCE           : Location of the hg19.fasta reference sequence
    TVC_PARAM           : Location of the TVC paramters JSON file to be use for the analysis
    BED_MERGED_PLAIN    : Location of Plain, Merged regions BED file.
    BED_UNMERGED_DETAIL : Location of the Detailed, Unmerged regions BED file.
    HOTSPOT_VCF         : Location of the hotspots VCF file to be used in the analysis

For the time being, all of these parameters must be used in the config file.  For an example, see the default config
file in the current directory

Other options:
    -c    Use a custom config file instead of the default in the current working dir
    -v    Print the version information and exit.
    -h    Print this help text
EOT
)"

# Set up logging for run to capture std TVC output to data dir start log in cwd and then move to results later
logfile="$(date +"%Y%m%d").tvc_sa.log.txt"
exec > >(tee $logfile)
exec 2>&1

while getopts :c:hv opt;
do 
    case $opt in
        c)
            config_file="$OPTARG"
            if [[ ! -e "$config_file" ]]; then
                echo "ERROR: Selected config file '$config_file' can not be found"
                exit
            fi
            ;;
        v)
            echo -e "$script - $version\n"
            exit
            ;;
        h)
            echo "$script - $version"
            echo -e "$usage\n"
            exit
            ;;
        /?)
            echo "Invalid option: -$OPTARG\n"
            echo -e "$usage\n"
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Check that we've loaded an output dir and a bam file to process.
if (( $# < 2 )); then
    echo "ERROR: Invalid number of arguments!"
    echo -e "$usage\n"
    exit 1
fi

outdir_root=$1
input_bam=$(readlink -f $2)

cwd=$(pwd)
now() { now=$(date +%c); echo -n "[$now]:"; }

# Get the sample name assuming <sample_name>_<rawlib>?.<bam>
sample_name=$(echo $(basename $input_bam) | perl -pe 's/(.*?)(_rawlib)?.bam/\1/')
outdir="$cwd/$outdir_root/${sample_name}_out"
ptrim_bam="${outdir}/${sample_name}_PTRIM.bam"
post_proc_bam="${outdir}/${sample_name}_processed.bam"

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

# If no custom config file set, read in the default in the cwd 
if [[ -z $config_file ]]; then
    config_file="$cwd/config"
fi
declare -A tvc_params

if [[ ! -e "$config_file" ]]; then 
    echo "ERROR: Can not find a configuration file in the current directory."
    exit 1;
fi

err_count=0
while read key value;
do
    if [[ ! $key =~ ^\ *# && -n $key ]]; then
        if [[ -e "$value" ]]; then
            tvc_params[$key]=$value
        else
            tvc_params[$key]="NULL"
            err_count=1
        fi
    fi
done < $config_file

if [[ $err_count == 1 ]]; then
    echo "ERROR: There were invalid parameters found in the config file.  Can not continue unless the following params are fixed:"
    for err in "${!tvc_params[@]}"; do
        if [[ ${tvc_params[$err]} == 'NULL' ]]; then
            printf "\t%-20s  => %s\n" $err ${tvc_params[$err]}
        fi
    done
    exit 1
fi

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
tvc_params[PROCBAM]=$post_proc_bam

if [[ $debug -eq 1 ]]; then
    echo "Params as passed to TVC:"
    for key in "${!tvc_params[@]}"; do
        printf "\t%-20s  => %s\n" $key ${tvc_params[$key]}
    done
    echo
fi

tvc_launch_cmd="python $TVC_BIN_DIR/variant_caller_pipeline.py    \
        --num-threads       "34"                                  \
        --input-bam         "${tvc_params[BAM]}"                  \
        --primer-trim-bed   "${tvc_params[BED_UNMERGED_DETAIL]}"  \
        --postprocessed-bam "${tvc_params[PROCBAM]}"              \
        --reference-fasta   "${tvc_params[REFERENCE]}"            \
        --output-dir        "${tvc_params[OUTDIR]}"               \
        --parameters-file   "${tvc_params[TVC_PARAM]}"            \
        --region-bed        "${tvc_params[BED_MERGED_PLAIN]}"     \
        --hotspot-vcf       "${tvc_params[HOTSPOT_VCF]}"          \
        --error-motifs      "${tvc_params[ERROR_MOTIF]}"          \
"
if [[ $debug -eq 1 ]]; then
    echo "Formatted launch cmd:"
fi

echo $tvc_launch_cmd
echo "$(now) Launching TVC..."
eval $tvc_launch_cmd
echo "$(now) TVC Pipeline complete."
mv "$logfile" "$outdir"
