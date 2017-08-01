#!/bin/bash -x
source ./tools/env.sh
echo XSA Rebuild Python Starting

js_url="$(xs app $js_app --urls)"

echo $js_url

xs push $python_app -p python -m $python_mem -b my_python_buildpack

python_url="$(xs app $python_app --urls)"

echo $python_url

#echo "Binding Python module to UAA"

#xs bind-service $python_app $uaa
##if [ $? -eq 0 ]
##then
##	echo "Binding of $python_app to $uaa was  created"
##	xs restart $python_app
##else
##	echo "Binding of $python_app to $uaa already exists"
##fi
#
#echo "Binding Python module to HDI-Container"
#
#xs bind-service $python_app $hdi
##if [ $? -eq 0 ]
##then
##	echo "Binding of $python_app to $hdi was  created"
#	xs restart $python_app
##else
##	echo "Binding of $python_app to $hdi already exists"
##fi

echo XSA Rebuild Python Finished

exit 0
