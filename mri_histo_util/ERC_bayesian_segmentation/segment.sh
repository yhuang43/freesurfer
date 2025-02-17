#!/usr/bin/env bash

# Exit at any error
set -e

# Make sure FreeSurfer is sourced
[ ! -e "$FREESURFER_HOME" ] && echo "error: freesurfer has not been properly sourced" && exit 1

# If requesting help
if  [ $# == 1 ] && [  $1 == "--help" ]
then
  echo " "
  echo "Bayesian segmentation with histological whole brain atlas."
  echo " "
  echo "Next-Generation histological atlas for high-resolution segmentation of human brain MRI"
  echo "Casamitjana et al. (in preparation)"
  echo " "
  echo "Usage:"
  echo "   segment.sh INPUT_SCAN OUTPUT_DIRECTORY GPU THREADS [BF_MODE] [GMM_MODE]"
  echo " "
  echo "INPUT SCAN: scan to process, in mgz or nii(.gz) format"
  echo "OUTPUT_DIRECTORY: directory with segmentations, volume files, etc"
  echo "GPU: set to 1 to use the GPU (*highly* recommended but requires a 24GB GPU!)"
  echo "THREADS: number of CPU threads to use (use -1 for all available threads)"
  echo "BF_MODE (optional): bias field model: dct (default), polynomial, or hybrid"
  echo "GMM_MODE (optional): must be 1mm (default) unless you define your own (see documentation)"
  echo " "
  exit 0
fi

# If number of arguments is incorrect
if [ $# -lt 4 ] || [ $# -gt 6 ]
then
  echo " "
  echo "Incorrect number of arguments."
  echo "Usage: "
  echo " "
  echo "   segment.sh INPUT_SCAN OUTPUT_DIRECTORY GPU THREADS BF_MODE GMM_MODE"
  echo " "
  echo "Or, for help"
  echo " "
  echo "   segment.sh --help"
  echo " "
  exit 1
fi

# Find path to shell script
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Try to find atlas data
ATLAS_DIR="$SCRIPTPATH/atlas"
# TODO remove the following line
#ATLAS_DIR="/autofs/space/panamint_005/users/iglesias/data/ERC_segmentation_3D/HierarchicalSegmentation/sparse_npz_blurred_sigma_4_samseg_background_fixed_conn_comps"
if [ ! -f "$ATLAS_DIR/size.npy" ];
then
  echo " "
  echo "   Atlas files not found. Please download atlas from: "
  echo "      https://ftp.nmr.mgh.harvard.edu/pub/dist/lcnpublic/dist/Histo_Atlas_Iglesias_2023/atlas.zip "
  echo "   and uncompress it into:  "
  echo "      $SCRIPTPATH/ "
  echo "   You only need to do this once. You can use the following three commands: "
  echo "      1: cd $SCRIPTPATH"
  echo "      2a (in Linux): wget https://ftp.nmr.mgh.harvard.edu/pub/dist/lcnpublic/dist/Histo_Atlas_Iglesias_2023/atlas.zip "
  echo "      2b (in MAC): curl -o atlas.zip https://ftp.nmr.mgh.harvard.edu/pub/dist/lcnpublic/dist/Histo_Atlas_Iglesias_2023/atlas.zip "
  echo "      3. unzip atlas.zip"
  echo " "
  echo "   After correct extraction, the directory: "
  echo "      $ATLAS_DIR "
  echo "   should contain files: size.npy, label_001.npz, label_002.npz, ..., and label_334.npz"
  echo " "
  exit 1
fi

# Parse arguments
INPUT=$1
OUTPUT_DIR=$2
CPU_FLAG=' '
if [ $3 -eq 0 ]
then
  CPU_FLAG='--cpu'
fi
THREADS=$4
BF_MODE='dct'
if [ $# -gt 4 ]
then
  BF_MODE=$5
fi
GMM_MODE='1mm'
if [ $# -gt 5 ]
then
  GMM_MODE=$6
fi


# Create command line arguments and run!
SYNTHSEG="$OUTPUT_DIR/SynthSeg.mgz"
SYNTHSEGCSV="$OUTPUT_DIR/SynthSeg.vols.csv"
FIELD="$OUTPUT_DIR/MNI_registration.mgz"
OUTPUT_SEG="$OUTPUT_DIR/seg_left.mgz"
OUTPUT_VOL="$OUTPUT_DIR/vols_left.csv"
BFCORR="$OUTPUT_DIR/bf_corrected.mgz"


# Create output directory if it isn't there
echo " "
if [ -d $OUTPUT_DIR ]; then
  echo "Output directory already exists, no need to create it"
else
  mkdir $OUTPUT_DIR
fi


echo "  "
echo "******************************"
echo "* Working on left hemisphere *"
echo "******************************"
echo "  "
cmd="fspython $SCRIPTPATH/scripts/segment.py --i $INPUT --gmm_mode $GMM_MODE --bf_mode $BF_MODE --i_seg $SYNTHSEG --o_synthseg_vols $SYNTHSEGCSV --i_field $FIELD --atlas_dir $ATLAS_DIR --hemi l --o_bf_corr $BFCORR --o $OUTPUT_SEG --o_vol $OUTPUT_VOL --threads $THREADS $CPU_FLAG "
echo "Running command:"
echo $cmd
echo "  "
$cmd

OUTPUT_SEG="$OUTPUT_DIR/seg_right.mgz"
OUTPUT_VOL="$OUTPUT_DIR/vols_right.csv"
echo "  "
echo "*******************************"
echo "* Working on right hemisphere *"
echo "*******************************"
echo "  "
cmd="fspython $SCRIPTPATH/scripts/segment.py --i $INPUT --gmm_mode $GMM_MODE --bf_mode $BF_MODE --i_seg $SYNTHSEG --o_synthseg_vols $SYNTHSEGCSV --i_field $FIELD --atlas_dir $ATLAS_DIR --hemi r --o $OUTPUT_SEG --o_vol $OUTPUT_VOL --threads $THREADS $CPU_FLAG "
echo "Running command:"
echo $cmd
echo "  "
$cmd

# Copy lookup table, for convenience
cp $SCRIPTPATH/data/AllenAtlasLUT $OUTPUT_DIR/lookup_table.txt

touch $OUTPUT_DIR/done

echo "  "
echo "*****************"
echo "* All done!!!!! *"
echo "*****************"
echo "  "