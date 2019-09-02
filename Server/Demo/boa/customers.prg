LOCAL loJSON,loResult,loData,lcFields,lcVar,lnVar,lcTab,llHeaders,llLabels

*--- Create JSON Parser
loJSON = newobject("JSON","json.prg")

*--- Result object
loResult = createobject("EMPTY")
addproperty(loResult,"file","klant")

lcFields = strextract(Request.Query_String+"&",'fields',"&")
lcVar = strconv(strextract(Request.Query_String+"&",'key=',"&"),11)
lcTab = strextract(Request.Query_String+"&",'tab=',"&")
llHeaders = iif(strextract(Request.Query_String+"&",'headers=',"&")="1",.T.,.F.)
llLabels = iif(strextract(Request.Query_String+"&",'labels=',"&")="1",.T.,.F.)

do case
case Request.Method = "GET"
	do case
	case Request.ID = "grid" 
		*--- Search grid definition
		addproperty(loResult,"headers[5]")
		
		loResult.Headers[1] = createobject("EMPTY")
		addproperty(loResult.Headers[1],"title","Name")
		addproperty(loResult.Headers[1],"data","naam")
		addproperty(loResult.Headers[1],"type","string")
		addproperty(loResult.Headers[1],"width","30%")
		loResult.Headers[2] = createobject("EMPTY")
		addproperty(loResult.Headers[2],"title","Address")
		addproperty(loResult.Headers[2],"data","adres")
		addproperty(loResult.Headers[2],"type","string")
		addproperty(loResult.Headers[2],"width","20%")
		loResult.Headers[3] = createobject("EMPTY")
		addproperty(loResult.Headers[3],"title","Place")
		addproperty(loResult.Headers[3],"data","postnrs_plaats")
		addproperty(loResult.Headers[3],"type","string")
		addproperty(loResult.Headers[3],"width","15%")
		loResult.Headers[4] = createobject("EMPTY")
		addproperty(loResult.Headers[4],"title","Mobile")
		addproperty(loResult.Headers[4],"data","gsm")
		addproperty(loResult.Headers[4],"type","string")
		addproperty(loResult.Headers[4],"width","15%")
		loResult.Headers[5] = createobject("EMPTY")
		addproperty(loResult.Headers[5],"title","Email")
		addproperty(loResult.Headers[5],"data","email")
		addproperty(loResult.Headers[5],"type","string")
		addproperty(loResult.Headers[5],"width","20%")
	case Request.ID = "form"
		*--- Form tabs
		addproperty(loResult,"titlefield","naam")
		addproperty(loResult,"tabpages[8]")
		
		loResult.TabPages[1] = createobject("EMPTY")
		addproperty(loResult.TabPages[1],"title","Address")
		addproperty(loResult.TabPages[1],"tab","1")
		addproperty(loResult.TabPages[1],"endpoint","/customers/${id}?tab=1")
		addproperty(loResult.TabPages[1],"pagetype","form")
		loResult.TabPages[2] = createobject("EMPTY")
		addproperty(loResult.TabPages[2],"title","Administration")
		addproperty(loResult.TabPages[2],"tab","2")
		addproperty(loResult.TabPages[2],"endpoint","/customers/${id}?tab=2")
		addproperty(loResult.TabPages[2],"pagetype","form")
		loResult.TabPages[3] = createobject("EMPTY")
		addproperty(loResult.TabPages[3],"title","Extra")
		addproperty(loResult.TabPages[3],"tab","3")
		addproperty(loResult.TabPages[3],"endpoint","/customers/${id}?tab=3")
		addproperty(loResult.TabPages[3],"pagetype","form")
		loResult.TabPages[4] = createobject("EMPTY")
		addproperty(loResult.TabPages[4],"title","History")
		addproperty(loResult.TabPages[4],"tab","4")
		addproperty(loResult.TabPages[4],"endpoint","/customers/${id}?tab=4")
		addproperty(loResult.TabPages[4],"pagetype","form")
		loResult.TabPages[5] = createobject("EMPTY")
		addproperty(loResult.TabPages[5],"title","Bill")
		addproperty(loResult.TabPages[5],"tab","5")
		addproperty(loResult.TabPages[5],"endpoint","/customers/${id}?tab=5")
		addproperty(loResult.TabPages[5],"pagetype","form")
		loResult.TabPages[6] = createobject("EMPTY")
		addproperty(loResult.TabPages[6],"title","Documents")
		addproperty(loResult.TabPages[6],"tab","6")
		addproperty(loResult.TabPages[6],"endpoint","/customers/${id}?tab=6")
		addproperty(loResult.TabPages[6],"pagetype","form")
		loResult.TabPages[7] = createobject("EMPTY")
		addproperty(loResult.TabPages[7],"title","Turnover")
		addproperty(loResult.TabPages[7],"tab","7")
		addproperty(loResult.TabPages[7],"endpoint","/customers/${id}?tab=7")
		addproperty(loResult.TabPages[7],"pagetype","form")
		loResult.TabPages[8] = createobject("EMPTY")
		addproperty(loResult.TabPages[8],"title","Data")
		addproperty(loResult.TabPages[8],"tab","8")
		addproperty(loResult.TabPages[8],"endpoint","/customers/${id}?tab=8")
		addproperty(loResult.TabPages[8],"pagetype","form")
	otherwise
		*--- Grid search
		if !empty(lcVar)
			addproperty(loResult,"Data[1]",NULL)
			
			if lcVar = "="
				lnVar = val(substr(lcVar,2))
				select nummer AS id, naam, adres, postnrs.plaats AS postnrs_plaats, gsm, email from klant left outer join postnrs on postnrs.newpost = klant.newpost where nummer = lnVar order by naam into cursor result
			else
				lcVar = upper(lcVar)+"%"
				select nummer AS id, naam, adres, postnrs.plaats AS postnrs_plaats, gsm, email from klant left outer join postnrs on postnrs.newpost = klant.newpost where naam like lcVar order by naam into cursor result
			endif
			
			select result
			if !eof()
				*--- Add items array
				dimension loResult.Data[reccount()]

				*--- Fill array with records as objects
				scan
					scatter name loResult.Data[recno()]
				endscan
			endif	
		endif

		*--- Form tabs fields definition
		do case
		case lcTab = "1"
			if llLabels
				*--- Set properties to rename
				dimension loJSON.PropertyAlias[1,2]
				loJSON.PropertyAlias[1,1] = 'text_transform' && VFP Object name
				loJSON.PropertyAlias[1,2] = 'text-transform' && JSON Object name
				
				*--- Add fields array elements
				addproperty(loResult,"labels[18]")
				
				loBlocks = createobject("EMPTY")
				addproperty(loBlocks,"width",12)
				addproperty(loResult,"blocks[1]")
				loResult.Blocks[1] = loBlocks

				loResult.Labels[1] = createobject("EMPTY")
				addproperty(loResult.Labels[1],"block",1)
				addproperty(loResult.Labels[1],"display","")
				addproperty(loResult.Labels[1],"fieldname","id")
				addproperty(loResult.Labels[1],"length",6)
				addproperty(loResult.Labels[1],"inputtype","hidden")

				loResult.Labels[2] = createobject("EMPTY")
				addproperty(loResult.Labels[2],"block",1)
				addproperty(loResult.Labels[2],"display","Name / Company:")
				addproperty(loResult.Labels[2],"tooltip","Name of the customer.")
				addproperty(loResult.Labels[2],"fieldname",'naam')
				addproperty(loResult.Labels[2],"length",40)
				addproperty(loResult.Labels[2],"inputtype",'text')
				addproperty(loResult.Labels[2],"newline",.T.)
				addproperty(loResult.Labels[2],"labelwidth",2)
				addproperty(loResult.Labels[2],"fieldwidth",4)
				addproperty(loResult.Labels[2],"pipe","uppercase")
				addproperty(loResult.Labels[2],"notempty",.T.)
				addproperty(loResult.Labels[2],"style",createobject("EMPTY"))
				addproperty(loResult.Labels[2].Style,"text_transform","uppercase")

				loResult.Labels[3] = createobject("EMPTY")
				addproperty(loResult.Labels[3],"block",1)
				addproperty(loResult.Labels[3],"display","Contact:")
				addproperty(loResult.Labels[3],"tooltip","Name of contact person.")
				addproperty(loResult.Labels[3],"fieldname",'naam2')
				addproperty(loResult.Labels[3],"length",40)
				addproperty(loResult.Labels[3],"inputtype",'text')
				addproperty(loResult.Labels[3],"newline",.F.)
				addproperty(loResult.Labels[3],"labelwidth",2)
				addproperty(loResult.Labels[3],"fieldwidth",4)
				addproperty(loResult.Labels[3],"pipe","uppercase")
				addproperty(loResult.Labels[3],"style",createobject("EMPTY"))
				addproperty(loResult.Labels[3].Style,"text_transform","uppercase")

				loResult.Labels[4] = createobject("EMPTY")
				addproperty(loResult.Labels[4],"block",1)
				addproperty(loResult.Labels[4],"display","Address:")
				addproperty(loResult.Labels[4],"tooltip","Address:")
				addproperty(loResult.Labels[4],"fieldname",'adres')
				addproperty(loResult.Labels[4],"length",40)
				addproperty(loResult.Labels[4],"inputtype",'text')
				addproperty(loResult.Labels[4],"newline",.T.)
				addproperty(loResult.Labels[4],"labelwidth",2)
				addproperty(loResult.Labels[4],"fieldwidth",4)
				addproperty(loResult.Labels[4],"pipe","uppercase")
				addproperty(loResult.Labels[4],"style",createobject("EMPTY"))
				addproperty(loResult.Labels[4].Style,"text_transform","uppercase")

				loResult.Labels[5] = createobject("EMPTY")
				addproperty(loResult.Labels[5],"block",1)
				addproperty(loResult.Labels[5],"display","Address 2:")
				addproperty(loResult.Labels[5],"tooltip","Address 2:")
				addproperty(loResult.Labels[5],"fieldname",'adres2')
				addproperty(loResult.Labels[5],"length",40)
				addproperty(loResult.Labels[5],"inputtype",'text')
				addproperty(loResult.Labels[5],"newline",.F.)
				addproperty(loResult.Labels[5],"labelwidth",2)
				addproperty(loResult.Labels[5],"fieldwidth",4)
				addproperty(loResult.Labels[5],"pipe","uppercase")
				addproperty(loResult.Labels[5],"style",createobject("EMPTY"))
				addproperty(loResult.Labels[5].Style,"text_transform","uppercase")

				loResult.Labels[6] = createobject("EMPTY")
				addproperty(loResult.Labels[6],"block",1)
				addproperty(loResult.Labels[6],"display",'')
				addproperty(loResult.Labels[6],"fieldname",'newpost')
				addproperty(loResult.Labels[6],"length",10)
				addproperty(loResult.Labels[6],"inputtype",'hidden')
				addproperty(loResult.Labels[6],"data",createobject("EMPTY"))
				addproperty(loResult.Labels[6].Data,"endpoint","/postnrs")
				addproperty(loResult.Labels[6].Data,"file","postnrs")
				addproperty(loResult.Labels[6].Data,"fieldname","newpost")

				loResult.Labels[7] = createobject("EMPTY")
				addproperty(loResult.Labels[7],"block",1)
				addproperty(loResult.Labels[7],"display","Zipcode:")
				addproperty(loResult.Labels[7],"tooltip","Postal code.")
				addproperty(loResult.Labels[7],"fieldname",'postnr')
				addproperty(loResult.Labels[7],"length",8)
				addproperty(loResult.Labels[7],"inputtype",'search')
				addproperty(loResult.Labels[7],"newline",.T.)
				addproperty(loResult.Labels[7],"labelwidth",2)
				addproperty(loResult.Labels[7],"fieldwidth",2)
				addproperty(loResult.Labels[7],"grid","postnrs")
				addproperty(loResult.Labels[7],"data",createobject("EMPTY"))
				addproperty(loResult.Labels[7].Data,"endpoint","/postnrs")
				addproperty(loResult.Labels[7].Data,"file","postnrs")
				addproperty(loResult.Labels[7].Data,"fieldname","postnr")
				addproperty(loResult.Labels[7].Data,"pagetype","modalgrid")
				addproperty(loResult.Labels[7].Data,"pagesize","xl")
				addproperty(loResult.Labels[7].Data,"hidefilter",.F.)
				addproperty(loResult.Labels[7].Data,"buttons[4]")
				loResult.Labels[7].Data.Buttons[1] = "select"
				loResult.Labels[7].Data.Buttons[2] = "add"
				loResult.Labels[7].Data.Buttons[3] = "edit"
				loResult.Labels[7].Data.Buttons[4] = "exit"
				addproperty(loResult.Labels[7].Data,"onclick",createobject("EMPTY"))
				addproperty(loResult.Labels[7].Data.OnClick,"endpoint","/postnrs/${id}")
				addproperty(loResult.Labels[7].Data.OnClick,"pagetype","modalform")
				addproperty(loResult.Labels[7].Data.OnClick,"pagesize","lg")
				addproperty(loResult.Labels[7].Data.OnClick,"hidefilter",.F.)
				addproperty(loResult.Labels[7].Data.OnClick,"buttons[2]")
				loResult.Labels[7].Data.OnClick.Buttons[1] = "save"
				loResult.Labels[7].Data.OnClick.Buttons[2] = "exit"
				addproperty(loResult.Labels[7].Data,"onedit",createobject("EMPTY"))
				addproperty(loResult.Labels[7].Data.OnEdit,"endpoint","/postnrs/${id}")
				addproperty(loResult.Labels[7].Data.OnEdit,"pagetype","modalform")
				addproperty(loResult.Labels[7].Data.OnEdit,"pagesize","lg")
				addproperty(loResult.Labels[7].Data.OnEdit,"hidefilter",.F.)
				addproperty(loResult.Labels[7].Data.OnEdit,"buttons[2]")
				loResult.Labels[7].Data.OnEdit.Buttons[1] = "save"
				loResult.Labels[7].Data.OnEdit.Buttons[2] = "exit"

				loResult.Labels[8] = createobject("EMPTY")
				addproperty(loResult.Labels[8],"block",1)
				addproperty(loResult.Labels[8],"display","")
				addproperty(loResult.Labels[8],"tooltip","Country codes")
				addproperty(loResult.Labels[8],"fieldname",'land')
				addproperty(loResult.Labels[8],"length",3)
				addproperty(loResult.Labels[8],"inputtype",'dropdown')
				addproperty(loResult.Labels[8],"newline",.F.)
				addproperty(loResult.Labels[8],"labelwidth",0)
				addproperty(loResult.Labels[8],"fieldwidth",2)							
				addproperty(loResult.Labels[8],"grid","landcodes")
				addproperty(loResult.Labels[8],"data",createobject("EMPTY"))							
				addproperty(loResult.Labels[8].Data,"endpoint","/landcodes")
				addproperty(loResult.Labels[8].Data,"file","landcodes")
				addproperty(loResult.Labels[8].Data,"fieldname","code")
				addproperty(loResult.Labels[8].Data,"hidefilter",.F.)
				addproperty(loResult.Labels[8].Data,"pagesize","")
				addproperty(loResult.Labels[8].Data,"pagetype","")
				addproperty(loResult.Labels[8].Data,"buttons[1]",NULL)
				addproperty(loResult.Labels[8].Data,"onclick",createobject("EMPTY"))
				addproperty(loResult.Labels[8].Data.OnClick,"endpoint","")
				addproperty(loResult.Labels[8].Data.OnClick,"pagetype","")
				addproperty(loResult.Labels[8].Data.OnClick,"pagesize","")
				addproperty(loResult.Labels[8].Data.OnClick,"hidefilter",.F.)
				addproperty(loResult.Labels[8].Data.OnClick,"buttons[1]",NULL)

				loResult.Labels[9] = createobject("EMPTY")
				addproperty(loResult.Labels[9],"block",1)
				addproperty(loResult.Labels[9],"display","Hometown:")
				addproperty(loResult.Labels[9],"tooltip","")
				addproperty(loResult.Labels[9],"fieldname",'postnrs_plaats')
				addproperty(loResult.Labels[9],"length",30)
				addproperty(loResult.Labels[9],"inputtype",'read_text')
				addproperty(loResult.Labels[9],"newline",.F.)
				addproperty(loResult.Labels[9],"labelwidth",2)
				addproperty(loResult.Labels[9],"fieldwidth",4)
				addproperty(loResult.Labels[9],"data",createobject("EMPTY"))							
				addproperty(loResult.Labels[9].Data,"endpoint","/postnrs")
				addproperty(loResult.Labels[9].Data,"file","postnrs")
				addproperty(loResult.Labels[9].Data,"fieldname","plaats")

				loResult.Labels[10] = createobject("EMPTY")
				addproperty(loResult.Labels[10],"block",1)
				addproperty(loResult.Labels[10],"display","")
				addproperty(loResult.Labels[10],"tooltip","")
				addproperty(loResult.Labels[10],"fieldname","")
				addproperty(loResult.Labels[10],"length",0)
				addproperty(loResult.Labels[10],"inputtype",'divider')
				addproperty(loResult.Labels[10],"newline",.T.)
				addproperty(loResult.Labels[10],"labelwidth",1)
				addproperty(loResult.Labels[10],"fieldwidth",11)							

				loResult.Labels[11] = createobject("EMPTY")
				addproperty(loResult.Labels[11],"block",1)
				addproperty(loResult.Labels[11],"display","Phone:")
				addproperty(loResult.Labels[11],"tooltip","Telephone")
				addproperty(loResult.Labels[11],"fieldname",'telefoon')
				addproperty(loResult.Labels[11],"length",16)
				addproperty(loResult.Labels[11],"inputtype",'phone')
				addproperty(loResult.Labels[11],"newline",.T.)
				addproperty(loResult.Labels[11],"labelwidth",2)
				addproperty(loResult.Labels[11],"fieldwidth",4)							

				loResult.Labels[12] = createobject("EMPTY")
				addproperty(loResult.Labels[12],"block",1)
				addproperty(loResult.Labels[12],"display","Fax.")
				addproperty(loResult.Labels[12],"tooltip","Fax.")
				addproperty(loResult.Labels[12],"fieldname",'telefoon2')
				addproperty(loResult.Labels[12],"length",16)
				addproperty(loResult.Labels[12],"inputtype",'phone')
				addproperty(loResult.Labels[12],"newline",.F.)
				addproperty(loResult.Labels[12],"labelwidth",2)
				addproperty(loResult.Labels[12],"fieldwidth",4)							

				loResult.Labels[13] = createobject("EMPTY")
				addproperty(loResult.Labels[13],"block",1)
				addproperty(loResult.Labels[13],"display","Mobile:")
				addproperty(loResult.Labels[13],"tooltip","Mobile number")
				addproperty(loResult.Labels[13],"fieldname",'gsm')
				addproperty(loResult.Labels[13],"length",16)
				addproperty(loResult.Labels[13],"inputtype",'phone')
				addproperty(loResult.Labels[13],"newline",.T.)
				addproperty(loResult.Labels[13],"labelwidth",2)
				addproperty(loResult.Labels[13],"fieldwidth",4)						

				loResult.Labels[14] = createobject("EMPTY")
				addproperty(loResult.Labels[14],"block",1)
				addproperty(loResult.Labels[14],"display","E-Mail:")
				addproperty(loResult.Labels[14],"tooltip","E-Mail address.")
				addproperty(loResult.Labels[14],"fieldname",'email')
				addproperty(loResult.Labels[14],"length",40)
				addproperty(loResult.Labels[14],"inputtype",'email')
				addproperty(loResult.Labels[14],"newline",.T.)
				addproperty(loResult.Labels[14],"labelwidth",2)
				addproperty(loResult.Labels[14],"fieldwidth",10)							
				addproperty(loResult.Labels[14],"pipe","lowercase")
				addproperty(loResult.Labels[14],"style",createobject("EMPTY"))
				addproperty(loResult.Labels[14].Style,"text_transform","lowercase")

				loResult.Labels[15] = createobject("EMPTY")
				addproperty(loResult.Labels[15],"block",1)
				addproperty(loResult.Labels[15],"display","")
				addproperty(loResult.Labels[15],"tooltip","")
				addproperty(loResult.Labels[15],"fieldname","")
				addproperty(loResult.Labels[15],"length",0)
				addproperty(loResult.Labels[15],"inputtype",'divider')
				addproperty(loResult.Labels[15],"newline",.T.)
				addproperty(loResult.Labels[15],"labelwidth",1)
				addproperty(loResult.Labels[15],"fieldwidth",11)							

				loResult.Labels[16] = createobject("EMPTY")
				addproperty(loResult.Labels[16],"block",1)
				addproperty(loResult.Labels[16],"display","VAT:")
				addproperty(loResult.Labels[16],"tooltip","")
				addproperty(loResult.Labels[16],"fieldname",'btw_kode')
				addproperty(loResult.Labels[16],"length",3)
				addproperty(loResult.Labels[16],"inputtype",'combobox')
				addproperty(loResult.Labels[16],"newline",.T.)
				addproperty(loResult.Labels[16],"labelwidth",2)
				addproperty(loResult.Labels[16],"fieldwidth",2)							
				addproperty(loResult.Labels[16],"options[4]")
				loResult.Labels[16].Options[1] = createobject("EMPTY")
				addproperty(loResult.Labels[16].Options[1],"option","Individual")
				addproperty(loResult.Labels[16].Options[1],"value","P")
				loResult.Labels[16].Options[2] = createobject("EMPTY")
				addproperty(loResult.Labels[16].Options[2],"option","Company")
				addproperty(loResult.Labels[16].Options[2],"value","B")
				loResult.Labels[16].Options[3] = createobject("EMPTY")
				addproperty(loResult.Labels[16].Options[3],"option","School")
				addproperty(loResult.Labels[16].Options[3],"value","V")
				loResult.Labels[16].Options[4] = createobject("EMPTY")
				addproperty(loResult.Labels[16].Options[4],"option","No VAT")
				addproperty(loResult.Labels[16].Options[4],"value","N")

				loResult.Labels[17] = createobject("EMPTY")
				addproperty(loResult.Labels[17],"block",1)
				addproperty(loResult.Labels[17],"display","")
				addproperty(loResult.Labels[17],"tooltip","")
				addproperty(loResult.Labels[17],"fieldname",'landcode')
				addproperty(loResult.Labels[17],"length",3)
				addproperty(loResult.Labels[17],"inputtype",'read_text')
				addproperty(loResult.Labels[17],"newline",.F.)
				addproperty(loResult.Labels[17],"labelwidth",0)
				addproperty(loResult.Labels[17],"fieldwidth",2)
				addproperty(loResult.Labels[17],"data",createobject("EMPTY"))							
				addproperty(loResult.Labels[17].Data,"endpoint","/landcodes")
				addproperty(loResult.Labels[17].Data,"file","landcodes")
				addproperty(loResult.Labels[17].Data,"fieldname","landcode")

				loResult.Labels[18] = createobject("EMPTY")
				addproperty(loResult.Labels[18],"block",1)
				addproperty(loResult.Labels[18],"display","VAT Nr.")
				addproperty(loResult.Labels[18],"tooltip","VAT number of the customer.")
				addproperty(loResult.Labels[18],"fieldname",'btw_nr')
				addproperty(loResult.Labels[18],"length",16)
				addproperty(loResult.Labels[18],"inputtype",'text')
				addproperty(loResult.Labels[18],"newline",.F.)
				addproperty(loResult.Labels[18],"labelwidth",2)
				addproperty(loResult.Labels[18],"fieldwidth",4)
			endif

			SendData(lcTab,@loResult)
		endcase
	endcase
case Request.Method = "POST"
	*--- Insert
	loJSON.Parse(Request.Content,,@loData)
	
	*--- Data type conversion
	if type("loData.newpost") = "C"
		loData.newpost = val(loData.newpost)
	endif
	
	try
		insert into klant from name loData

		Request.ID = alltrim(str(nummer))
		SendData(lcTab,@loResult)
	catch to oException
		addproperty(loResult,"error","Error: "+oException.Message)
	endtry
case Request.Method = "PUT"
	*--- Update
	loJSON.Parse(Request.Content,,@loData)

	try
		use klant
		locate for nummer = val(Request.ID)
		
		gather name loData memo

		SendData(lcTab,@loResult)
	catch to oException
		addproperty(loResult,"error","Error: "+oException.Message)
	endtry
case Request.Method = "DELETE"
	*--- Delete
	loJSON.Parse(Request.Content,,@loData)

	try
		delete from klant where nummer = val(Request.ID)

		addproperty(loResult,"Data[1]",NULL)
	catch to oException
		recall
		
		addproperty(loResult,"error","Erro: "+oException.Message)
	endtry
endcase

*--- Generate JSON
Response.Content      = loJSON.Stringify(@loResult)
Response.Content_Type = "application/json; charset=utf8"

*--- Release System and JSON Parser object
release loJSON

*--- Release class
clear class json

**********************************************************************************
FUNCTION SendData
*****************
LPARAMETERS lcTab,loData
	*--- Form data
	if !empty(Request.ID) AND Request.ID > "0"
		addproperty(loData,"Data[1]",NULL)

		do case
		case lcTab = "1"
			lcFields = "nummer AS id,naam,naam2,adres,adres2,klant.newpost,klant.postnr,landcode,land,postnrs.plaats AS postnrs_plaats,telefoon,telefoon2,gsm,email,btw_kode,btw_nr"
		endcase
		
		if !empty(lcFields)
			lcSelect = "select "+lcFields+" from klant left outer join postnrs on postnrs.newpost = klant.newpost where nummer = "+Request.ID+" into cursor result"
			&lcSelect
			
			select result
			if !eof()
				scatter name loData.Data[1]
			endif
		endif
	endif
ENDFUNC