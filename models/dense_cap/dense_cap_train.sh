# Script for training dense captioning model with joint inference and visual context
# Do freeze-convnet training first, then finetuning
# Usage:
# ./models/dense_cap/dense_cap_train.sh [GPU_ID] [DATASET] [MODEL_TYPE] [INITIAL_WEIGHTS] [EXTRA_ARGS]
# Example:
# To train a model with joint inference and visual context (late fusion, feature summation) on visual genome 1.0
# ./models/dense_cap/dense_cap_train.sh 1 visual_genome late_fusion_sum models/vggnet/vgg16.caffemodel 
set -x
set -e

export PYTHONUNBUFFERED="True"

GPU_ID=$1
DATASET=$2
MODEL_TYPE=$3
WEIGHTS=$4
array=( $@ )
len=${#array[@]}
EXTRA_ARGS=${array[@]:4:$len}
EXTRA_ARGS_SLUG=${EXTRA_ARGS// /_}
case $DATASET in
   visual_genome)
    TRAIN_IMDB="vg_1.0_train"
    TEST_IMDB="vg_1.0_val"
    PT_DIR="dense_cap"
    FINETUNE_AFTER=200000
    ITERS=400000
    ;;
  visual_genome_1.2)
    TRAIN_IMDB="vg_1.2_train"
    TEST_IMDB="vg_1.2_val"
    PT_DIR="dense_cap"
    FINETUNE_AFTER=200000
    ITERS=400000
    ;;
  *)
    echo "No dataset given"
    exit
    ;;
esac
GLOG_logtostderr=1
# If training visual context model, need to start with the context-free counterpart
if [ ${MODEL_TYPE} != "joint_inference" ]
then
./lib/tools/train_net.py --gpu ${GPU_ID} \
  --solver models/${PT_DIR}/solver_joint_inference.prototxt \
  --weights ${WEIGHTS} \
  --imdb ${TRAIN_IMDB} \
  --iters ${FINETUNE_AFTER} \
  --cfg models/${PT_DIR}/dense_cap.yml \
  ${EXTRA_ARGS}
WEIGHTS=output/dense_cap/${TRAIN_IMDB}/dense_cap_joint_inference_iter_${FINETUNE_AFTER}.caffemodel
fi
# Training with convnet weights fixed
./lib/tools/train_net.py --gpu ${GPU_ID} \
  --solver models/${PT_DIR}/solver_${MODEL_TYPE}.prototxt \
  --weights ${WEIGHTS} \
  --imdb ${TRAIN_IMDB} \
  --iters ${FINETUNE_AFTER} \
  --cfg models/${PT_DIR}/dense_cap.yml \
  ${EXTRA_ARGS}
NEW_WEIGHTS=output/dense_cap/${TRAIN_IMDB}/dense_cap_${MODEL_TYPE}_iter_${FINETUNE_AFTER}.caffemodel
# Finetuning all weights
./lib/tools/train_net.py --gpu ${GPU_ID} \
  --solver models/${PT_DIR}/solver_${MODEL_TYPE}_finetune.prototxt \
  --weights ${NEW_WEIGHTS} \
  --imdb ${TRAIN_IMDB} \
  --iters `expr ${ITERS} - ${FINETUNE_AFTER}` \
  --cfg models/${PT_DIR}/dense_cap.yml \
  ${EXTRA_ARGS}

