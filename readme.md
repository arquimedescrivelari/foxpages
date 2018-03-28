# Fox Pages Server 3.0

## What is this?

Fox Pages Server (FPS) is a multithreaded HTTP, HTTPS, and FastCGI server for Visual FoxPro.

With Fox Pages Server you can develop, debug, and distribute web content and applications by using Visual FoxPro.

Fox Pages Server does not allow Visual FoxPro code to run on the Internet. This is why it is necessary to know the language and development tools for internet that will be used, for example: HTML, CSS, Javascript, JQuery, Dojo etc.

## Requirements
Microsoft Visual FoxPro 9.0

## Distribution
Fox Pages Server is distributed in two modes: development mode and distribution mode.

### Development Mode
In this mode, the server works by default in singlethread, so that it is possible to use Visual FoxPro for the development of FXP pages. The development mode requires Visual FoxPro installed.

### Distribution mode
In this mode, the server works in multithread, providing extreme processing gain. The distribution mode requires the Visual FoxPro runtime installed.

In development and distribution modes, any error is recorded in tables in the LOGS folder allowing detection and tracing of errors.

## Before installing
Do not attempt to do the installation procedure in development and deployment mode on the same computer. If this is necessary, run the install.bat file from distribution mode, because it will register the components will also create the Windows Service. Configure the development mode to use an IP or port other than the distribution mode.

### Installation in development mode
1) Locate the Development folder.
2) Run the install.bat file. (To install on Windows 10 run using Command prompt as administrator)
3) Run the desired protocol program, located in the SERVERS folders, HTTP.FXP is the default.

The Visual FoxPro debugging will only work in development mode because it is impossible to display any interface when the code runs in a multithreaded DLL. Any attempt will generate errors or freeze the thread.

### Installation in distribution mode
1) Locate the Distribution folder.
2) Run the install.bat file. (To install on Windows 10 run using Command prompt as administrator)

### Security Tip
It is not recommended to leave the .HTML files with their .FXP compiled in the same folder of the server, they can be downloaded if the extension is changed in the webbrowser.

## Before starting
Fox Pages uses port 80 as default for HTTP, so before starting it is necessary to stop any service that is using port 80 (IIS, Apache, etc.) or change the port used in the HTTP.PRG program located in the SERVERS folder on the mode, or in the PORT field of the SERVERS.DBF table located in the DATA folder in distribution mode.

Other protocols follow the same procedure.

## Setting up HTTP and HTTPS servers

The FPS.DBC database located in the DATA folder stores the configuration of the servers.
The documentation of the tables and their respective fields can be found in the FPS.HTML file.
The relationship between the tables can be viewed in the FPS.JPG image.

### Servers
The servers are responsible for the connections of the clients (IE, Chrome, Firefox, etc) and servers (NGinX, etc).

Each server runs on a separate thread and can, depending on the configuration of the IP number, listen on the same port. In case of conflicts of IP numbers and ports the first configured server will receive the connections.

Configure the servers by adding, modifying, or deleting records in the SERVERS.DBF table.

Each protocol defaults to a specific port:

- HTTP must be configured for port 80.
- HTTPS must be configured for port 443.

FastCGI is usually used in communication between servers, there is no default port.

### Sites
Sites establish a relationship between a HOSTNAME (e.g. www.example.com) with the folder where the site files are located (e.g. c:\sites\example), and configures your home page (e.g. index.fxp, index. php, index.html, etc).

Configure the sites by adding, modifying, or deleting records in the SITES.DBF table.

If the HOSTNAME field is filled with "*" all HOSTNAMES will be related to the same folder.

In this same table we configure redirects by filling in the REDIRECT field with the full address of the redirection. This feature is very useful when we need to, for example, redirect unsecured connections (HTTP) to a secure server (HTTPS), this is done for example by filling in the REDIRECT field of the site www.example.com from the unsafe server (HTTP) with "https://www.example.com", the secure site address (HTTPS).

### Gateways
Gateways are used to send requests to other development tools. PHP has been the only one tested so far, while any tool that supports FastCGI must be compatible.

Configure the gateways by adding, modifying, or deleting records in the GATEWAYS.DBF table.

The only protocol supported is FastCGI.

Gateways work in a similar way to Sites, establishing a relationship between a HOSTNAME (e.g. www.example.com) with the folder where the site files are located (e.g. c:\sites\example). The difference lies in the fact that the contents of the URI field (e.g. ".php") must be contained in the request URI so that it is sent to the gateway.

Based on these criteria, Fox Pages Server transforms the HTTP request into a FastCGI request and sends it to the configured server. The FastCGI response is then transformed into an HTTP response and sent to the client.

Requests that do not meet the criteria will be processed by the HTTP server, so for each Gateway a Site must be configured.

### Security
Not all folders and files contained within a site must be accessible. Databases, tables, and programs are some examples.

Fox Pages Server has the access control system that allows authorized access or complete blocking of site folders.

Access control is configured by adding, modifying, or deleting records from tables REALMS.DBF, USERS.DBF, and REALMUSER.DBF

The REALM.DBF table sets the access settings for the site folders.

The USERS.DBF table defines the users who will have access to the folders.

The REALMUSER.DBF table lists users with folders.

## Setting up FastCGI servers

Fox Pages Server can be configured to be used through other web servers using the FastCGI protocol.

The nginx.conf file located in the NGINX folder is a configuration template for the NGinX server. Copy this file to the CONF folder where NGinX is installed and configure the ROOT parameter with the full path of the site files folder.

To configure Fox Pages Server to use the FastCGI protocol, fill the TYPE field of the SERVERS.DBF table with "FCGI".

As all information required for the processing of the request must be provided by the web server, there is no need to configure sites, gateways or security.

## Accessing the first time
After server startup use any browser by typing in the configured server address (e.g. http://localhost, https://localhost).

## Demo site
To enter the demo site there are two accounts, one for the client and one for the representative.

The customer's account access the customer area. To access, use the email cliente@teste.com.br and the password 123456.

The representative account starts an application for customer and order registration. To access use the email representante@teste.com.br and the password 123456.

### Dynamic pages
A dynamic page uses a server-side programming language in the development of a website or Internet application.

The Fox Server Pages makes it possible to develop these pages using the resources of static pages of developments (eg HTML, CSS, Javascript) with Visual Fox Pro programming features (eg console language programming, database).

In Fox Pages Server an HTML page is converted into a PRG program file and compiled into a compiled FXP file, so page processing is extremely fast and does not have the limitations of using another interpreter.

In the compilation process only the code between the `<FPS>` and `</FPS>` tags will be processed, the rest will be sent as static content.

An example of static content.
```
<HTML>
Hello World
</HTML>
```
Result:

Hello World  

An example of a program as static content because of the missing `<FPS>` and `</FPS>` tags.
```
<HTML>
for nCounter = 1 to 3
    Hello World
next
</HTML>
```
Result:

for lnCounter = 1 to 3  
    Hello World  
next  

An example using the tags `<t>` and `<e>`, they are responsible for sending static texts and expressions.
```
<HTML>
    <FPS>
       cWorld = "World"
       for nCounter = 1 to 3
          <t>Hello </t><e>cWorld</e><br>
       next
    </FPS>
</HTML>
```
Result:

Hello World  
Hello World  
Hello World  

An example using other HTML tags combined programming.
Every line started with an HTML tag or by the `<t>` tag is sent.
```
<HTML>
    <FPS>
       <b>Begin</b><br><br>

       cWorld = "World"
       for nCounter = 1 to 3
          <b><t>Hello </t><e>cWorld</e></b><br>
       next

       <br>
       <t>End</t>
    </FPS>
</HTML>
```
Result:

Begin  

Hello World  
Hello World  
Hello World  

End  

## RESTfull Applications
REST (Representational State Transfer) is an architectural style that advocates that Web applications should use HTTP as originally intended, where GET, PUT, POST and DELETE requests should be used for query, change, creation, and deletion, respectively.

Fox Pages Server processes a request as REST whenever the Accept header is "application/json".

More details can be found in the application available on the demo site when signing in with the representative account.

## Incompatibility with version 2.0
For FastCGI protocol support, the processing of Request and Response object properties has been changed.

In version 2.0 headers with hyphens (e.g. Accept-Encoding) had the hyphen removed (e.g. AcceptEnconding). In version 3.0 these hyphens are changed to underline (e.g. Accept_Encoding).

## Licensing
Fox Pages Server is free and open source software. The license is located in the LICENSE file.

The component used for the connections is the Socketwrench of the company Catalyst Development Corporation (www.sockettools.com).

This component is distributed in the free and commercial versions. The free version does not support secure connections (SSL/TLS).

The development version of Fox Pages Server is configured to use the free version of SocketWrench. This will be a limitation only if the use of secure connections in the development environment is required.

To use the commercial version of SocketWrench you must purchase a license, as Fox Pages Server does not include this license.

The version configuration used, free or commercial, or the version of SocketWrench, is located in the FOXPAGES.H file of the CORE folder, as follows:

//SOCKETWRENCH  
#DEFINE USEFREEVERSION  
#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.6"  

//SocketWrench 8  
//#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.8"  
//#DEFINE CSWSOCK_LICENSE_KEY	"INSERT YOUR RUNTIME LICENSE HERE"  

//SocketWrench 9  
//#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.9"  
//#DEFINE CSWSOCK_LICENSE_KEY	"INSERT YOUR RUNTIME LICENSE HERE"  

You need to recompile the project after you change these settings.

## Credits

Multithreading - VFP2C32T.FLL - Christian Ehlscheid  
Compression - VFPCompression - Craig Boyd  
Encryption - VFPEncryption - Craig Boyd  
JSON Parser - Modified library version - Craig Boyd  
Sockets - Socketwrench - Catalyst Development  

## Donate
If this project is usefull to you, consider a donation.

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=XEXS5TAWJG7YL)