#INCLUDE foxpages.h

******************************************************************************************
* HTML Processing class
***********************
DEFINE CLASS HTMLProcessor AS SESSION
	*--- Error
	HasError = .F.

	*--- Work directory
	Directory = ""

	PROCEDURE Init()
		*--- Debug log
		This.Parent.Parent.Log.Add(3,"Web.HTML.Init")

		*--- Sets
		set deleted on
		set exclusive off
		set memowidth to 8192
	ENDPROC

	PROCEDURE Destroy()
		*--- Debug log
		This.Parent.Parent.Log.Add(3,"Web.HTML.Destroy")
	ENDPROC

	PROCEDURE Error(nError,cMethod,nLine)
	LOCAL lcMessage,lnSize,lnCtrl
		This.HasError = .T.

		m.lcMessage = "Message: "+alltrim(str(m.nError))+" - "+message()+;
					iif(This.Parent.Parent.StartMode = 0,"<BR>Code: "+strtran(message(1),"<BR>",""),"")

		m.lcMessage = m.lcMessage+"<BR><BR>Call Stack:"
		m.lnSize = astackinfo(Stack)
		for m.lnCtrl = (m.lnSize-1) to 5 step -1
			m.lcMessage = m.lcMessage+"<BR>"+alltrim(str(stack[m.lnCtrl,1]-4))+") "+stack[m.lnCtrl,2]+" ("+stack[m.lnCtrl,3]+","+alltrim(str(stack[m.lnCtrl,5]))+")"
		next

		*--- Debug log
		This.Parent.Parent.Log.Add(0,"Web.HTML.Error",strtran(m.lcMessage,"<BR>",CRLF))

		*--- Send error
		This.Parent.SendError("500","Internal Server Error","RUNTIME ERROR",m.lcMessage)
	ENDPROC

	PROCEDURE Process(File AS String)
	LOCAL lnDirs
		*--- Debug log
		This.Parent.Parent.Log.Add(3,"Web.HTML.Process")

		*--- Work directory
		This.Directory = This.Parent.Directory

		*--- Insert directory into file
		m.File = This.Directory+m.File

		*--- Compile HTML to FXP
		if !This.Compile(m.File)
			return .F.
		endif

		*--- FXP found
		if file(m.File)
			*--- Set response properties
			This.Parent.Response.Status_Code        = "200"
			This.Parent.Response.Status_Description = "OK"
			This.Parent.Response.Content_Type       = "text/html"
		else
			*--- Send 404.fxp content
			m.File = This.Directory+"/404.fxp"

			*--- Compile HTML to FXP
			if !This.Compile(m.File)
				This.Parent.SendError("404","Not Found","Not Found")
				return .F.
			endif

			*--- 404.fxp found
			if file(m.File)
				*--- Set response properties
				This.Parent.Response.Status_Code        = "404"
				This.Parent.Response.Status_Description = "Not found"
				This.Parent.Response.Content_Type       = "text/html"
			else
				This.Parent.SendError("404","Not Found","Not Found")
				return .F.
			endif
		endif

		*--- Set path directory
		set path to (This.Directory)

		*--- Add / to directory
		This.Directory = This.Directory+"/"

		for m.lnDirs = 1 to adir(aDirs,This.Directory+"*.*","D")
			if aDirs[m.lnDirs,1] = "."
				loop
			endif
			if "D" $ aDirs[m.lnDirs,5]
				set path to (This.Directory+aDirs[m.lnDirs,1]) additive
			endif
		next

		*--- Objects
		Socket   = This.Parent.Parent.Socket
		HTTP     = This.Parent
		HTML     = This
		Request  = This.Parent.Request
		Response = This.Parent.Response

		*--- Avoid program recompilation by debugger
		set development off

		*--- Run FoxCode
		set textmerge to memvar Response.OutPut noshow
		set textmerge on
		do (m.File)
		set textmerge off
		set textmerge to

		*--- Restore program recompilation
		set development on

		*--- Release objects
		RELEASE Socket
		RELEASE HTTP
		RELEASE HTML
		RELEASE Request
		RELEASE Response

		*--- Reload FLLs
		#IFDEF X64
			set library to bin64\vfp2c32.fll
		#ELSE
			set library to bin\vfp2c32t.fll,bin\vfpcompression.fll,bin\vfpencryption.fll
		#ENDIF

		*--- Clear set procedure
		set procedure to

		*--- Clear set path
		set path to

		*--- Close any open connection
		sqldisconnect(0)

		*--- Close any open database
		close databases all

		*--- Remove FXP from cache
		clear program

		return !This.HasError
	ENDPROC

	PROCEDURE Include(File AS String)
		*--- Debug log
		This.Parent.Parent.Log.Add(3,"Web.HTML.Include")

		*--- Insert directory into file
		m.File = This.Directory+m.File

		*--- Compile HTML to FXP
		This.Compile(m.File)

		*--- FXP not found
		if !file(m.File)
			return .F.
		endif

		*--- Run FoxCode
		do (m.File)

		*--- Runtime error 
		return !This.HasError
	ENDPROC

	PROCEDURE Compile(File AS String)
	LOCAL lcFXPFile,lcERRFile,lcPRGFile,lcHTMLFile,lcPRGFileData,lcHTMLFileData,llFoxCodeBlock,llFoxCodeBlockEnd,llHTMLCodeLine,lnCtrl,lcLine,ltCreate,ltAccess,ltWrite
		m.lcFXPFile      = m.File               				&& FXP file 
		m.lcERRFile      = strtran(m.lcFXPFile,".fxp",".err")	&& ERR file 
		m.lcPRGFile      = strtran(m.lcFXPFile,".fxp",".prg")	&& PRG file 
		m.lcHTMLFile     = strtran(m.lcFXPFile,".fxp",".html")	&& HTML file
		m.lcPRGFileData  = "" && PRG file data	
		m.lcHTMLFileData = "" && HTML file data

		*--- Check if a HTML file exist
		if file(m.lcHTMLFile)
			*--- Check file dates
			if !file(m.lcFXPFile) OR fdate(m.lcHTMLFile,1) > fdate(m.lcFXPFile,1)
				*--- Compile a new version of .html to a .prg file
				m.lcHTMLFileData = filetostr(m.lcHTMLFile)
				m.lcPRGFileData = ""

				m.llFoxCodeBlock = .F.
				for m.lnCtrl = 1 to memlines(m.lcHTMLFileData)
					m.lcLine = mline(m.lcHTMLFileData,m.lnCtrl)

					m.llHTMLCodeLine = .F.

					do case
					case m.llFoxCodeBlock AND left(chrtran(m.lcLine,chr(9)+chr(32),""),1) = "*"
						*--- Comments
					case "<%" $ m.lcLine AND !("%>" $ m.lcLine)
						*--- FoxCode Block start 
						m.llFoxCodeBlock = .T.
						m.lcLine = strtran(m.lcLine,"<%")
					case "<fps>" $ m.lcLine
						*--- FoxCode Block start 
						m.llFoxCodeBlock = .T.
						m.lcLine = strtran(m.lcLine,"<fps>")
					case !("<%" $ m.lcLine) AND "%>" $ m.lcLine
						*--- FoxCode Block End
						m.llFoxCodeBlockEnd = .T.
						m.lcLine = strtran(m.lcLine,"%>")
					case "</fps>" $ m.lcLine
						*--- FoxCode Block End
						m.llFoxCodeBlockEnd = .T.
						m.lcLine = strtran(m.lcLine,"</fps>")
					case "<%" $ m.lcLine AND "%>" $ m.lcLine
						*--- HTMLCode Line
						m.llHTMLCodeLine = .T.
						m.lcLine = strtran(strtran(m.lcLine,"<%","<<"),"%>",">>")
					case ("<e>" $ m.lcLine AND "</e>" $ m.lcLine)
						*--- HTMLCode Line
						m.llHTMLCodeLine = .T.
						m.lcLine = strtran(strtran(m.lcLine,"<e>","<<"),"</e>",">>")
					case ("<t>" $ m.lcLine AND "</t>" $ m.lcLine)
						*--- HTMLCode Line
						m.llHTMLCodeLine = .T.
						m.lcLine = strtran(strtran(m.lcLine,"<t>"),"</t>")
					case left(ltrim(m.lcLine),1) = "<" OR right(rtrim(m.lcLine),1) = ">"
						*--- HTMLCode Line
						m.llHTMLCodeLine = .T.
					endcase

					m.lcPRGFileData = m.lcPRGFileData + iif(!m.llFoxCodeBlock OR m.llHTMLCodeLine,"\","")+m.lcLine+CRLF

					if m.llFoxCodeBlockEnd
						m.llFoxCodeBlock    = .F.
						m.llFoxCodeBlockEnd = .F.
					endif
				next

				*--- Save PRG file
				strtofile(m.lcPRGFileData,m.lcPRGFile)
			endif
		endif

		*--- Check if a PRG file exist
		if file(m.lcPRGFile)
			*--- Check file dates
			if !file(m.lcFXPFile) OR fdate(m.lcPRGFile,1) > fdate(m.lcFXPFile,1)
				*--- Compile PRG File
				compile (m.lcPRGFile)

				*--- Check compilation erros
				if file(m.lcERRFile)
					*--- Delete files
					delete file (m.lcPRGFile)
					delete file (m.lcFXPFile)

					*--- Debug log
					This.Parent.Parent.Log.Add(0,"Web.HTML.Error",filetostr(m.lcERRFile))

					*--- Send error
					This.Parent.SendError("500","Internal Server Error","COMPILATION ERROR",strtran(filetostr(m.lcERRFile),CRLF,"<BR>"))

					*--- Delete error file
					delete file (m.lcERRFile)

					return .F.
				endif

				*--- Check start mode
				if This.Parent.Parent.StartMode = 0
					*--- Save PRG file times
					GetFileTimes(m.lcFXPFile,@m.ltCreate,@m.ltAccess,@m.ltWrite)

					*--- Save HTML file as PRG file
					copy file (m.lcHTMLFile) to (m.lcPRGFile)

					*--- Set PRG file times to avoid debugger to show 'Source out of date'
					SetFileTimes(m.lcPRGFile,m.ltCreate,m.ltAccess,m.ltWrite)
				else
					*--- Delete PRG file
					delete file (m.lcPRGFile)
				endif
			endif
		endif
	ENDPROC
ENDDEFINE