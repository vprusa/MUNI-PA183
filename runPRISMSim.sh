#!/bin/bash
THIS_DIR=$(dirname `realpath "$0"`)
chsh -s /bin/bash
# this script runs iterations of PRISM's simulation on given model
# and then creates histograms out of results and out of averaged iterations results
# TODO then it does Reachability test for given value

PRISM_BIN_FILE=~/IDE/bio/prism/prism-4.5-linux64/bin/prism

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
# s -> (more or less) silent
#RUN_FUN="phmr"
#RUN_FUN="hr"
RUN_FUN=`[[ -z "$1" ]] && echo "phmrs" || echo "$1"`

FILE=prism_model_gen1.sm
if [[ ! -z ${2} ]] ; then
  FILE=${2}
fi

if [[ ! -z ${3} ]] ; then
  FILE_ID=${3}
fi

echo "FILE: $FILE"
MODEL_FILE=${THIS_DIR}/$FILE

SIM_ITERATIONS=150
PRISM_RESULT_TO_HIST_COLS=( 4 5 )
DESIRED_LINE=102

NOW_DIR_NAME=`date +%Y-%m-%d_%H-%M-%S`
TMP_DIR=${THIS_DIR}/tmp/tmp-${FILE_ID}/

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
function histogramValues(){
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
        last=0
        for (h in hist){
            while(last < h-1){
              printf " %i  ->  0 \n", last+1
              last=last+1
            }
            last=h
            printf " %i  ->  %i \n", h, hist[h]
          }
    }
EOF
)
  [[ $DEBUG == *"h"* ]] && echo "AWK_CMD: $AWK_CMD"
  awk "$AWK_CMD" ${1}
}

function histogram(){
  #histogramValues $1 $2 | sort -k1 -n  | uniq
  histo="============================================================================================================================================+"

  while IFS= read -r line
  do
    cols=( $line )
    value=${cols[2]}

    space=""
    if [[ ${cols[0]} -le 9 ]]; then
      space="$space "
    fi
    if [[ ${cols[0]} -le 99 ]]; then
      space="$space "
    fi
    space2=""
    if [[ ${cols[2]} -le 9 ]]; then
      space2="$space2 "
    fi
    if [[ ${cols[2]} -le 99 ]]; then
      space2="$space2 "
    fi

    echo "$space$line $space2${histo:0:$value}"
  done < <(histogramValues $1 $2)
}

declare -A histResults

function prismResults(){
  FILE_NAME_PART_TMPL="${OUT_FILE_NAME_PART}/iter-{iteration}"
  mkdir -p ${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}
  for i in $(seq 1 $SIM_ITERATIONS); do
    fileNamePart=${FILE_NAME_PART_TMPL/"{iteration}"/${i}}
    outFile=${TMP_LATEST_DIR}/${fileNamePart}.out
    if [[ $RUN_FUN == *"m"* ]] ; then
      #echo "Iteration: $i"
      printf '\r%s: %2d' "Iteration" "$i"
      cmd="${PRISM_BIN_FILE} ${MODEL_FILE} ${PRISM_CMD_PROPERTIES} ${outFile}"
      [[ $RUN_FUN != *"s"* ]] && echo "Executing: ${cmd}"
      [[ $RUN_FUN == *"s"* ]] && ${cmd} 2>&1 > /dev/null || ${cmd}
    fi
  done
}

prismResults
echo ""

function histPrismResultsOnLine(){
  fileNamePart=$1
  outFile=${TMP_LATEST_DIR}/${fileNamePart}.out
  if [[ $RUN_FUN == *"h"* ]] ; then
    for col in ${PRISM_RESULT_TO_HIST_COLS[@]}; do
        cmd="histogram $outFile $col"
        [[ $RUN_FUN != *"s"* ]] && echo "  Executing: ${cmd}"
        cmdRes=`$cmd`
        histResults[$col]="$cmdRes"
    done
  fi
  #cat ${outFile}
}

function extractLines(){
  LINE_NMB=$1
  outFile=${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}.lines.${LINE_NMB}.out
  #echo "extractLines - LINE_NMB: ${LINE_NMB} "
  mkdir -p ${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}

  for i in $(seq 1 $SIM_ITERATIONS); do
    inFile=${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}/iter-${i}.out
    cmd="sed -n \"${LINE_NMB}p\" $inFile"
    [[ $RUN_FUN != *"s"* ]] && echo "cmd: ${cmd}"
    outLine=`$EXEC -c "${cmd}"`
    echo "${outLine}" >> $outFile
  done
}

function printResults(){
  if [[ $RUN_FUN == *"h"* ]] ; then
    histFile=${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}.histogram.out
    for col in ${PRISM_RESULT_TO_HIST_COLS[@]}; do
      fileHeadArr=( `head -n1 ${TMP_LATEST_DIR}/${OUT_FILE_NAME_PART}/iter-1.out` )
      echo "histogram results (column $col): ${fileHeadArr[$(($col-1))]}" >> ${histFile}
      # echo "${histResults[$col]}"
      echo "${histResults[$col]}" >> ${histFile}
    done
    echo "Histogram stored to: ${histFile}"
  fi
}

extractLines ${DESIRED_LINE}
DESIRED_LINE_FILE_NAME_PART=${OUT_FILE_NAME_PART}.lines.${DESIRED_LINE}


#echo -e "\n histPrismResultsOnLine: ${DESIRED_LINE_FILE_NAME_PART}"
histPrismResultsOnLine "${DESIRED_LINE_FILE_NAME_PART}"

[[ $RUN_FUN == *"r"* ]] && printResults

#
