#!/bin/bash
THIS_DIR=$(dirname `realpath "$0"`)
chsh -s /bin/bash
# this script runs iterations of PRISM's simulation on given model
# and then creates histograms out of results and out of averaged iterations results
# TODO then it does Reachability test for given value

PRISM_BIN_FILE=~/IDE/bio/prism/prism-4.5-linux64/bin/prism
#MODEL_FILE=~/IDE/bio/prism/PA183/files/prism_model10.sm
MODEL_FILE=~/IDE/bio/prism/PA183/files/prism_case_study_cell_cycle_cyclin_edited.sm
PRISM_CMD_PROPERTIES="-simpath 100,loopcheck=false"
OUT_FILE_NAME_PART="prism"

# seems like local bash is broken, idk why, using 'bash -c ...' workaround works
EXEC="bash"

# if contains X enables debug messages for Y function/procedure
# p -> prepare
# h -> histogram
DEBUG="0"
# p -> prepare
# h -> histogram & its results
# m -> prism
# r -> printResults
#RUN_FUN="phmr"
#RUN_FUN="hr"
RUN_FUN=`[[ -z "$1" ]] && echo "phmr" || echo "$1"`


SIM_ITERATIONS=100
PRISM_RESULT_TO_HIST_COLS=( 4 5 )
DESIRED_LINE=102

NOW_DIR_NAME=`date +%Y-%m-%d_%H-%M-%S`
TMP_DIR=${THIS_DIR}/tmp/
TMP_LATEST_DIR_NAME=./latest
TMP_CURRENT_DIR=${TMP_DIR}/${NOW_DIR_NAME}
TMP_LATEST_DIR=${TMP_DIR}/${TMP_LATEST_DIR_NAME}

function prepareEnv(){
  [[ $DEBUG == *"p"* ]] && echo "Preparing environment..."
  mkdir -p ${TMP_CURRENT_DIR}
  rm "${TMP_LATEST_DIR}"
  [[ $DEBUG == *"p"* ]] && echo "Creating symlink to latest results.."
  $EXEC -c "cd ${TMP_DIR} && ln -s ${NOW_DIR_NAME} ${TMP_LATEST_DIR_NAME}"
}

[[ $RUN_FUN == *"p"* ]] && prepareEnv

# note - result's columns:
# action step time s1 s2 - 0 0.0 1 1

# https://stackoverflow.com/questions/39614454/creating-histograms-in-bash
function histogram(){
  [[ $DEBUG == *"h"* ]] && echo "histogram from ${1} on column ${2}"
  # End Of Command
  AWK_CMD=$(cat <<-EOF
    BEGIN{
        bin_width=1;
    }
    {
        bin=int((\$$2)/bin_width);
        if( bin in hist){
            hist[bin]+=1
        }else{
            hist[bin]=1
        }
    }
    END{
        for (h in hist)
            printf " %i  ->  %i \n", h, hist[h]
    }
EOF
)

  [[ $DEBUG == *"h"* ]] && echo "AWK_CMD: $AWK_CMD"
  awk "$AWK_CMD" ${1}
}

declare -A histResults

function prismResults(){
  FILE_NAME_PART_TMPL="${OUT_FILE_NAME_PART}.{iteration}"
  for i in $(seq 1 $SIM_ITERATIONS); do
    fileNamePart=${FILE_NAME_PART_TMPL/"{iteration}"/${i}}
    outFile=${TMP_LATEST_DIR}/${fileNamePart}.out
    if [[ $RUN_FUN == *"m"* ]] ; then
      echo "Iteration: $i"
      cmd="${PRISM_BIN_FILE} ${MODEL_FILE} ${PRISM_CMD_PROPERTIES} ${outFile}"
      echo "Executing: ${cmd}"
      ${cmd}
    fi
  done
}

prismResults

function histPrismResultsOnLine(){
  fileNamePart=$1
  outFile=${TMP_LATEST_DIR}/${fileNamePart}.out
  if [[ $RUN_FUN == *"h"* ]] ; then
    for col in ${PRISM_RESULT_TO_HIST_COLS[@]}; do
        cmd="histogram $outFile $col"
        echo "  Executing: ${cmd}"
        cmdRes=`$cmd`
        histResults[$col]="$cmdRes"
    done
  fi
  cat ${outFile}
}

function extractLines(){
  LINE_NMB=$1
  outFile=${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}.lines.${LINE_NMB}.out
  echo "extractLines - LINE_NMB: ${LINE_NMB} "
  for i in $(seq 1 $SIM_ITERATIONS); do
    inFile=${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}.${i}.out
    cmd="sed -n \"${LINE_NMB}p\" $inFile"
    echo "cmd: ${cmd}"
    outLine=`$EXEC -c "${cmd}"`
    echo "${outLine}" >> $outFile
  done
}

function printResults(){
  if [[ $RUN_FUN == *"h"* ]] ; then
    for col in ${PRISM_RESULT_TO_HIST_COLS[@]}; do
      echo "histResults: $col"
      echo "${histResults[$col]}"
    done
  fi
}

extractLines ${DESIRED_LINE}
DESIRED_LINE_FILE_NAME_PART=${OUT_FILE_NAME_PART}.lines.${DESIRED_LINE}


echo "histPrismResultsOnLine: ${DESIRED_LINE_FILE_NAME_PART}"
histPrismResultsOnLine "${DESIRED_LINE_FILE_NAME_PART}"

[[ $RUN_FUN == *"r"* ]] && printResults

#
