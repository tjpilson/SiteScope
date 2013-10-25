SiteScope
=========

SiteScope template deploy program

- sitescopeProv.pl
- sitescopeTemplateDef.json

HP SiteScope provides a SOAP-based API for managing the server and configuration.  Documentation for the API is sparse.  This program is intended to provide a quick deployment method for new monitors based on existing templates.

Pre-Req
  - SOAP::Lite (crypt, etc.)
  - JSON::XS
  - You should already have an existing template created on the SiteScope server

Configuring sitescopeTemplateDef.json
  - List all SiteScope servers intended for deployment in the server: fields.  Add server: fields as needed, no limits.  These server listings will be processed serial.
  
  - Configure the structure of the template into the sitescopeTemplateDef.json file.  Use the existing structure as an example, update/add/remove as needed.
  
  - The .json file is used to validate the command line input against the template structure prior to issuing the call to SiteScope.
  
Configuring sitescopeProv.pl
  - In general, no changes should be needed for the main program.
  
  - If you are using SSL and you don't have signed certs, there are 2 comments SSL options that you may uncomment to ignore the certificate errors.
  
  - If you need to see the structure of the SOAP/XML via STDOUT, uncomment the debug line for the SOAP::Lite module.
  
  - --showTemplates will process the .json file and display the template parameters
  - --help for command line requirements
