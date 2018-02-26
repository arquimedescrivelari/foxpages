LOCAL loJSON,loData,laResult,loResult

*--- Check user logued
if type("Request.Cookies.SID") = "O" AND !empty(Request.Cookies.SID.Value)
  *--- Locate session
  use data\sessions
  locate for session = Request.Cookies.SID.Value

  *--- User logued
  if !eof()
    cSeller = sessions.seller
  else
    *--- User not logued, delete cookie
    HTTP.SetCookie("SID","",datetime()-86400,,"/")

	*--- Send Error
	HTTP.SendError("200","Login required","Login required","You must be logued.")
    
    return
  endif
else
	*--- Send Error
	HTTP.SendError("200","Login required","Login required","You must be logued.")

    return
endif

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- Result object
loResult = createobject("EMPTY")

do case
case Request.Method = "GET"
	*--- Get/Query
	SELECT id, name FROM groups ORDER BY id INTO CURSOR result

	if !eof()
		*--- Add array of nodes
		addproperty(loResult,"children("+str(max(reccount("result"),1))+")","")

		*--- Add group nodes
		select result
		scan
			*--- Create object from node record
			scatter name loResult.Children[recno()]
		endscan
	endif
		
	*--- Create root object
	addproperty(loResult,"name","Todos")
	addproperty(loResult,"id",0)

	*--- Result must be an array
	DIMENSION laResult(1)
	laResult[1] = loResult
	
	*--- Generate JSON
	Response.Content      = loJSON.Stringify(@laResult)
	Response.Content_Type = "application/json; charset=utf8"

	*--- Release JSON Parser object
	release loJSON

	*--- Release class
	clear class json
	clear class main

	return	
case Request.Method = "POST"
	*--- Insert
   loJSON.Parse(Request.Content,,@loData)

	try
		USE groups
		INSERT INTO groups (name) VALUES (loData.Name)
	    
	    addproperty(loResult,"success",.T.)
	    addproperty(loResult,"id",groups.id)
		addproperty(loResult,"name",groups.name)
	catch
	    addproperty(loResult,"success",.F.)
	    addproperty(loResult,"error","Error: could not add group to database")
	endtry
case Request.Method = "PUT"
	*--- Update
   loJSON.Parse(Request.Content,,@loData)

	try
		USE groups
		UPDATE groups SET name = loData.Name where id = val(loData.id)
	    
	    addproperty(loResult,"success",.T.)
	    addproperty(loResult,"id",groups.id)
		addproperty(loResult,"name",groups.name)
	catch
	    addproperty(loResult,"success",.F.)
		addproperty(loResult,"error","Error: could not rename group in database")
	endtry
case Request.Method = "DELETE"
	*--- Delete
	try
		DELETE FROM groups WHERE id = val(Request.ID)
	    
	    addproperty(loResult,"id",groups.id)
		addproperty(loResult,"name",groups.name)
	    addproperty(loResult,"success",.T.)
	catch
	    addproperty(loResult,"success",.F.)
		addproperty(loResult,"error","Error: could not delete group from database")
	endtry
endcase

*--- Generate JSON
Response.Content      = loJSON.Stringify(loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release JSON Parser object
release loJSON

*--- Release class
clear class json
clear class main