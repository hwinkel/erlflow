#!/bin/sh
/opt/local/bin/erlc erlflow.erl 
/opt/local/bin/erlc erlflow_net.erl
/opt/local/bin/erlc erlflow_xpdl_parser.erl
/opt/local/bin/erlc erlflow_pnml_parser.erl   
/opt/local/bin/erl  -s erlflow start 
