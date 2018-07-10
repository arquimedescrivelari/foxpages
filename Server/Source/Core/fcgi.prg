#INCLUDE foxpages.h

******************************************************************************************
* FCGI Protocol Parser Class
****************************
DEFINE CLASS FCGIProtocol AS CUSTOM
	PROCEDURE Init()
		*--- Debug log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".FCGI.Init")
	ENDPROC

	PROCEDURE Destroy()
		*--- Debug log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".FCGI.Destroy")
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
		This.Parent.Parent.Log.Add(0,proper(This.Parent.Name)+".FCGI.Error",m.lcMessage)
	ENDPROC

	PROCEDURE Process(Request AS String)
	LOCAL lnLength,lnPad,lcContent,lnNameLen,lnValueLen,lnNameStart,lcName,lcValue
		*--- Debug log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".FCGI.Process")

		*--- Store request data
		This.Parent.Request.Data = m.Request

		do while !empty(m.Request)
*!*			typedef struct {
*!*				unsigned char version;
*!*				unsigned char type;
*!*				unsigned char requestIdB1;
*!*				unsigned char requestIdB0;
*!*				unsigned char contentLengthB1;
*!*				unsigned char contentLengthB0;
*!*				unsigned char paddingLength;
*!*				unsigned char reserved;
*!*			} FCGI_Header;

			*--- Record data
			This.Parent.Request.Type  = Bin2UInt(substr(m.Request,2,1))
			This.Parent.Request.ReqID = Bin2UInt(substr(m.Request,3,2))

			*--- Request length and pad sizes
			m.lnLength = Bin2UInt(substr(m.Request,5,2))
			m.lnPad    = Bin2UInt(substr(m.Request,7,1))

			*--- Incomplete request, wait next read event
			if len(m.Request) < FCGI_HEADER_LEN+m.lnLength+m.lnPad
				return .T.
			endif

			*--- Request record
			m.lcContent = substr(m.Request,FCGI_HEADER_LEN+1,m.lnLength)

			*--- Trim request
			m.Request = substr(m.Request,FCGI_HEADER_LEN+1+m.lnLength+m.lnPad)

			do case
			case This.Parent.Request.Type = FCGI_BEGIN_REQUEST
*!*				typedef struct {
*!*					unsigned char roleB1;
*!*					unsigned char roleB0;
*!*					unsigned char flags;
*!*					unsigned char reserved[5];
*!*				} FCGI_BeginRequestBody

				*--- Request role
				This.Parent.Request.Role = Bin2UInt(substr(m.lcContent,1,2))
				
				*--- Keep alive connection 
				This.Parent.Parent.KeepAlive = bitand(Bin2UInt(substr(m.lcContent,3,1)),FCGI_KEEP_CONN)
			case This.Parent.Request.Type = FCGI_PARAMS
				do while !empty(m.lcContent)
					*--- Header name length
					m.lnNameLen = Bin2UInt(substr(m.lcContent,1,1))

					*--- Header value length
					m.lnValueLen = Bin2UInt(substr(m.lcContent,2,1))

					if m.lnValueLen > 127
*!*						typedef struct {
*!*							unsigned char nameLengthB0;  /* nameLengthB0  >> 7 == 0 */
*!*							unsigned char valueLengthB3; /* valueLengthB3 >> 7 == 1 */
*!*							unsigned char valueLengthB2;
*!*							unsigned char valueLengthB1;
*!*							unsigned char valueLengthB0;
*!*							unsigned char nameData[nameLength];
*!*							unsigned char valueData[valueLength
*!*								((B3 & 0x7f) << 24) + (B2 << 16) + (B1 << 8) + B0];
*!*						} FCGI_NameValuePair14;

						m.lnValueLen  = bitclear(Bin2UInt(substr(m.lcContent,2,4)),31)
						m.lnNameStart = 1+4+1
					else
*!*						typedef struct {
*!*							unsigned char nameLengthB0;  /* nameLengthB0  >> 7 == 0 */
*!*							unsigned char valueLengthB0; /* valueLengthB0 >> 7 == 0 */
*!*							unsigned char nameData[nameLength];
*!*							unsigned char valueData[valueLength];
*!*						} FCGI_NameValuePair11;

						m.lnNameStart = 1+1+1
					endif

					*--- Header name
					m.lcName  = substr(m.lcContent,m.lnNameStart,m.lnNameLen)

					*--- Header value
					m.lcValue = substr(m.lcContent,m.lnNameStart+m.lnNameLen,m.lnValueLen)

					*--- Add/Update request properties
					This.Parent.Request.AddProperty(strtran(m.lcName,"HTTP_",""),m.lcValue)

					*--- Next header
					m.lcContent = substr(m.lcContent,m.lnNameStart+m.lnNameLen+m.lnValueLen)
				enddo
			case This.Parent.Request.Type = FCGI_STDIN
				*--- Request content
				This.Parent.Request.Content = This.Parent.Request.Content+m.lcContent
			endcase
		enddo

		*--- Response properties
		This.Parent.Response.Connection = This.Parent.Request.Connection
	ENDPROC

	PROCEDURE Send()
	LOCAL lnSize,lnHandle,lnPos,lcPacket,llSuccess
		*--- Debug log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".FCGI.Send")

		m.llSuccess = .T.

		*--- Send header
		if !This.SendRecord(FCGI_STDOUT,This.Parent.Response.Header)
			m.llSuccess = .F.
		endif

		*--- Don't send any data to HEAD method
		if This.Parent.Request.Method # "HEAD"
			*--- Packet length
			m.lnSize = HTTP_PACKET_LENGTH

			if empty(This.Parent.Response.FileName)
			  	*--- Send Data
				m.lnPos = 1
				do while m.llSuccess AND m.lnPos <= len(This.Parent.Response.Output)
					*--- Split data
					if m.lnPos+m.lnSize <= len(This.Parent.Response.Output)
						m.lcPacket = substr(This.Parent.Response.Output,m.lnPos,m.lnSize)
					else
						m.lcPacket = substr(This.Parent.Response.Output,m.lnPos)
				    endif

				    *--- Data position
				    m.lnPos = m.lnPos+m.lnSize

				    This.Parent.Response.Bytes = This.Parent.Response.Bytes+len(m.lcPacket)

					*--- Send packet
					if m.llSuccess AND !This.SendRecord(FCGI_STDOUT,m.lcPacket)
						m.llSuccess = .F.
					endif
				enddo
			else
			  	*--- Open file
				m.lnHandle = fopen(This.Parent.Response.FileName)

				if m.lnHandle = -1
				   return .F.
				endif

				do while m.llSuccess AND !feof(m.lnHandle)
					*--- Read packet
				 	m.lcPacket = fread(m.lnHandle,m.lnSize)

				    This.Parent.Response.Bytes = This.Parent.Response.Bytes+len(m.lcPacket)

					*--- Send packet
					if m.llSuccess AND !This.SendRecord(FCGI_STDOUT,m.lcPacket)
						m.llSuccess = .F.
					endif
				enddo

				*--- Close file
				fclose(m.lnHandle)
			endif
		endif

		if m.llSuccess AND !This.SendRecord(FCGI_STDOUT,"")
			m.llSuccess = .F.
		endif

*!*		typedef struct {
*!*			unsigned char appStatusB3;
*!*			unsigned char appStatusB2;
*!*			unsigned char appStatusB1;
*!*			unsigned char appStatusB0;
*!*			unsigned char protocolStatus;
*!*			unsigned char reserved[3];
*!*		} FCGI_EndRequestBody;

		m.lcPacket = UInt2Bin(0,4)+;
					 UInt2Bin(FCGI_REQUEST_COMPLETE,1)+;
					 replicate(chr(0),3)

		if m.llSuccess AND !This.SendRecord(FCGI_END_REQUEST,m.lcPacket)
			m.llSuccess = .F.
		endif

		*--- Log
		This.Parent.Parent.Log.Add(2,proper(This.Parent.Name)+".FCGI.Sent")

		return m.llSuccess
	ENDPROC

	PROCEDURE SendRecord(lcType,lcData)
	LOCAL lcRecord,lnLength,lnPad
	
*!*		typedef struct {
*!*			unsigned char version;
*!*			unsigned char type;
*!*			unsigned char requestIdB1;
*!*			unsigned char requestIdB0;
*!*			unsigned char contentLengthB1;
*!*			unsigned char contentLengthB0;
*!*			unsigned char paddingLength;
*!*			unsigned char reserved;
*!*			unsigned char contentData[contentLength];
*!*			unsigned char paddingData[paddingLength];
*!*		} FCGI_Record;

		m.lnLength = len(m.lcData)

		m.lnPad = 8-mod(m.lnLength,8)
		if m.lnPad = 8
			m.lnPad = 0
		endif

		m.lcRecord = UInt2Bin(FCGI_VERSION_1,1)+;
					 UInt2Bin(lcType,1)+;
					 UInt2Bin(This.Parent.Request.ReqID,2)+;
					 UInt2Bin(m.lnLength,2)+;
					 UInt2Bin(m.lnPad,1)+;
					 chr(0)+;
					 m.lcData+;
					 replicate(chr(0),m.lnPad)

		return This.Parent.Parent.Socket.Write(lcRecord)
	ENDPROC
ENDDEFINE

******************************************************************************************
* FCGI Gateway Class
********************
DEFINE CLASS FCGIGateway AS Socket OF core\socket.prg

	Buffer      = ""
	Response    = ""

	IsConnected = .F.

	PROCEDURE Init()
		*--- Debug log
		This.Parent.Parent.Log.Add(2,"Gateway.FCGI.Init")
		
		*--- Run base class code
		dodefault()
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
		This.Parent.Parent.Log.Add(0,"Gateway.FCGI.Error",m.lcMessage)
	ENDPROC

	PROCEDURE Process()
	LOCAL lcData,lcHeader,laHeaders,lnLength,lnPad,lcName,lcValue,lcNameLen,lcValueLen,llSuccess
		*--- Debug log
		This.Parent.Parent.Log.Add(2,"Gateway.FCGI.Process")

*!*		typedef struct {
*!*			unsigned char roleB1;
*!*			unsigned char roleB0;
*!*			unsigned char flags;
*!*			unsigned char reserved[5];
*!*		} FCGI_BeginRequestBody

		*--- Begin request Body
		m.lcData = UInt2Bin(FCGI_RESPONDER,2)+;
				   UInt2Bin(iif(This.Parent.Request.Connection = "keep-alive",FCGI_KEEP_CONN,0),1)+;
				   chr(0)+chr(0)+chr(0)+chr(0)+chr(0)

		m.llSuccess = .T.

		*--- Send begin request record
		if m.llSuccess AND !This.SendRequest(FCGI_BEGIN_REQUEST,m.lcData)
			m.llSuccess = .F.
		endif

		*--- Request headers
		dimension laHeaders[1]
		amembers(laHeaders,This.Parent.Request)

		m.lcData = ""
		for each m.lcHeader in m.laHeaders
			*--- Header value
			m.lcValue = evaluate("This.Parent.Request."+m.lcHeader)

			*--- Don't send empty headers
			if empty(m.lcValue)
				loop
			endif

			*--- Headers
			do case
			case m.lcHeader == "DATA"
				loop
			case m.lcHeader == "CONTENT_LENGTH"
				m.lcName = "CONTENT_LENGTH"
			case m.lcHeader == "CONTENT_TYPE"
				m.lcName = "CONTENT_TYPE"
			case m.lcHeader == "DOCUMENT_ROOT"
				m.lcName = "DOCUMENT_ROOT"
			case m.lcHeader == "DOCUMENT_URI"
				m.lcName = "DOCUMENT_URI"
			case m.lcHeader == "GATEWAY_INTERFACE"
				m.lcName = "GATEWAY_INTERFACE"
			case m.lcHeader == "METHOD"
				m.lcName = "REQUEST_METHOD"
			case m.lcHeader == "REDIRECTSTATUS"
				m.lcName = "REDIRECT_STATUS"
			case m.lcHeader == "REMOTE_ADDRESS"
				m.lcName = "REMOTE_ADDR"
			case m.lcHeader == "REMOTE_PORT"
				m.lcName = "REMOTE_PORT"
			case m.lcHeader == "QUERY_STRING"
				m.lcName = "QUERY_STRING"
			case m.lcHeader == "REQUEST_SCHEME"
				m.lcName = "REQUEST_SCHEME"
			case m.lcHeader == "SCRIPT_NAME"
				m.lcName = "SCRIPT_NAME"
			case m.lcHeader == "SCRIPT_FILENAME"
				m.lcName = "SCRIPT_FILENAME"
			case m.lcHeader == "SERVER_ADDRESS"
				m.lcName = "SERVER_ADDR"
			case m.lcHeader == "SERVER_NAME"
				m.lcName = "SERVER_NAME"
			case m.lcHeader == "SERVER_PORT"
				m.lcName = "SERVER_PORT"
			case m.lcHeader == "SERVER_SOFTWARE"
				m.lcName = "SERVER_SOFTWARE"
			case m.lcHeader == "REQUEST_URI"
				m.lcName = "REQUEST_URI"
			case m.lcHeader == "SERVER_PROTOCOL"
				m.lcName = "SERVER_PROTOCOL"
			otherwise
				m.lcName = "HTTP_"+m.lcHeader
			endcase
			
			*--- Convert numeric parameters to character
			if type("m.lcValue") = "N"
				m.lcValue = alltrim(str(m.lcValue))
			endif

			*--- Name length
			m.lnNameLen  = len(m.lcName)

			*--- Value length
			m.lnValueLen = len(m.lcValue)

			if m.lnNameLen > 127
				m.lcNameLen  = UInt2Bin(bitset(m.lnNameLen,31),4)

				*--- Type 41 or 44
				if m.lnValueLen > 127
*!*					typedef struct {
*!*						unsigned char nameLengthB3;  /* nameLengthB3  >> 7 == 1 */
*!*						unsigned char nameLengthB2;
*!*						unsigned char nameLengthB1;
*!*						unsigned char nameLengthB0;
*!*						unsigned char valueLengthB3; /* valueLengthB3 >> 7 == 1 */
*!*						unsigned char valueLengthB2;
*!*						unsigned char valueLengthB1;
*!*						unsigned char valueLengthB0;
*!*						unsigned char nameData[nameLength
*!*							((B3 & 0x7f) << 24) + (B2 << 16) + (B1 << 8) + B0];
*!*						unsigned char valueData[valueLength
*!*							((B3 & 0x7f) << 24) + (B2 << 16) + (B1 << 8) + B0];
*!*					} FCGI_NameValuePair44;

					m.lcValueLen = UInt2Bin(bitset(m.lnValueLen,31),4)
				else
*!*					typedef struct {
*!*						unsigned char nameLengthB3;  /* nameLengthB3  >> 7 == 1 */
*!*						unsigned char nameLengthB2;
*!*						unsigned char nameLengthB1;
*!*						unsigned char nameLengthB0;
*!*						unsigned char valueLengthB0; /* valueLengthB0 >> 7 == 0 */
*!*						unsigned char nameData[nameLength
*!*							((B3 & 0x7f) << 24) + (B2 << 16) + (B1 << 8) + B0];
*!*						unsigned char valueData[valueLength];
*!*					} FCGI_NameValuePair41;

					m.lcValueLen = UInt2Bin(m.lnValueLen,1)
				endif
			else
				m.lcNameLen  = UInt2Bin(m.lnNameLen,1)

				*--- Type 11 or 14
				if m.lnValueLen > 127
*!*					typedef struct {
*!*						unsigned char nameLengthB0;  /* nameLengthB0  >> 7 == 0 */
*!*						unsigned char valueLengthB3; /* valueLengthB3 >> 7 == 1 */
*!*						unsigned char valueLengthB2;
*!*						unsigned char valueLengthB1;
*!*						unsigned char valueLengthB0;
*!*						unsigned char nameData[nameLength];
*!*						unsigned char valueData[valueLength
*!*							((B3 & 0x7f) << 24) + (B2 << 16) + (B1 << 8) + B0];
*!*					} FCGI_NameValuePair14;

					m.lcValueLen = UInt2Bin(bitset(m.lnValueLen,31),4)
				else
*!*					typedef struct {
*!*						unsigned char nameLengthB0;  /* nameLengthB0  >> 7 == 0 */
*!*						unsigned char valueLengthB0; /* valueLengthB0 >> 7 == 0 */
*!*						unsigned char nameData[nameLength];
*!*						unsigned char valueData[valueLength];
*!*					} FCGI_NameValuePair11;

					m.lcValueLen = UInt2Bin(m.lnValueLen,1)
				endif
			endif

			m.lcData = m.lcData+m.lcNameLen+m.lcValueLen+m.lcName+m.lcValue
		next

		*--- Send params record
		if m.llSuccess AND !This.SendRequest(FCGI_PARAMS,m.lcData)
			m.llSuccess = .F.
		endif

		*--- Send end params record
		if m.llSuccess AND !This.SendRequest(FCGI_PARAMS)
			m.llSuccess = .F.
		endif

		*--- Send STDIN record
		if !empty(This.Parent.Request.Content)
			*--- Send STDIN record
			if m.llSuccess AND !This.SendRequest(FCGI_STDIN,This.Parent.Request.Content)
				m.llSuccess = .F.
			endif
		endif

		*--- Send END STDIN record
		if m.llSuccess AND !This.SendRequest(FCGI_STDIN)
			m.llSuccess = .F.
		endif

		return m.llSuccess
	ENDPROC

	PROCEDURE SendRequest(lnType,lcData)
	LOCAL lcRecord,lnLength,lnPad
		*--- Parameter check
		if pcount() < 2
			m.lcData = ""
		endif

		*--- Data length
		m.lnLength = len(m.lcData)

		*--- Data padding
		m.lnPad = 8-mod(m.lnLength,8)
		if m.lnPad = 8
			m.lnPad = 0
		endif

		*--- Add padding
		m.lcData = m.lcData+replicate(chr(0),m.lnPad)

*!*		typedef struct {
*!*			unsigned char version;
*!*			unsigned char type;
*!*			unsigned char requestIdB1;
*!*			unsigned char requestIdB0;
*!*			unsigned char contentLengthB1;
*!*			unsigned char contentLengthB0;
*!*			unsigned char paddingLength;
*!*			unsigned char reserved;
*!*		} FCGI_Header;

		*--- Send record
		m.lcRecord = UInt2Bin(FCGI_VERSION_1,1)+;
						  UInt2Bin(lnType,1)+;
						  UInt2Bin(1,2)+;
						  UInt2Bin(m.lnLength,2)+;
						  UInt2Bin(m.lnPad,1)+;
						  chr(0)+;
						  m.lcData

		return This.Write(m.lcRecord)
	ENDPROC

	PROCEDURE SendResponse()
	LOCAL lnType,lnReqID,lnLength,lnPad,lcContent,lcHeader,lcHeaderLen,lnSize,lnPos,lcPacket,lcStatus_Code,lcStatus_Description,llSuccess
		do while !empty(This.Buffer)
*!*			typedef struct {
*!*				unsigned char version;
*!*				unsigned char type;
*!*				unsigned char requestIdB1;
*!*				unsigned char requestIdB0;
*!*				unsigned char contentLengthB1;
*!*				unsigned char contentLengthB0;
*!*				unsigned char paddingLength;
*!*				unsigned char reserved;
*!*			} FCGI_Header;

			*--- Record data
			m.lnType  = Bin2UInt(substr(This.Buffer,2,1))
			m.lnReqID = Bin2UInt(substr(This.Buffer,3,2))

			*--- Response length and pad size
			m.lnLength = Bin2UInt(substr(This.Buffer,5,2))
			m.lnPad    = Bin2UInt(substr(This.Buffer,7,1))

			*--- Incomplete response, wait next read event
			if len(This.Buffer) < FCGI_HEADER_LEN+m.lnLength+m.lnPad
				return .T.
			endif

			*--- Response record
			m.lcContent = substr(This.Buffer,FCGI_HEADER_LEN+1,m.lnLength)

			*--- Trim response
			This.Buffer = substr(This.Buffer,FCGI_HEADER_LEN+1+m.lnLength+m.lnPad)

			do case
			case m.lnType = FCGI_END_REQUEST
				*--- Extract header from response
				m.lcHeaderLen = at(HEADER_DELIMITER,This.Response)-1
				m.lcHeader    = substr(This.Response,1,m.lcHeaderLen)

				*--- Add Content-length header
				if !("Content-Length:" $ m.lcHeader)
					m.lcHeader = "Content-Length: "+alltrim(str(len(This.Response)-m.lcHeaderLen-4))+CRLF+m.lcHeader
				endif

				*--- Add Server header
				m.lcHeader = "Server: "+FOX_PAGES_VERSION+CRLF+m.lcHeader

				*--- Add/update HTTP status code header
				m.lcStatus_Code        = "200"
				m.lcStatus_Description = "OK"
				if "Status:" $ m.lcHeader
					m.lcStatus_Code = strextract(m.lcHeader,"Status: "," ")
					m.lcStatus_Description = strextract(m.lcHeader,m.lcStatus_Code+" ",CRLF)
				endif

				m.lcHeader = "HTTP/1.1 "+m.lcStatus_Code+" "+m.lcStatus_Description+CRLF+m.lcHeader

				*--- Update Location header
				if "Location:" $ m.lcHeader
					m.lcHeader = strtran(m.lcHeader,"Location: ./","Location: "+This.Parent.Request.Document_URI)
				endif

				*--- Update header
				This.Response = m.lcHeader+substr(This.Response,at(HEADER_DELIMITER,This.Response))

				*--- Save response data
				This.Parent.Response.Bytes = len(This.Response)
				This.Parent.Response.Header = m.lcHeader
				This.Parent.Response.Status_Code = m.lcStatus_Code

				*--- Disconnect
				This.Disconnect()

				*--- Response complete
				m.llSuccess = .T.
			case m.lnType = FCGI_STDOUT
				*--- Save response content
				This.Response = This.Response+m.lcContent
			endcase
		enddo

		*--- Incomplete response
		if !m.llSuccess
			return .T.
		endif

		*--- Debug log
		This.Parent.Parent.Log.Add(2,"Gateway.FCGI.Send")

		*--- Packet length
		m.lnSize = HTTP_PACKET_LENGTH

	  	*--- Send Data
		m.lnPos = 1
		do while m.llSuccess AND m.lnPos <= len(This.Response)
			*--- Split data
			if m.lnPos+m.lnSize <= len(This.Response)
				m.lcPacket = substr(This.Response,m.lnPos,m.lnSize)
			else
				m.lcPacket = substr(This.Response,m.lnPos)
		    endif

		    *--- Data position
		    m.lnPos = m.lnPos+m.lnSize

			*--- Send packet
			if m.llSuccess AND !This.Parent.Parent.Socket.Write(m.lcPacket)
				m.llSuccess = .F.
			endif
		enddo

		*--- Clear response
		This.Response = ""

		*--- Log
		This.Parent.Parent.Log.Add(2,"Gateway.FCGI.Sent")

		*--- Remove gateway object
		This.Parent.Parent.RemoveObject("Gateway")
	ENDPROC

	PROCEDURE Read()
	LOCAL laBuffer,lcBuffer,lnSize,lnByte
		*--- Wait to read
		do while !This.IsReadable
			*--- Check connection
			if !This.SocketWrench.IsConnected
				This.Parent.Disconnect()
				return .F.
			endif

			sleep(10)
		enddo

		*--- Create byte array buffer
		DIMENSION laBuffer[1024] AS Byte

		m.lcBuffer = ""
		do while This.IsReadable
			*--- Reset byte array
			m.laBuffer = 0

			*--- Read data to byte array
			m.lnSize = This.SocketWrench.Read(@m.laBuffer)

			*--- Check data was received
			if m.lnSize < 1
				exit
			endif

			*--- Convert byte array to string
			for m.lnByte = 1 to m.lnSize
				m.lcBuffer = m.lcBuffer + chr(m.laBuffer[m.lnByte])
			next
		enddo

		This.Buffer = This.Buffer+m.lcBuffer

		*--- Send response
		This.SendResponse()
	ENDPROC

	PROCEDURE Write(Data AS String)
		return This.SocketWrench.Write(createbinary(Data)) # -1
	ENDPROC

	PROCEDURE OnDisconnect()
		This.Parent.Parent.Disconnect()
	ENDPROC
ENDDEFINE