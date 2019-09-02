******************************************************************************************
* Log class
***********
DEFINE CLASS Log AS CUSTOM
	*--- Hide class properties
	HIDDEN BaseClass,ClassLibrary,Class,Comment,ControlCount,Controls,Height,HelpContextID,Left,Objects,Parent,ParentClass,Picture,Tag,Top,WhatsThisHelpID,Width

	Server   = ""
	Thread   = ""
	Process  = ""
	Event    = ""
	Date     = {}
	Time     = ""
	Seconds  = 0
	Peer     = ""
	Request  = ""
	Host     = ""
	Method   = ""
	URI      = ""
	Code     = ""
	Response = ""
	Bytes    = 0
	Interval = 0
	Message  = ""

	PROCEDURE Reset()
		*--- Reset log info
		This.Server   = This.Parent.ServerID
		This.Thread   = transform(This.Parent.ThreadIndex,"@L 9999")
		This.Process  = ""
		This.Event    = ""
		This.Date     = {}
		This.Time     = ""
		This.Seconds  = seconds()
		This.Peer     = ""
		This.Host     = ""
		This.Request  = ""
		This.Method   = ""
		This.URI      = ""
		This.Code     = ""
		This.Response = ""
		This.Bytes    = 0
		This.Interval = 0
		This.Message  = ""
	ENDPROC

	PROCEDURE Add(Level AS Integer, Event AS String, Message AS String)
	LOCAL lcAlias,lnSeconds,lnInterval,lcPeerAddress,lcLogFile
		*--- Seconds
		m.lnSeconds = seconds()

*!*			*--- Update seconds
*!*			if inlist(This.Event,"Process")
*!*				This.Seconds = m.lnSeconds
*!*			endif

		*--- Check requests log and log level
		if m.Level > This.Parent.LogLevel AND This.Parent.LogRequests = 0 AND !inlist(This.Event,"Gateway.FCGI.Sent","Gateway.HTTP.Sent","Web.FCGI.Sent","Web.HTTP.Sent")
			return
		endif

		*--- Check parameters
		if empty(m.Message)
			m.Message = ""
		endif

		*--- Event
		This.Event = m.Event

		*--- New process ID
		if empty(This.Process) AND inlist(This.Event,"Accept","Process") && !inlist(This.Event,"Destroy","Disconnect")
			This.Process = substr(sys(2015),3)
		endif

		*--- Date
		This.Date = date()

		*--- Time
		This.Time = This.Sec2Time(m.lnSeconds)

		*--- Interval
		if !empty(This.Seconds) AND !inlist(This.Event,"Accept","Destroy","Disconnect","Error")
			This.Interval = (m.lnSeconds - (This.Seconds + iif(This.Seconds > m.lnSeconds,86400,0))) * 1000
		endif

		*--- Peer address
		if type("This.Parent.Socket.PeerAddress") = "C" and !empty(This.Parent.Socket.PeerAddress)
			This.Peer = This.Parent.Socket.PeerAddress+":"+alltrim(str(This.Parent.Socket.PeerPort))
		endif

		*--- Request
		do case
		case type("This.Parent.Gateway.Request.Data") = "C"
			This.Request = This.Parent.Gateway.Request.Data
		case type("This.Parent.Web.Request.Data") = "C"
			This.Request = This.Parent.Web.Request.Data
		endcase

		*--- Method
		do case
		case type("This.Parent.Gateway.Request.Method") = "C"
			This.Method = This.Parent.Gateway.Request.Method
		case type("This.Parent.Web.Request.Method") = "C"
			This.Method = This.Parent.Web.Request.Method
		endcase

		*--- Host name
		do case
		case type("This.Parent.Gateway.Request.Host") = "C"
			This.Host = This.Parent.Gateway.Request.Host
		case type("This.Parent.Web.Request.Host") = "C"
			This.Host = This.Parent.Web.Request.Host
		endcase

		*--- URI
		do case
		case type("This.Parent.Gateway.Request.Document_URI") = "C"
			This.URI = This.Parent.Gateway.Request.Document_URI
		case type("This.Parent.Web.Request.Document_URI") = "C"
			This.URI = This.Parent.Web.Request.Document_URI
		endcase

		*--- Bytes
		do case
		case type("This.Parent.Gateway.Response.Bytes") = "N"
			This.Bytes = This.Parent.Gateway.Response.Bytes
		case type("This.Parent.Web.Response.Bytes") = "N"
			This.Bytes = This.Parent.Web.Response.Bytes
		endcase

		*--- Reponse code
		do case
		case type("This.Parent.Gateway.Response.Status_Code") = "C"
			This.Code = This.Parent.Gateway.Response.Status_Code
		case type("This.Parent.Web.Response.Status_Code") = "C"
			This.Code = This.Parent.Web.Response.Status_Code
		endcase

		*--- Reponse
		do case
		case type("This.Parent.Gateway.Response.Header") = "C"
			This.Response = This.Parent.Gateway.Response.Header
		case type("This.Parent.Web.Response.Header") = "C"
			This.Response = This.Parent.Web.Response.Header
		endcase

		*--- Message
		This.Message = m.Message 

		*--- Save current selected alias
		lcAlias = alias()

		*--- Acvtivity Log
		if This.Parent.LogRequests = 1 AND inlist(This.Event,"Gateway.FCGI.Sent","Gateway.HTTP.Sent","Web.FCGI.Sent","Web.HTTP.Sent")
			*--- Log tables name
			lcLogFile = "LOG_"+dtos(date())+"_"+substr(time(),1,2)+"_REQUESTS"

			*--- Check if table exist
			if !file("logs\"+lcLogFile+".DBF")
				*--- Enter in critical section to avoid other threads to create the log table
				sys(2336,1)

				*--- Create requests log table
				CREATE TABLE ("logs\"+lcLogFile) FREE (server C(4), thread C(10), process C(8), date D, time C(12), peer C(25), host C(60), request M, method C(8), uri C(60), code C(3), response M, bytes N(15), interval N(6))

				*--- Leave critical section
				sys(2336,2)
			endif

			*--- Insert log
			INSERT INTO ("logs\"+lcLogFile) FROM NAME This

			*--- Keep log files closed to increase performance
			SELECT (lcLogFile)
			USE
		endif

		*--- Debug Log
		if m.Level = 0 OR This.Parent.LogLevel > 1
			*--- Log tables name
			lcLogFile = "LOG_"+dtos(date())+"_"+substr(time(),1,2)+"_PROCESS"

			*--- Check if table exist
			if !file("logs\"+lcLogFile+".DBF")
				*--- Enter in critical section to avoid other threads to create the log table
				sys(2336,1)

				*--- Create debug log table
				CREATE TABLE ("logs\"+lcLogFile) FREE (server C(4), thread C(10), process C(8), event C(30), date D, time C(12), peer C(25), host C(60), request M, method C(8), uri C(60), code C(3), response M, bytes N(15), interval N(6), message M)

				*--- Leave critical section
				sys(2336,2)
			endif

			*--- Insert log
			INSERT INTO ("logs\"+lcLogFile) FROM NAME This

			*--- Keep log files closed to increase performance
			SELECT (lcLogFile)
			USE
		endif

		*--- Restore selected alias
		if !empty(lcAlias)
			select (lcAlias)
		endif
	ENDPROC

	PROCEDURE Sec2Time(SentSeconds AS Number)
	LOCAL lnHours, lnMinutes, lnSeconds, lnMiliSeconds, lcOutPut

		m.lnHours = floor(m.SentSeconds/3600)
		m.SentSeconds = mod(m.SentSeconds,3600)
		m.lnMinutes = floor(m.SentSeconds/60)
		m.SentSeconds = mod(m.SentSeconds,60)
		m.lnSeconds = floor(m.SentSeconds)
		m.lnMiliSeconds = (m.SentSeconds-m.lnSeconds) * 1000

		m.lcOutPut = transform(m.lnHours,"@l 99") + ":" + ;
		    transform(m.lnMinutes,"@l 99") + ":" + ;
		    transform(m.lnSeconds,"@l 99") + ":" + ;
		    transform(m.lnMiliSeconds,"@l 999")

		return (m.lcOutPut)
	ENDPROC
ENDDEFINE