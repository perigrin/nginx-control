#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Data::Visitor::Callback;
use Parse::RecDescent;

$\="\n";

$::RD_ERRORS = 1; # Make sure the parser dies when it encounters an error
$::RD_WARN   = 1; # Enable warnings. This will warn on unused rules &c.
$::RD_HINT   = 1; # Give out hints to help fix problems.
#$::RD_TRACE  = 1; # if defined, also trace parsers' behaviour

our %config;

# Create and compile the source file
my $parser = Parse::RecDescent->new(q(

OPERATOR    : /\=\=|\!\=|\=\~|\!\~/
IDENTIFIER  : /[a-zA-Z-]+/
DIGITS      : /\d+/

## ---------------------------------------------------------
## misc ...

quoted_string    : <perl_quotelike>
                 { $return = $item[1]->[2] }

## ---------------------------------------------------------
## parameters

parameter_value  : DIGITS | quoted_string
                 { $return = bless [ $item[1] ] => 'ParameterValue' }

parameter_key    : IDENTIFIER '.' IDENTIFIER
                 { $return = bless [ $item[1], $item[3] ] => 'ParameterKey' }

parameter_pair   : quoted_string '=>' parameter_value ','
                 { $return = bless [ $item[1], $item[3] ] => 'ParameterPair' }

scalar_parameter : parameter_key '=' parameter_value
                 { $return = bless [ $item{ parameter_key }, $item{ parameter_value } ] => 'Parameter' }

array_parameter  : parameter_key '=' '(' parameter_value(s /,/) ')'
                 { $return = bless [ $item{ parameter_key }, $item[4] ] => 'Parameter' }                 
                 
hash_parameter   : parameter_key '=' '(' parameter_pair(s) ')'
                 { $return = bless [ $item{ parameter_key }, $item[4] ] => 'Parameter' }                 

parameter        : hash_parameter | array_parameter | scalar_parameter

## ---------------------------------------------------------
## conditional expressions

field            : '$' IDENTIFIER '[' quoted_string ']'
                 { $return = bless [ $item[2] , $item[4] ] => 'Field' }

conditional_expr : field OPERATOR parameter_value
                 { $return = bless [ $item{field}, $item{OPERATOR}, $item{parameter_value} ] => 'ConditionalExpr' }

## ---------------------------------------------------------
## put things together

block_header     : conditional_expr | 'config'

block_content    : parameter | block

block            : block_header '{' block_content(s) '}'
                 {  $return = bless [ $item{ block_header }, $item[3] ] => 'Block' } 

config           : <skip:qr/(\s+|#.*\n)*/> block 

));

my $config_string = join "" => `lighttpd -p -f lighttpd.dev.conf`;
print $config_string;

my $config_ast = $parser->config($config_string);

warn Dumper $config_ast;

my $v = Data::Visitor::Callback->new(
    ParameterKey    => sub { print "Got ParameterKey" },
    Parameter       => sub { print "Got Parameter" },    
    Block           => sub { print "Got Block" },
    Field           => sub { print "Got Field" },    
    ConditionalExpr => sub { print "Got ConditionalExpr" },    
    object          => "visit_ref", # recurse        
);

$v->visit( $config_ast );


