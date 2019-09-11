#INCLUDE ..\core\foxpages.h

*--- Change window caption
_VFP.Caption = FOX_PAGES_VERSION+" - HTTP"

*--- Compile programs
compile ..\core\*.prg

*--- Create server
PUBLIC FPServer
FPServer = newobject("Server","..\core\server.prg")

*--- Set ID
FPServer.ServerID = "0001"

*--- Set name
FPServer.ServerName = FOX_PAGES_VERSION

*--- Set requests log
FPServer.LogRequests = 1

*--- Set processing log level
FPServer.LogLevel = 3

*--- Set development mode
FPServer.StartMode = 0

*--- Server start
FPServer.Start()

*--- Set server type
FPServer.Type = "HTTP"

*--- Configure IP and Port (HTTP)
if !FPServer.Listen('0.0.0.0',80)
	messagebox("Can not start listenner.",MB_OK+MB_ICONSTOP,"Error")
endif

************************************************************************
* The lines bellow are used to debug the destroy events of the objects *
************************************************************************

*!*	*--- Read events
*!*	set step on

*!*	*--- Server stop listen
*!*	FPServer.StopListen()

*!*	*--- Server stop
*!*	FPServer.Stop()

*!*	*--- Release server
*!*	RELEASE FPServer