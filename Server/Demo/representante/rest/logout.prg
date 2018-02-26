LOCAL lcUserName

if type("Request.Cookies.SID") = "O" AND !empty(Request.Cookies.SID.Value) && Logout
	*--- Locate session
	use data\sessions
	locate for session = Request.Cookies.SID.Value

	lcUserName = username

	*--- Remove session.
	if !eof()
		delete
	endif

	*--- Log
	strtofile(ttoc(datetime())+" - "+Request.Remote_Address+":"+Request.Remote_Port+" - logout.fpx - "+alltrim(lcUserName)+chr(13)+chr(10),HTML.Directory+"representantes.txt",1)
endif