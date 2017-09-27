#!/bin/bash -x
#Modify these variable to match your situation/needs

user="XSA_DEV"
magic="8coh90w7mrionqr5"
proj="hana-xsa-python-buildpack" #Only if you've changed the project name

#=== Don't change things below this line ===

hdi="$user-$magic-$proj-hdi-container"
uaa="mta-python-uaa"

js_app="$user-$magic-$proj-js"
web_app="$user-$magic-$proj-web"
python_app="$user-$magic-$proj-python"
python_mem="96M"

