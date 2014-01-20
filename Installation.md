Installation Guide
==================

Repository
----------

At this stage the best course of action is to clone the repository

    % git clone https://github.com/mytestbed/omf_sfa.git
    % cd omf_sfa
    % export OMF_SFA_HOME=`pwd`
    % bundle install

Configuration
-------------

Edit the configuration file (OMF_SFA_HOME/etc/omf-sfa/omf-sfa-am.yaml).

    % cd $OMF_SFA_HOME/etc/omf-sfa
    % vim omf-sfa-am.yaml

Database
--------

Use the Rakefile to create the database.

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

In order to create the required certificates we need to use a script in the
bin directory of OMF (in the future this file will be an executable in the
systems directory so we can use it directly, at the time being though this is
not the case).

    % cd OMF_HOME/bin

First we have to create a root certificate for our testbed that will sign every other
certificate we create.

    % ruby omf_cert.rb --email root@nitlab.inf.uth.gr -o root.pem --duration 5000000 create_root

Then you have to copy this file to the trusted roots directory (defined in the configuration file)

    % cp root.pem ~/.omf/trusted_roots

Now we have to create the certificate used by am_server and copy it to the coresponding direcotry.
Please notice that we are using the root certificate we have just created in --root arguement

    % ruby omf_cert.rb -o am.pem --email am@nitlab.inf.uth.gr --resource-id xmpp://am_controller@testserver --resource-type am_controller --root root.pem --duration 5000000 create_resource
    % cp am.pem ~/.omf/

We also have to create a user certificate for the various scripts to use.

    % ruby omf_cert.rb -o user_cert.pem --email root@nitlab.inf.uth.gr --user root --root root.pem --duration 5000000 create_user
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

Repeat this proccess for other certificates too.

Hint: you can use the following command in order to inspect a certificate in a human readable way.

    % openssl x509 -in root.pem -text

Populate the database
---------------------

In order to populate the database you have to use the following script:

    OMF_SFA_HOME/bin/create_resource

First you have to edit the configuration file accordingly:

    % nano OMF_SFA_HOME/bin/conf.yaml

Then a json file that describes the resources is required. This file can contain either a single resource
or more than one resources in the form of an array. In NITOS we have exported a json file from the old inventory
(new_nitos_nodes.json) and created a parser (nitos_nodes_json_parser) to convert this file to the new format.
Parser usage:

    % ./nitos_nodes_json_parser new_nitos_nodes.json

This will create the file 'nitos_nodes_out.json'. We can use this file as input to create_resource script.

    % ./create_resource -t node -c conf.yaml -i nitos_nodes_out.json

This script uses the xmpp interface of am_server to import data in the database.

In order to populate the database with the channels a similar procedure can be followed. We need a json that describes the
channels (nitos_channels.json).

    % ./create_resource -t channel -c conf.yaml -i nitos_channels.json

Executing am_server
-------------------

To start an AM with a some pre-populated resources ('--test-load-am') from this directory, run the following:

    % cd $OMF_SFA_HOME
    % bundle exec ruby -I lib lib/omf-sfa/am/am_server.rb start

