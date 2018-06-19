#INCLUDE foxpages.h

******************************************************************************************
* HTTP Protocol class
*********************
DEFINE CLASS HTTPProtocol AS CUSTOM
	PROCEDURE Init()
		*--- Debug log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".HTTP.Init")
	ENDPROC

	PROCEDURE Destroy()
		*--- Debug log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".HTTP.Destroy")
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
	LOCAL lcMessage,lnSize,lnCtrl
		m.lcMessage = "Message: "+alltrim(str(m.nError))+" - "+message()+;
					iif(This.Parent.Parent.StartMode = 0,CRLF+"Code: "+message(1),"")

		m.lcMessage = m.lcMessage+CRLF+CRLF+"Call Stack:"
		m.lnSize = astackinfo(Stack)
		for m.lnCtrl = (m.lnSize-1) to 2 step -1
			m.lcMessage = m.lcMessage+CRLF+alltrim(str(stack[m.lnCtrl,1]-1))+") "+stack[m.lnCtrl,2]+" ("+stack[m.lnCtrl,3]+","+alltrim(str(stack[m.lnCtrl,5]))+")"
		next

		*--- Debug log
		This.Parent.Parent.Log.Add(0,proper(This.Parent.Name)+".HTTP.Error",m.lcMessage)
	ENDPROC

	PROCEDURE Process(Request AS String)
	LOCAL lcHeader,lnHeader,lcData,lcName,lcValue,lnPos
		*--- Incomplete request
		if !(HEADER_DELIMITER $ m.Request)
			return .F.
		endif

		*--- Request header
		m.lcHeader = substr(m.Request,1,at(HEADER_DELIMITER,m.Request)+3)

		*--- Request can be received in multiple packets
		if val(strextract(m.lcHeader,"Content-Length: ",CRLF))+len(m.lcHeader) > len(m.Request)
			return .T.
		endif

		*--- Store request data for log
		This.Parent.Request.Data = m.Request

		*--- Request data
		m.lcData = mline(m.lcHeader,1)

		*--- Method
		This.Parent.Request.Method = substr(m.lcData,1,at(" ",m.lcData)-1)

		*--- Request URI
		This.Parent.Request.Request_URI = strextract(m.lcData," "," HTTP/")

		*--- Server protocol
		This.Parent.Request.Server_Protocol = substr(m.lcData,rat(" ",m.lcData)+1)

		*--- Extract Query_String
		if '?' $ This.Parent.Request.Request_URI
			This.Parent.Request.Query_String = substr(This.Parent.Request.Request_URI,at('?',This.Parent.Request.Request_URI)+1)
		    This.Parent.Request.Document_URI = substr(This.Parent.Request.Request_URI,1,at('?',This.Parent.Request.Request_URI)-1)
		else
		 	This.Parent.Request.Query_String = ""
		    This.Parent.Request.Document_URI = This.Parent.Request.Request_URI
		endif

		*--- Hostname
		This.Parent.Request.Host = strextract(m.lcHeader,"Host: ",CRLF)

		*--- Debug log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".HTTP.Process")

		*--- No URI, send index page
		if right(This.Parent.Request.Document_URI,1) = "/"
			*--- Open sites table
			if !used("sites")
				use data\sites in 0
			endif

			*--- Locate host in sites table and define working directory
			select sites
			locate for server = This.Parent.Parent.ServerID AND (hostname = This.Parent.Request.Host OR hostname = "*")

		    This.Parent.Request.Document_URI = This.Parent.Request.Document_URI + alltrim(sites.index)
		endif

		*--- Request properties
		for m.lnHeader = 2 to memlines(m.lcHeader)-2
			*--- Header data
			m.lcData = mline(m.lcHeader,m.lnHeader)

			*--- Find delimiteer
			m.lnPos = at(":",m.lcData)

			if !empty(m.lnPos)
				*--- Header name
				m.lcName = substr(m.lcData,1,lnPos-1)

				*--- Update header name
				m.lcName = chrtran(m.lcName,"-","_")

				*--- Header value
				m.lcValue = substr(m.lcData,lnPos+2)

				*--- Add/Update request object properties
				This.Parent.Request.AddProperty(m.lcName,m.lcValue)
			endif
		next

		*--- Server and connection properties
		This.Parent.Request.Request_Scheme			= iif(This.Parent.Parent.Secure = 0,"http","https")
		This.Parent.Request.Remote_Address			= This.Parent.Parent.Socket.PeerAddress
		This.Parent.Request.Remote_Port				= alltrim(str(This.Parent.Parent.Socket.PeerPort))
		This.Parent.Request.Server_Address			= This.Parent.Parent.Socket.LocalAddress
		This.Parent.Request.Server_Name				= This.Parent.Request.Host
		This.Parent.Request.Server_Port				= alltrim(str(This.Parent.Parent.Socket.LocalPort))
		This.Parent.Request.Server_Software			= FOX_PAGES_VERSION

		*--- Request content
		This.Parent.Request.Content = substr(m.Request,at(HEADER_DELIMITER,m.Request)+len(HEADER_DELIMITER))

		*--- Response properties
		This.Parent.Response.Connection = This.Parent.Request.Connection
	ENDPROC

	PROCEDURE Send()
	LOCAL lnSize,lnHandle,lnPos,lcPacket,llSuccess
		*--- Log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".HTTP.Send")

		llSuccess = .T.

		*--- Send header
		if !This.Parent.Parent.Socket.Write(This.Parent.Response.Header)
			llSuccess = .F.
		endif

		*--- Don't send any data to HEAD method
		if This.Parent.Request.Method # "HEAD"
			*--- Packet length
			m.lnSize = HTTP_PACKET_LENGTH
			if This.Parent.Parent.StartMode = 1 AND !empty(This.Parent.Parent.Bandwidth)
				m.lnSize = int(This.Parent.Parent.Bandwidth * 102.4)
			endif

			if empty(This.Parent.Response.FileName)
			  	*--- Send Data
				m.lnPos = 1
				do while llSuccess AND m.lnPos <= len(This.Parent.Response.Output)
					*--- Split data
					if m.lnPos+m.lnSize <= len(This.Parent.Response.Output)
						m.lcPacket = substr(This.Parent.Response.Output,m.lnPos,m.lnSize)
					else
						m.lcPacket = substr(This.Parent.Response.Output,m.lnPos)
				    endif

				    *--- Data position
				    m.lnPos = m.lnPos+m.lnSize

				    if This.Parent.Response.Transfer_Encoding = "chunked"
				    	m.lcPacket = ltrim(substr(transform(len(m.lcPacket),"@0"),3),"0") + CRLF + m.lcPacket + CRLF
				    endif

				    This.Parent.Response.Bytes = This.Parent.Response.Bytes + len(m.lcPacket)

					*--- Send packet
					if llSuccess AND !This.Parent.Parent.Socket.Write(m.lcPacket)
						llSuccess = .F.
					endif

					*--- Bandwidth limit
					if This.Parent.Parent.StartMode = 1 AND !empty(This.Parent.Parent.Bandwidth) AND m.lnPos <= len(This.Parent.Response.Output)
						sleep(100)
					endif
				enddo
			else
			  	*--- Open file
				m.lnHandle = fopen(This.Parent.Response.FileName)

				if m.lnHandle = -1
					llError = .T.
					return .F.
				endif

				do while llSuccess AND !feof(m.lnHandle)
					*--- Read packet
				 	m.lcPacket = fread(m.lnHandle,m.lnSize)

				    if This.Parent.Response.Transfer_Encoding = "chunked"
				    	m.lcPacket = ltrim(substr(transform(len(m.lcPacket),"@0"),3),"0") + CRLF + m.lcPacket + CRLF
				    endif

				    This.Parent.Response.Bytes = This.Parent.Response.Bytes + len(m.lcPacket)

					*--- Send packet
					if llSuccess AND !This.Parent.Parent.Socket.Write(m.lcPacket)
						llSuccess = .F.
					endif

					*--- Bandwidth limit
					if This.Parent.Parent.StartMode = 1 AND !empty(This.Parent.Parent.Bandwidth) AND !feof(m.lnHandle)
						sleep(100)
					endif
				enddo

				*--- Close file
				fclose(m.lnHandle)
			endif

			*--- Send trailer
		    if This.Parent.Response.Transfer_Encoding = "chunked"
			    This.Parent.Response.Bytes = This.Parent.Response.Bytes + 5

			    if llSuccess AND !This.Parent.Parent.Socket.Write("0"+CRLF+CRLF)
					llSuccess = .F.
				endif
			endif
		endif

		*--- Log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".HTTP.Sent")

		return llSuccess
	ENDPROC
ENDDEFINE