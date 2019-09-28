
	mod_filter_msg - Custom Modules for ejabberd hook filter packet
	Author: drey


This module allows advanced ejabberd administrators to filter all messages
transaction from ejabberd server and send to particular local node-js restapi.


	BASIC CONFIGURATION
	===================

Add the module to your ejabberd.yml, on the modules section:
modules:
  mod_filter_msg: {}


	TASK SYNTAX
	===========

...:
* get groupchat and singlechat messages tuple format.
* throw to rest api node js.
* node js will receive the request data and save to somewhere else.
