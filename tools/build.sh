#!/bin/bash
source ./tools/env.sh
echo "XSA Build Python Starting"

js_url="$(xs app $js_app --urls)"

echo "JS_URL: $js_url"

echo "Pushing $python_app using my_python_buildpack."

xs push $python_app -p python -m $python_mem -b my_python_buildpack
#xs push $python_app -p python -m $python_mem -b sap_python_buildpack

#exit 0

python_url="$(xs app $python_app --urls)"

echo "Python_URL: $python_url"

echo "Binding Python module to UAA"

xs bind-service $python_app $uaa
#if [ $? -eq 0 ]
#then
#	echo "Binding of $python_app to $uaa was  created"
#	xs restart $python_app
#else
#	echo "Binding of $python_app to $uaa already exists"
#fi

echo "Binding Python module to HDI-Container"

xs bind-service $python_app $hdi
#if [ $? -eq 0 ]
#then
#	echo "Binding of $python_app to $hdi was  created"
	xs restart $python_app
#else
#	echo "Binding of $python_app to $hdi already exists"
#fi

echo "Remapping App Router"

xs set-env $web_app destinations '[{"forwardAuthToken":true,"name":"js_be","url":"'$js_url'"},{"forwardAuthToken":true,"name":"python_be","url":"'$python_url'"}]'

xs restage $web_app

xs restart $web_app

echo "XSA Build Python Finished"
echo ""
echo "js_module : $js_app : $js_url"
echo "python_module : $python_app : $python_url"
echo ""
echo "To see the routing destinations of your app-router, run this command."
echo "xs env $web_app | grep destinations"
echo ""
xs env $web_app | grep destinations
echo ""
echo "web_module : $web_app"
xs app $web_app --urls
echo ""

exit 0
