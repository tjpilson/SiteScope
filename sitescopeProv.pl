#!/usr/bin/perl

# ---------------------------------------------
# sitescopeProv.pl
# Tim Pilson
# 10/25/2013
#
# Provision HP SiteScope templates via SOAP API
#
# Requires: sitescopeTemplateDef.json
# ---------------------------------------------

#use SOAP::Lite 'trace', 'debug';  ## for debug
use SOAP::Lite; 
use Term::ReadKey;
use JSON::XS;
use Getopt::Long;

## Parms (required)
## ----------------
my $templateFile   = "sitescopeTemplateDef.json";
my @url;
my ($templateFolder,$template,$destHome,$destGroup);
my ($jsonText,$jsonArray);
my @parmsReq;
my %parmsIn;

## Usage
## -----
my $usage = "Usage: $0 [options]\n";
$usage   .= "Options: --showTemplates,       Display configured templates.\n";
$usage   .= "         --template,            Template to invoke.\n";
$usage   .= "         --destHome,            Location for alert home (base folder).\n";
$usage   .= "         --destGroup,           Location for alert group (group folder).\n";
$usage   .= "         --parms,               field:value pairs to pass to the template. (ex. application_ip:10.10.10.10)\n";
$usage   .= "                                Multiple parms may be supplied (--parms application_ip:10.10.10.10 --parms field:value)\n";
$usage   .= "         --help,          -[hH] Print this help message.\n";

## Set Command Line Options
GetOptions ('showTemplates' => \&showTemplates,
            'template=s'    => \$template,
            'destHome=s'    => \$destHome,
            'destGroup=s'   => \$destGroup,
            'parms=s'       => \@parms,
            'help'          => sub { print $usage; exit;   },
            'h'             => sub { print $usage; exit;   }
) or die($usage);

## Build hash of input parms
foreach my $parms (@parms) {
  my($field, $value) = split(/:/,$parms); 
  $parmsIn{$field} = "$value";
}

## Required parms
if ( $field{template} eq ""  ) { die "ERROR: missing parameter --template\n";  }
if ( $field{destHome} eq ""  ) { die "ERROR: missing parameter --destHome\n";  }
if ( $field{destGroup} eq "" ) { die "ERROR: missing parameter --destGroup\n"; }

## Get Credentials for Authentication
## ----------------------------------
print "Enter Username: ";
chomp(my $username = <STDIN>);

print "Enter Password: ";
ReadMode('noecho'); ## turn off echo for grabbing password
chomp(my $password = <STDIN>);
ReadMode(0);
print "\n";

## SOAP Environment
## ----------------
$SOAP::Constants::PREFIX_ENV = "soapenv";  ## Set the SOAP header to "soapenv" instead of "soap"

sub showTemplates {
  ## --------------------------------
  ## Display templates from JSON file
  ## --------------------------------
  my $jsonText;

  open(JSON,"$templateFile") || die "ERROR: can't open input file, $templateFile\n";
  while(<JSON>) {
    chomp;
    $jsonText .= $_;
  }

  my $jsonArray = decode_json($jsonText);

  foreach my $item (@$jsonArray) {
    if ( $item->{url} ) {
      for my $fields (@{$item->{url}}) {
        print "Server: $fields->{server}\n";
      }
    } elsif ( $item->{templateFolder} ) {
      print "$item->{templateFolder}\n";
      print "  $item->{template}\n";
      for my $fields (@{$item->{config}}) {
        print "    \-\>Required Field: $fields->{fieldName}\n";
      }
    }
    print "\n";
  }

  close(JSON);
  exit;
}

sub validateTemplate {
  ## --------------------------------
  ## Display templates from JSON file
  ## --------------------------------
  my $jsonText;

  open(JSON,"$templateFile") || die "ERROR: can't open input file, $templateFile\n";
  while(<JSON>) {
    chomp;
    $jsonText .= $_;
  }

  my $jsonArray = decode_json($jsonText);

  my $match = 0;
  my $missingFields = 0;

  print "Validating data with template... ";

  ## Loop through template definitions
  foreach my $item (@$jsonArray) {
    if ( $template eq $item->{template} ) {  ## Look for a matching template name
      $match = 1;
      $templateFolder = $item->{templateFolder};
      for my $fields (@{$item->{config}}) {  ## Build an array of required fields
        push (@parmsReq ,"$fields->{fieldName}");
      }
    }
  }

  ## Determine whether we found a match
  if ( $match == 1 ) {
    my @missing;
    foreach my $parmsReq (@parmsReq) {  ## from template
      if ( $parmsIn{"$parmsReq"} eq "" ) {  ## from command line parms
        $missingFields = 1;
        push(@missing, $parmsReq);
      }
    } 

    if ( $missingFields == 1 ) {
      print "FAIL ( missing fields: ";
      foreach my $m (@missing) {  ## show missing fields
        print "$m ";
      }
      print ")\n";
      exit 1;
    } else {
      print "PASS\n";
    }
  } else {
    print "FAIL (no templates found)\n";
    exit 1;
  }

  ## Loop through template for servers
  foreach my $item (@$jsonArray) {
    if ( $item->{url} ) {  ## Look for servers
      for my $fields (@{$item->{url}}) {  ## Build an array of servers fields
        push (@url ,"$fields->{server}");
      }
    }
  }

  ## Validate that we have at least one server to deploy to
  my $totalServers = @url;
  if ( $totalServers < 1 ) {
    print "ERROR: no servers listed\n";
    exit 1;
  }

  close(JSON);
}

&validateTemplate();

## Construct SOAP Call
## -------------------
foreach my $url (@url) {
  print "Submitting request to: $url\n";
  my $soap = new SOAP::Lite                                             
    uri   => "SiteScope",
    proxy => "$url";

  ## Use these options if SSL and certificates are not valid
  #$soap->proxy->ssl_opts( SSL_verify_mode => 0 );  ## Turn off SSL certficate verification
  #$soap->proxy->ssl_opts( verify_hostname => 0 );  ## Turn off SSL hostname verification

  ## Call "deploySingleTemplateEx" method
  ## ------------------------------------
  my $method = SOAP::Data->name('deploySingleTemplateEx')
      ->attr({'soapenv:encodingStyle' => 'http://schemas.xmlsoap.org/soap/encoding'});

  ## "deploySingleTemplateEx" structure
  ## ----------------------------------
  my @params = SOAP::Data->name('in0' =>
      \SOAP::Data->value(
                         SOAP::Data->name('item' => "$templateFolder")
                           ->attr({'xsi:type' => 'xsd:string'}),
                         SOAP::Data->name('item' => "$template")
                           ->attr({'xsi:type' => 'xsd:string'})
                        ))
       -> attr({'xsi:type' => 'con:ArrayOf_xsd_string',
                'soapenc:arrayType' => 'xsd:string[]'});

  my @fieldValueCombo;

  ## Build the XML string
  foreach my $key (keys %parmsIn) {
    ## Build key data object
    my $field = SOAP::Data->name('key' => "$key")->attr({'xsi:type' => 'xsd:string'}),SOAP::Data->name('value' => "$parmsIn{$key}")->attr({'xsi:type' => 'xsd:string'});
    ## Build value data object
    my $value = SOAP::Data->name('value' => "$parmsIn{$key}")->attr({'xsi:type' => 'xsd:string'});
    ## Build data object array
    push (@fieldValueCombo, SOAP::Data->name('item' => \SOAP::Data->value($field,$value))->attr({'xsi:type' => 'x-:mapItem'}));
  }

  push (@params, SOAP::Data->name('in1' =>
      \SOAP::Data->value(@fieldValueCombo))
      ->attr({'xsi:type' => 'x-:Map',
              'xmlns:x-' => 'http://xml.apache.org/xml-soap'})); 

## Data Structure for reference
## ----------------------------
#  push (@params, SOAP::Data->name('in1' =>
#      \SOAP::Data->value(
#                         SOAP::Data->name('item' =>
#                             \SOAP::Data->value(
#                                                SOAP::Data->name('key' => "$parm1Key")
#                                                  ->attr({'xsi:type' => 'xsd:string'}),
#                                                SOAP::Data->name('value' => "$parm1Value")
#                                                  ->attr({'xsi:type' => 'xsd:string'})
#                                               )
#                                         )
#                               ->attr({'xsi:type' => 'x-:mapItem'}),
#                         SOAP::Data->name('item' =>
#                             \SOAP::Data->value(
#                                                SOAP::Data->name('key' => "$parm2Key")
#                                                  ->attr({'xsi:type' => 'xsd:string'}),
#                                                SOAP::Data->name('value' => "$parm2Value")
#                                                  ->attr({'xsi:type' => 'xsd:string'})
#                                               )
#                                         )
#                               ->attr({'xsi:type' => 'x-:mapItem'})
#                         ))
#      ->attr({'xsi:type' => 'x-:Map',
#              'xmlns:x-' => 'http://xml.apache.org/xml-soap'})); 

  push (@params, SOAP::Data->name('in2' =>
      \SOAP::Data->value(
                         SOAP::Data->name('item' => "$destHome")
                           ->attr({'xsi:type' => 'xsd:string'}),
                         SOAP::Data->name('item' => "$destGroup")
                           ->attr({'xsi:type' => 'xsd:string'})
                        ))
       -> attr({'xsi:type' => 'con:ArrayOf_xsd_string',
                'soapenc:arrayType' => 'xsd:string[]'}));

  push (@params, SOAP::Data->name('in3')
      ->value("$username")
      ->attr({'xsi:type' => 'xsd:string'}));

  push (@params, SOAP::Data->name('in4')
      ->value("$password")
      ->attr({'xsi:type' => 'xsd:string'}));

  #print $soap->call($method => @params)->result;
  my $result = $soap->call($method => @params);

  unless ($result->fault) {
    print "** Success **\n";
    print "** $url **\n";
    print $result->result();
  } else {
    print "** ERROR **\n";
    print "** $url **\n";
    print "  Fault Code: ", $result->faultcode, "\n";
    print "Fault String: ", $result->faultstring, "\n";
  }
}
