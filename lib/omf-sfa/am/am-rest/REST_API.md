Objective
=========

This is the reference document for the REST API provided by NITOS Broker. This REST API can be used by developers who need access to NITOS Broker inventory with other standalone or web applications, and administrators who want to script interactions with the Testbed's Servers. At the moment Resource Discovery and Resource Reservation are possible through the REST interface.

Because the REST API is based on open standards, you can use any programming language to access the API. Briefly, a REST call can be described by:

1. URL: hostname and path (e.g. https://localhost:8001/resources)  
2. Body: the information needed to complete the requested operation
3. Methods: GET methods is used to list resources, POST method is used to create a new resource, PUT is used to update a resource and DELETE is used to delete a resource.
4. Parameters: used to filter the requested resources (e.g. https://localhost:8001/resources/nodes/?name=node001)

Table of contents
================= 

1. API
2. Authentication
3. Examples
4. More Examples
5. Footnotes

API
===

Resources
---------
* Description: 

Everything (either physical or not) in the inventory of NITOS broker is described as a Resource (e.g. Nodes, accounts, 
channels, etc). Using the path `/resources` you can get a description of all the resources in the inventory. Every 
resource is described by a universal unique id (uuid) and a name.

* path: `/resources`
* methods:
  * GET: List all resources
  * POST: Not allowed
  * PUT: Not allowed
  * DELETE: Not allowed
- This method is created for testing purposes and although it can be used in applications, it is not advised and usage of the methods described below is.

Nodes
---------
* Description

A Node is a physical machine that can be used in an experiment. Information about Nodes are critical to 
experimenters because Nodes are the in center of every experiment. Node characteristics that are needed to be 
described are hardware specifications (CPU, RAM, hd capacity, etc), interfaces (Ethernet interfaces, wireless 
interfaces, etc) and other node specifying information (Hostname etc). All those information are being exposed 
thought the methods bellow.

* path: `/resources/nodes`
* methods:
  * GET: List Nodes
      * Parameters
          * uuid: filter the results based on the universal unique id of the node
          * name: filter the results based on the name of the node
          * if no parameters are provided all Nodes are listed
  * POST: Create a resource of type Node
      * Body: Description of the Node to be created in json format
  * PUT: Update a resource of type Node
      * Body: Description of the Node to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Node
      * Body: Description of the Node to be deleted in json format (uuid or name is mandatory)

Channels
---------

* Description

Channels can be all the frequency channels described in wireless protocols like 802.11. Channels are important 
to experimenters because of interference with other experimenters. During an experiment (that involves wireless
experimentation) every experimenter should have at least one reserved channel and should be conducting his 
experiments only on that channel. Channel information are being exposed thought the methods bellow.

* `/resources/channels`
  * GET: List Channels
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the channel
          * name: filter the results based on the name of the channel
          * if no parameters are provided all Channels are listed
  * POST: Create a resource of type Channel
      * `Body`: Description of the Channel to be created in json format
  * PUT: Update a resource of type Channel
      * `Body`: Description of the Channel to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Channel
      * `Body`: Description of the Channel to be deleted in json format (uuid or name is mandatory)

Leases
---------
* Description

Leasing a resource is equivalent to reserving a resource. A Lease is associated with a time slot (valid_from, 
valid_until), an account and a resource. During that time slot the owner of the account gets full control of 
the resource and can use it in his experiments. Lease information are being exposed thought the methods bellow.

* `/resources/leases`
  * GET: List Leases
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the node
          * name: filter the results based on the name of the node
          * if no parameters are provided all Leases are listed
  * POST: Create a resource of type Leases
      * `Body`: Description of the Leases to be created in json format
  * PUT: Update a resource of type Leases
      * `Body`: Description of the Leases to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Leases
      * `Body`: Description of the Leases to be deleted in json format (uuid or name is mandatory)

Chassis Manager Cards
---------------------
* Description

Chassis Manager Cards are combined of a general purpose microcontroller, an Ethernet microcontroller and a 
relay's circuit. The microcontroller can support a tiny WebServer, so it can communicate through network 
controller and http protocol with any other device in the same network. Exploiting this ability we can send
http requests to CM card to give power to relays so they can bridge the jumpers of any motherboard to 
start/stop or reset their operation. Additionally CMC returns to us a http response and inform us about
the operation status of the node.

Information regarding CMCs can be very important to experimenters because they can use the CMC to control  
nodes in their experiments. Information regarding CMCs are exposed through the methods described bellow.

* `/resources/cmc`
  * GET: List Chassis Manager Cards
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the cmc
          * name: filter the results based on the name of the cmc
          * if no parameters are provided all CMCs are listed
  * POST: Create a resource of type CMC
      * `Body`: Description of the CMC to be created in json format
  * PUT: Update a resource of type CMC
      * `Body`: Description of the CMC to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type CMC
      * `Body`: Description of the CMC to be deleted in json format (uuid or name is mandatory)

Openflow Switches
-----------------
* Description

OpenFlow is an emerging new technology, the most widely used Software Defined Networking (SDN) enabler. OpenFlow
enables networks to evolve, by giving a remote controller the power to modify the behavior of network devices, 
through a well-defined "forwarding instruction set". Together with Flowvisor multiple researchers can run experiments 
safely and independently on the same production OpenFlow network. Information regarding Openflow switches are being 
advertised by this API through the methods below.

* `/resources/openflow`
  * GET: List of Openflow Switches
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the Openflow Switch
          * name: filter the results based on the name of the Openflow Switch
          * if no parameters are provided all Openflow Switches are listed
  * POST: Create a resource of type Openflow Switch
      * `Body`: Description of the Openflow Switch to be created in json format
  * PUT: Update a resource of type Openflow Switch
      * `Body`: Description of the Openflow Switch to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Openflow Switch
      * `Body`: Description of the Openflow Switch to be deleted in json format (uuid or name is mandatory)

LTE Base stations
------------------
* Description

* `/resources/lte`
  * GET: List LTE Base Stations
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the LTE Base stations
          * name: filter  the results based on the name of the LTE Base Stations
          * if no parameters are provided all LTE Base Stations are listed
  * POST: Create a resource of type LTE Base stations
      * `Body`: Description of the LTE Base stations to be created in json format
  * PUT: Update a resource of type LTE Base stations
      * `Body`: Description of the LTE Base stations to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type LTE Base stations
      * `Body`: Description of the LTE Base stations to be deleted in json format (uuid or name is mandatory)

Wimax Base Stations
-------------------
* Description

* `/resources/wimax`
  * GET: List Wimax Base stations
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the Wimax Base stations
          * name: filter the results based on the name of the Wimax Base stations
          * if no parameters are provided all Wimax Base Stations are listed
  * POST: Create a resource of type Wimax Base stations
      * `Body`: Description of the Wimax Base stations to be created in json format
  * PUT: Update a resource of type Wimax Base stations
      * `Body`: Description of the Wimax Base stations to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Wimax Base stations
      * `Body`: Description of the Wimax Base stations to be deleted in json format (uuid or name is mandatory)

* `/status` (optional)
  * GET: Status of AM
  * POST: Not allowed
  * PUT: Not allowed
  * DELETE: Not allowed

* `/version`
  * GET: Information about capabilities of AM implementation
  * POST: Not allowed
  * PUT: Not allowed
  * DELETE: Not allowed

Authentication
==============

Introduction
------------

The REST Interface of NITOS Broker is using https and x509 certificates to authenticate and authorize requests.

* GET requests: Certificates are not mandatory , with the exception of path '/resources/accounts' (this request shows only user's accounts).
* POST requests: Certificates are mandatory. Regular users can only use /resources/leases connected to their own account, administrator priviledges are required in order to create other type of resources.
* PUT requests: Certificates are mandatory. Regular users can only use /resources/leases connected to their own account, administrator priviledges are required in order to update other type of resources.
* DELETE requests: Certificates are mandatory. Regular users can only use /resources/leases connected to their own account, administrator priviledges are required in order to delete other type of resources.

Example of using Certificates
-----------------------------

    $ curl --cert /path/to/certificate/user_cert.pem --key /path/to/private/key/user_key.pkey -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @lease.json -k https://localhost:8001/resources/leases/

Examples
========

List all resources
------------------

    $ curl -k https://localhost:8001/resources
    {
      "resource_response": {
      "resources": [
        {
          "uuid": "7ebfe87e-c5fa-462b-94a5-1b19668c0311",
          "href": "/resources//7ebfe87e-c5fa-462b-94a5-1b19668c0311",
          "name": "root",
          "type": "account",
          "created_at": "2014-03-04T20:05:04+02:00",
          "valid_until": "2014-06-12T21:05:05+03:00",
       ...

List information about the Node with uuid '7ebfe87e-c5fa-462b-94a5-1b19668c0311'
--------------------------------------------------------------------------------

    $ curl -k https://localhost:8001/resources/nodes/?uuid=7ebfe87e-c5fa-462b-94a5-1b19668c0311
    {
      "resource_response": {
        "resources": [
          {
            "uuid": "6a6e20ca-8df5-4c6e-be0c-4f8adc8a1daf",
            "href": "/resources/6a6e20ca-8df5-4c6e-be0c-4f8adc8a1daf",
            "name": "node120",
            "type": "node",
            "interfaces": [
              {
                "uuid": "50593640-48df-4c39-ac05-4b0d8b180978",
                "href": "/resources/50593640-48df-4c39-ac05-4b0d8b180978",
                "name": "node120:if0",
        ...

Create a resource of type Node using a file as input in  json format (footnote 1)
--------------------------------------------------------------------

    $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @node.json -k https://localhost:8001/resources/nodes/
    {
      "resource_response": {
        "resource": {
          "uuid": "52207433-c4ba-468d-9d77-4eb1e8d705e6",
          "href": "/resources/nodes//52207433-c4ba-468d-9d77-4eb1e8d705e6",
          "name": "node123",
          "type": "node",
          "interfaces": [
            {
              "uuid": "3a7b7d67-7dd3-4f0b-a6f3-90b1775821b2",
              "href": "/resources/nodes//3a7b7d67-7dd3-4f0b-a6f3-90b1775821b2",
              "name": "node123:if0",
        ...

Update a resource of type Node using json as input. 
---------------------------------------------------

    $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X PUT -d '{"uuid":"52207433-c4ba-468d-9d77-4eb1e8d705e6","hostname":"omf.nitos.node122"}' -k https://10.64.44.12:8001/resources/nodes/
    {
      "resource_response": {
        "resource": {
          "uuid": "52207433-c4ba-468d-9d77-4eb1e8d705e6",
          "href": "/resources/nodes//52207433-c4ba-468d-9d77-4eb1e8d705e6",
          "name": "node123",
          "type": "node",
          "exclusive": true,
          "hostname": "omf.nitos.node123",
        ...

Delete a resource of type Node using json as input. 
---------------------------------------------------

    $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X DELETE -d '{"uuid":"7196ea8e-003c-4afe-9120-4b1057b5d19a"}' -k https://localhost:8001/resources/nodes/
    {
      "resource_response": {
        "response": "OK",
        "about": "/resources/nodes/"
      }
    }
      ...

More examples
=============

The following examples assume that the Authentication/Authorization mechanism is disabled. Follow Chapter 2 on how to send requests 
using certificates.

Channels
--------
    GET   : $ curl -k https://localhost:8001/resources/channels
    POST  : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @channel.json -k https://localhost:8001/resources/channels/
    PUT   : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X PUT -d '{"uuid":"aeeab139-68cc-4e0e-b6b4-fb4fac8ab0e0","frequency":"2.417GHz"}' -k https://10.64.44.12:8001/resources/channels/
    DELETE: $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X DELETE -d '{"uuid":"aeeab139-68cc-4e0e-b6b4-fb4fac8ab0e0"}' -k https://localhost:8001/resources/channels/

Leases
--------
    GET   : $ curl -k https://localhost:8001/resources/leases
    POST  : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @lease.json -k https://localhost:8001/resources/leases/
    PUT   : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X PUT -d '{"uuid":"e026ad2d-07bf-48e2-a39e-aae29a7d86cd","frequency":"2.417GHz"}' -k https://10.64.44.12:8001/resources/leases/
    DELETE: $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X DELETE -d '{"uuid":"e026ad2d-07bf-48e2-a39e-aae29a7d86cd"}' -k https://localhost:8001/resources/leases/

Chassis managers Cards
---------------------
    GET   : $ curl -k https://localhost:8001/resources/cmc
    POST  : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @cmc.json -k https://localhost:8001/resources/cmc/
    PUT   : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X PUT -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e","frequency":"2.417GHz"}' -k https://10.64.44.12:8001/resources/cmc/
    DELETE: $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X DELETE -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e"}' -k https://localhost:8001/resources/cmc/

Switches
---------------------
    GET   : $ curl -k https://localhost:8001/resources/switces
    POST  : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @switches.json -k https://localhost:8001/resources/switches/
    PUT   : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X PUT -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e","frequency":"2.417GHz"}' -k https://10.64.44.12:8001/resources/switches/
    DELETE: $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X DELETE -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e"}' -k https://localhost:8001/resources/switches/

LTE Base Stations
---------------------
    GET   : $ curl -k https://localhost:8001/resources/lte
    POST  : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @lte.json -k https://localhost:8001/resources/lte/
    PUT   : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X PUT -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e","frequency":"2.417GHz"}' -k https://10.64.44.12:8001/resources/lte/
    DELETE: $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X DELETE -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e"}' -k https://localhost:8001/resources/lte/

Wimax Base Stations
---------------------
    GET   : $ curl -k https://localhost:8001/resources/wimax
    POST  : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST -d @wimax.json -k https://localhost:8001/resources/wimax/
    PUT   : $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X PUT -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e","frequency":"2.417GHz"}' -k https://10.64.44.12:8001/resources/wimax/
    DELETE: $ curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X DELETE -d '{"uuid":"040f9b96-7aff-438a-919d-0e1e12a2d93e"}' -k https://localhost:8001/resources/wimax/

Footnotes:
==========

(1) example of node.json

    {
      "name": "node2",
      "hostname": "omf.nitos.node2",
      "interfaces": [
        {
          "name": "node2:if0",
          "role": "control",
          "mac": "00-03-1d-0d-4b-96",
          "ip": {
            "address": "10.0.1.102",
            "netmask": "255.255.255.0",
            "ip_type": "ipv4"
          }
        },
        {
          "name": "node2:if1",
          "role": "experimental",
          "mac": "00-03-1d-0d-4b-97"
        }
      ],
      "cmc": {
        "name": "node2:cm",
        "mac": "09:A2:DA:0D:F1:01",
        "ip": {
          "address": "10.1.0.102",
          "netmask": "255.255.255.0",
          "ip_type": "ipv4"
        }
      }
    }

(2) There are some particularities in the parameters of GET commands:
  
  1. The existence of at least one of 'uuid' or 'name' parameters is mandatory. 
  2. 'name' parameter is not unique in our models, thus the first of the results is returned. Please use 'uuid' instead when it is possible.
