"""
A first simple Cloud Foundry Flask app
Author: Ian Huston
License: See LICENSE.txt
"""
from flask import Flask
from flask import request
import os
import pyhdb
# Downloading pyhdb-0.3.3.tar.gz
import json
import datetime
import Crypto.PublicKey.RSA as RSA
import jws.utils
import python_jwt as jwt

app = Flask(__name__)

# Get port from environment variable or choose 9099 as local default
port = int(os.getenv("PORT", 9099))

# This module's Flask webserver will respond to these three routes (URL paths)
# If there is no path then just return Hello World and this module's instance number
@app.route('/')
def hello_world():
    return 'Hello World! I am instance ' + str(os.getenv("CF_INSTANCE_INDEX", 0))

# If there is a request for a python/test, return Testing message and module's instance number
@app.route('/python/test')
def testing_world():
    return 'Testing!!!xyz I am instance ' + str(os.getenv("CF_INSTANCE_INDEX", 0))

# If there is a request for a python/test2, return Testing message and then check JWT and connect to the data service and retrieve some data
@app.route('/python/test2')
def testing2_world():
    output = 'Testing More! \n'
    output += '\n'
    output += 'Receiving module should check that it came from our approuter and verify or abort if otherwise.\n'
    output += '\n'
    svcs_json = str(os.getenv("VCAP_SERVICES", 0))
    svcs = json.loads(svcs_json)

    # Verify the JWT before proceeding. or refuse to process the request.
    # https://jwt.io/ JWT Debugger Tool and libs for all languages
    # https://github.com/jpadilla/pyjwt/
    # https://github.com/davedoesdev/python-jwt

    # From the vcap_services environment variable pull out these things for later.
    vkey = svcs["xsuaa"][0]["credentials"]["verificationkey"]
    secret = svcs["xsuaa"][0]["credentials"]["clientsecret"]

    #output += 'vkey: ' + vkey + '\n'
    #output += 'secret: ' + secret + '\n'

    #jwt.decode(encoded, verify=False)
    req_host = request.headers.get('Host')
    req_auth = request.headers.get('Authorization')

    #output += 'req_host: ' + req_host + '\n'
    #output += 'req_auth: ' + req_auth + '\n'

    #import jwt
    #output += 'req_auth = ' + req_auth + '\n'

    #Check to see if the request has an authorization header and if it starts with "Bearer "
    if req_auth:
        if req_auth.startswith("Bearer "):
            output += 'JWT Authorization is of type Bearer! \n'
        else:
            output += 'JWT Authorization is not of type Bearer! \n'
    else:
        output += 'Authorization header is missing! \n'

    output += '\n'

    #If it looks like the right type of authoriztion header, grab it's contents.
    if req_auth:
        jwtoken = req_auth[7:]

        # The PKEY in the env has the \n stripped out and the importKey expects them!
        pub_pem = "-----BEGIN PUBLIC KEY-----\n" + vkey[26:-24] + "\n-----END PUBLIC KEY-----\n"
        #output += 'pub_pem = ' + pub_pem + '\n'

	# Manipulate the pem key so that we can verify it.
        pub_key = RSA.importKey(pub_pem)
        (header, claim, sig) = jwtoken.split('.')
        header = jws.utils.from_base64(header)
        claim = jws.utils.from_base64(claim)
        if jws.verify(header, claim, sig, pub_key, is_json=True):
            output += 'JWT is Verified! \n'
        else:
            output += 'JWT FAILED Verification! \n'

    else:
        output += 'Normally we would only do work if JWT is verified.\n'

    output += '\n'

    # This module should only proced with any further execution if the JWT has been verified.
    # In this example we blindly continue, but this is not the best practice.

    # Grab information from the vcap_services about the database connection
    schema = svcs["hana"][0]["credentials"]["schema"]
    user = svcs["hana"][0]["credentials"]["user"]
    password = svcs["hana"][0]["credentials"]["password"]
    conn_str = svcs["hana"][0]["credentials"]["url"]
    host = svcs["hana"][0]["credentials"]["host"]
    port = svcs["hana"][0]["credentials"]["port"]
    driver = svcs["hana"][0]["credentials"]["driver"]

    output += 'schema: ' + schema + '\n'
    output += 'user: ' + user + '\n'
    output += 'password: ' + password + '\n'
    output += 'conn_str: ' + conn_str + '\n'
    output += 'host: ' + host + '\n'
    output += 'port: ' + port + '\n'
    output += 'driver: ' + driver + '\n'

    output += '\n'
    # Connect to the python HANA DB driver using the connection info
    connection = pyhdb.connect(host,int(port),user,password)
    # Prep a cursor for SQL execution
    cursor = connection.cursor()
    # Form an SQL statement to retrieve some data
    cursor.execute('SELECT "tempId", "tempVal", "ts", "created" FROM "' + schema + '"."sensors.temp"')
    # Execute the SQL and capture the result set
    sensor_vals = cursor.fetchall()

    # Loop through the result set and output
    for sensor_val in sensor_vals:
        output += 'sensor_val: ' + str(sensor_val[1]) + ' at: ' + str(sensor_val[2]) + '\n'

    # Close the DB connection
    connection.close()

    # Return the results
    return output

if __name__ == '__main__':
    # Run the app, listening on all IPs with our chosen port number
    app.run(host='0.0.0.0', port=port)
