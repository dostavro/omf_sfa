Objective
=========

This is the reference document for the REST API provided by NITOS Broker. This REST API can be used by developers who need access to NITOS Broker inventory with other standalone or web applications, and administrators who want to script interactions with the NITOS servers. At the moment Resource Discovery and Resource Reservation are possible through the REST interface.

Because the REST API is based on open standards, you can use any programming language to access the API. 

Table of contents
================= 

1. API
2. Examples
3. More Examples
4. Footnotes

API
===

* `/resources`
  * GET: List all resources
  * POST: Not allowed
  * PUT: Not allowed
  * DELETE: Not allowed

* `/resources/nodes`
  * GET: List Nodes
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the node
          * name: filter the results based on the name of the node
          * if no parameters are provided all Nodes are listed
  * POST: Create a resource of type Node
      * `Body`: Description of the Node to be created in json format
  * PUT: Update a resource of type Node
      * `Body`: Description of the Node to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Node
      * `Body`: Description of the Node to be deleted in json format (uuid or name is mandatory)

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

* `/resources/cmc`
  * GET: List Chasis Manager Cards
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

* `/resources/openflow`
  * GET: List of Openflow Switches
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the Openflow Switch
          * name: filter the results based on the name of the Openflow Switch
          * if no parameters are provided all Openflow Switchs are listed
  * POST: Create a resource of type Openflow Switch
      * `Body`: Description of the Openflow Switch to be created in json format
  * PUT: Update a resource of type Openflow Switch
      * `Body`: Description of the Openflow Switch to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Openflow Switch
      * `Body`: Description of the Openflow Switch to be deleted in json format (uuid or name is mandatory)

* `/resources/lte`
  * GET: List LTE basestations
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the LTE Basestations
          * name: fiLTE Basestationsr the results based on the name of the LTE Basestations
          * if no parameters are provided all LTE Basestationss are listed
  * POST: Create a resource of type LTE Basestations
      * `Body`: Description of the LTE Basestations to be created in json format
  * PUT: Update a resource of type LTE Basestations
      * `Body`: Description of the LTE Basestations to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type LTE Basestations
      * `Body`: Description of the LTE Basestations to be deleted in json format (uuid or name is mandatory)

* `/resources/wimax`
  * GET: List Wimax Basestations
      * `Parameters`
          * uuid: filter the results based on the universal unique id of the Wimax Basestations
          * name: filter the results based on the name of the Wimax Basestations
          * if no parameters are provided all Wimax Basestationss are listed
  * POST: Create a resource of type Wimax Basestations
      * `Body`: Description of the Wimax Basestations to be created in json format
  * PUT: Update a resource of type Wimax Basestations
      * `Body`: Description of the Wimax Basestations to be updated in json format (uuid or name is mandatory)
  * DELETE: Delete a resource of type Wimax Basestations
      * `Body`: Description of the Wimax Basestations to be deleted in json format (uuid or name is mandatory)

* `/status` (optional)
  * GET: Status of AM
  * POST: Not allowed
  * PUT: Not allowed
  * DELETE: Not allowed

* `/version`
  * GET: Information about capabilites of AM implementation
  * POST: Not allowed
  * PUT: Not allowed
  * DELETE: Not allowed

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

Chasis managers Cards
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
  
  1. The existance of at least one of 'uuid' or 'name' parameters is mandatory. 
  2. 'name' parameter is not unique in our models, thus the first of the results is returned. Please use 'uuid' instead when it is possible.
