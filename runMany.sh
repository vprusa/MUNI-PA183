#!/bin/bash
# this scripts runs runPRISMSim.sh on multiple models multiple times

THIS_DIR=$(dirname `realpath "$0"`)
chsh -s /bin/bash

ITERATIONS=1
mkdir -p ${THIS_DIR}/tmp

MODEL1_ORIG=${THIS_DIR}/prism_model1.sm
MODEL1_LOW=${THIS_DIR}/prism_model1_gen.low.sm
MODEL1_HIGH=${THIS_DIR}/prism_model1_gen.high.sm

MODEL1_ELOW=${THIS_DIR}/prism_model1_gen.extraLow.sm
MODEL1_EHIGH=${THIS_DIR}/prism_model1_gen.extraHigh.sm


MODEL2_ORIG=${THIS_DIR}/prism_model2.sm
MODEL2_LOW=${THIS_DIR}/prism_model2_gen.low.sm
MODEL2_HIGH=${THIS_DIR}/prism_model2_gen.high.sm

cp -r ${MODEL1_ORIG} ${MODEL1_LOW}
cp -r ${MODEL1_ORIG} ${MODEL1_HIGH}

sed -i "s/const double fi_pRB .*/const double fi_pRB = 0.005;/g" ${MODEL1_LOW}
sed -i "s/const double fi_pRB .*/const double fi_pRB = 0.01;/g" ${MODEL1_HIGH}


cp -r ${MODEL1_ORIG} ${MODEL1_ELOW}
cp -r ${MODEL1_ORIG} ${MODEL1_EHIGH}

sed -i "s/const double fi_pRB .*/const double fi_pRB = 0.0005;/g" ${MODEL1_ELOW}
sed -i "s/const double fi_pRB .*/const double fi_pRB = 0.05;/g" ${MODEL1_EHIGH}


cp -r ${MODEL2_ORIG} ${MODEL2_LOW}
cp -r ${MODEL2_ORIG} ${MODEL2_HIGH}

sed -i "s/const double pst_prot_deg_pRB .*/const double pst_prot_deg_pRB = 0.005;/g" ${MODEL2_LOW}
sed -i "s/const double pst_prot_deg_pRB .*/const double pst_prot_deg_pRB = 0.01;/g" ${MODEL2_HIGH}

rm -rf ${THIS_DIR}/tmp

for i in $(seq 1 $ITERATIONS); do
  echo "MODEL1_LOW: $MODEL1_LOW"
  logFile=${THIS_DIR}/tmp/1_Low-pRB-${i}.log
  echo "logFile: $logFile"
  ${THIS_DIR}/runPRISMSim.sh phmrs `basename ${MODEL1_LOW}` 1_LowFi-pRB & disown
  ${THIS_DIR}/runPRISMSim.sh phmrs `basename ${MODEL1_HIGH}` 1_HighFi-pRB & disown

  ${THIS_DIR}/runPRISMSim.sh phmrs `basename ${MODEL1_ELOW}` 1_ExtraLowFi-pRB & disown
  ${THIS_DIR}/runPRISMSim.sh phmrs `basename ${MODEL1_EHIGH}` 1_ExtraHighFi-pRB & disown

  ${THIS_DIR}/runPRISMSim.sh phmrs  `basename ${MODEL2_LOW}` 2_LowFi-pRB & disown
  ${THIS_DIR}/runPRISMSim.sh phmrs  `basename ${MODEL2_HIGH}` 2_HighFi-pRB & disown
done

#
