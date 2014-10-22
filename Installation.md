Installation Guide
==================

Prerequirements
---------------

Install xmlsec1, which is required by the am_server

    % apt-get install libxmlsec1-dev xmlsec1

Repository
----------

At this stage the best course of action is to clone the 'dostavro/omf_sfa' repository, which includes the most updated version (very soon, it will be pulled to the original repository 'mytestbed/omf_sfa').

    % git clone https://github.com/dostavro/omf_sfa.git
    % cd omf_sfa
    % export OMF_SFA_HOME=`pwd`
    % bundle install

If your bundle FAILS because it cannot find PostgreSQL build environment, and you don't need this feature, then you should comment-in the line 
's.add_runtime_dependency "dm-postgres-adapter"' in the file $OMF_SFA_HOME/omf_sfa.gemspec and then bundle install again.

Configuration
-------------

This file OMF_SFA_HOME/etc/omf-sfa/omf-sfa-am.yaml, is the central configuration file of omf-sfa.
At first, you are able to use nitlab.inf.uth.gr as xmpp server. In case you want to use your own one, you can change it here [tutorial for xmpp](http://mytestbed.net/doc/omf/file.set_up_communication_server.html).

    % cd $OMF_SFA_HOME/etc/omf-sfa
    % nano omf-sfa-am.yaml

Database
--------

Use the Rakefile to create the database, where the description of your resources is being stored.

    % cd $OMF_SFA_HOME
    % rake autoMigrate

this will create an empty database based on the information defined on the
configuration file.

If a change in the database model is required we can use the Rakefile to
autoUpgrade the database.

    % rake autoUpgrade

Certificates
------------

The directory which holds the certificates is specified in the configuration
file.

First we have to create a root self signed certificate for our testbed that will sign every other
certificate we create.

    % omf_cert.rb --email root@nitlab.inf.uth.gr -o root.pem --duration 5000000 create_root

Then you have to copy this file to the trusted roots directory (defined in the configuration file)

    % mkdir ~/.omf
    % mkdir ~/.omf/trusted_roots
    % cp root.pem ~/.omf/trusted_roots

Now we have to create the certificate used by am_server and copy it to the coresponding directory.
Please notice that we are using the root certificate we have just created in --root argument, also 
notice that we are using omf:testserver as our domain, if you have changed the domain in the configuration file 
omf-sfa-am.yaml change the following commands accordingly too (also if on previous steps you have decided to 
use your xmpp, change the xmpp here as well). 


    % omf_cert.rb -o am.pem  --geni_uri URI:urn:publicid:IDN+omf:testserver+user+am --email am@nitlab.inf.uth.gr --resource-id xmpp://am_controller@nitlab.inf.uth.gr --resource-type am_controller --root root.pem --duration 5000000 create_resource
    % cp am.pem ~/.omf/

We also have to create a user certificate (for root user) for the various scripts to use. You can use this command to 
create certificates for any user you wish.

    % omf_cert.rb -o user_cert.pem --geni_uri URI:urn:publicid:IDN+omf:testserver+user+root --email root@nitlab.inf.uth.gr --user root --root root.pem --duration 5000000 create_user
    % cp user_cert.pem ~/.omf/

Now open the above certificates with any text editor copy the private key at the bottom of the certificate (with the headings)
create a new file (get the name of the private key from the corresponding configuration file) and paste the private key in this file.
For example:

    % nano user_cert.pem
    copy something that looks like this
      \-----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEA4Rbp2cdAsZ2147QgqnQUeA4y8KSCXYpcp+acVIBFecVT94EC
      D59l162wMb67tGSwSim3K59olN02A6beN46u ... aafh6gmHbDGx+j1UAo1bFtA
      kjYJDDXxhrU1yK/foHdT38v5TlGmSvbuubuWOskCJRoKkHfbOPlH
      \-----END RSA PRIVATE KEY-----
    % touch user_cert.pkey
    % nano user_cert.pkey
    paste

Repeat this process for the am.pem certificate.
Also copy the am certificate to trusted_roots folder.

	% cp am.pem ~/.omf/trusted_roots 

Hint: you can use the following command in order to inspect a certificate in a human readable way.

    % openssl x509 -in root.pem -text

Execute am_server
-------------------

To start an AM from this directory, run the following:

    % cd $OMF_SFA_HOME
    % bundle exec ruby -I lib lib/omf-sfa/am/am_server.rb start

Now lets use the REST interface to check that the server is running, open a browser and type in the address bar:

	https://localhost:8001/

If the browser asks you to trust the certificate of the server, press yes (I understand the risks choice in firefox).
Then you should see the readme file of the REST interface. This means that you have a working am_server, but the inventory is 
empty, in next section it is explained how to populate the db, with resource description.

Hint: The last part of this tutorial explains how you can setup the server to run as an upstart service, for now it is 
not required (and best skipped), but it is really usefull, from an administration prospective, when you are running a production server.

Populate the database
---------------------

First you have to edit the configuration file for the create_resource script accordingly (if on previous steps you have decided to 
use your xmpp, change the xmpp here as well):

    % nano $OMF_SFA_HOME/bin/conf.yaml

Then a json file that describes the resources is required. 
This file can contain either a single resource or more than one resources in the form of an array. 
A sample file is [here](https://github.com/dostavro/omf_sfa/tree/master/examples/Populate_DB/sample_nitos_enriched_nodes_out.json). 
The description of each resource is in the form of filling specific values to the predefined properties of each resources. 
The set of the properties of each resource is defined in its model (e.g. for the resource of type node, the model is [here](https://github.com/dostavro/omf_sfa/blob/master/lib/omf-sfa/resource/node.rb.
Please have in mind that although most of the properties are optional, there are properties like 'urn' which are mandatory (skipping urn might cause unexpected behaviour).
Moreover, there are properties like 'hardware_type' that are testbed specific and follow a convention.

To populate the database with the nodes:

    % ./create_resource -t node -c conf.yaml -i nodes_description.json

This script uses the xmpp interface of am_server to import data in the database.

In order to populate the database with the channels a similar procedure can be followed. We need a json that describes the
channels (sample file [here](https://github.com/dostavro/omf_sfa/tree/master/examples/Populate_DB/sample_nitos_channels.json)).

    % ./create_resource -t channel -c conf.yaml -i channels_description.json

Now let's use the REST interface again to see the data in the browser, open the browser again and type in the address bar:
    
    https://localhost:8001/resources/nodes

A json with the description of the nodes should appear (you can try https://localhost:8001/resources/channels also if you want).
Congratulations you have a working am_server!

Creating an upstart service 
---------------------------

An Upstart service is an event-based daemon which handles starting of tasks and services during boot, 
stopping them during shutdown and supervising them while the system is running.
In order to create your own upstart service you need to copy the conf file located in init/omf-sfa.conf of
your cloned repository and paste it to folder /etc/init. 

    % cp init/omf-sfa.conf /etc/init/

Then edit it accordingly (line 'chdir /root/omf/omf_sfa' must be changed to point to your omf-sfa folder). For example:


    % start on runlevel [2345]

    % respawn
    % env HOME=/root
    % chdir /root/omf/omf_sfa
     
    % script
    %   exec bundle exec ruby -I lib/ lib/omf-sfa/am/am_server.rb start
    % end script

Then you can start stop or restart the service with:

    % start omf-sfa
    % stop omf-sfa
    % restart omf-sfa

Now that this service will start on system boot, and respawn if it dies unexpectedly.

You can find the log file on omf-sfa on folder '/var/log/upstart/omf-sfa.log'

    % tail -f /var/log/upstart/omf_sfa.log 
