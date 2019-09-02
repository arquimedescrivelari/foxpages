* This file is used to print the structures of fields, index, views in a database
* The name of the database with path must be passed on (path could be from current 
* directory f.e. COMMONDB\mydb.dbc where COMMONDB is sub-dir of current directory)

* Though the VFP's own documentation wizard could be used, I was not much impressive
* with that since I burnt my finger once choosing and it corrupted some of my source 
* code. Secondly, it gives too much information which I do not need.

* This program would generate an output file with the name same as database but with
* extention .HTM and place it in the same directory as database.

* I have not spent much error trapping as of now in this program.

* Call syntax => do dbcdoc with "mydb.dbc"

* I am happy if you find this small utility usefull.
* Regards Vijayaraman - vijayaramanl@hotmail.com

cDBName = "fps.dbc"

LOCAL i, j, cListFile, cDBShortName, cDBFullName, cTemp, cTemp2

close databases all

SET EXCLUSIVE OFF
SET DATE BRITISH
cDBName = DefaultExt(cDBName, 'DBC')
IF !File(cDBName)
	MessageBox("Database not found.")
	Return
EndIf
OPEN DATA (cDBName)
cListFile = ADATABASES(aTMP)
IF VarType(aTMP) = "U"
	MessageBox("Can't open database.")
	Return
EndIF
cDBFullName = aTMP[1,2]
cDBShortName = aTMP[1,1]
cListFile = lower(Left(cDBFullName, Len(cDBFullName)-4)+".HTML")

SET TEXTMERGE TO (cListFile) NOSHOW
SET TEXTMERGE ON

*ADBObjects(aDBTable, "Table")

dimension aDBTable[7]
aDBTable[1] = "SERVERS"
aDBTable[2] = "SITES"
aDBTable[3] = "GATEWAYS"
aDBTable[4] = "REALMS"
aDBTable[5] = "USERS"
aDBTable[6] = "REALMUSER"
aDBTable[7] = "CORS"

If VarType(aDBTable) <> "U"
	* Sort the array
*	ASort(aDBTable)
	\<HTML>
	\<HEAD><TITLE>DATABASE</TITLE></HEAD>
	\<BODY>
	\<TABLE CELLSPACING=0 BORDER=1 CELLPADDING=1 WIDTH=950>
		\<TR><TD VALIGN="CENTER">
		\<P ALIGN="CENTER"><B><FONT FACE="Arial" COLOR="#0000ff">DATABASE TABLES - <<cDBShortName>></P></B></FONT>
		\</TD></TR>
	\</TABLE>
	\<BR>

	For i = 1 To ALen(aDBTable)
		Wait "Abrindo tabela "+aDBTable[i] Window Nowait
		USE (aDBTable[i]) ALIAS cPRNTable
		IF USED('cPRNTable')
			IF AFields(aTblField, 'cPRNTable') <= 0
				USE IN cPRNTable
				LOOP
			ENDIF
			\<FONT FACE="Arial" COLOR="#ff0000"><B>Table: <<aDBTable[i]>></B></FONT>
			\<FONT FACE="Arial"> (Fields: <<ALen(aTblField,1)>>)</FONT>
			\<BR><BR>
			\<FONT FACE="Arial" COLOR="#ff0000"><B><<STRTRAN(DBGETPROP(aDBTable[i], "Table", "Comment" ),chr(13),"<BR>")>></B></FONT>
			\<BR><BR>
			
			\<TABLE BORDER CELLSPACING=0 CELLPADDING=1 WIDTH=950>
			\<TR ALIGN="CENTER">
				\<TD VALIGN="CENTER"><B>Name</B></TD>
				\<TD VALIGN="CENTER"><B>Type</B></TD>
				\<TD VALIGN="CENTER"><B>Length</B></TD>
				\<TD VALIGN="CENTER"><B>Decimals</B></TD>
				\<TD VALIGN="CENTER"><B>Nulls</B></TD>
				\<TD VALIGN="CENTER"><B>Default</B></TD>
				\<TD VALIGN="CENTER"><B>Comments</B></TD>
			\</TR>
			For j = 1 To ALen(aTblField,1)
				
				\<TR ALIGN="CENTER">
					cFieldComment = DBGETPROP(aDBTable[i]+"."+aTblField[j,1], "Field", "Comment" )
					
					\<TD ALIGN="LEFT" VALIGN="CENTER"><<aTblField[j,1]>></TD>
					\<TD VALIGN="CENTER"><<aTblField[j,2]>></TD>
					\<TD VALIGN="CENTER"><<aTblField[j,3]>></TD>
					\<TD VALIGN="CENTER"><<aTblField[j,4]>></TD>
					\<TD VALIGN="CENTER"><<IIF(aTblField[j,5],"Yes","No")>></TD>
					\<TD VALIGN="CENTER"><<IIF(Empty(aTblField[j,9]),"-",aTblField[j,9])>></TD>
					\<TD ALIGN="LEFT" VALIGN="CENTER"><<IIF(Empty(cFieldComment),"-",strtran(cFieldComment,chr(13),"<BR>"))>></TD>
				\</TR>
			EndFor
			\</TABLE>
			\<FONT FACE="Arial" COLOR="#ff0000"><B>Indexes:</B></FONT>
			\<TABLE BORDER CELLSPACING=0 CELLPADDING=1 WIDTH=950>
			\<TR ALIGN="CENTER">
				\<TD VALIGN="CENTER"><B>Label</B></TD>
				\<TD VALIGN="CENTER"><B>Primary</B></TD>
				\<TD VALIGN="CENTER"><B>Key</B></TD>
			\</TR>
			For j = 1 To TagCount()
				\<TR ALIGN="CENTER">
					\<TD ALIGN="LEFT" VALIGN="CENTER"><<Tag(j)>></TD>
					\<TD VALIGN="CENTER"><<IIF(Primary(j),"Yes","No")>></TD>
					\<TD ALIGN="LEFT" VALIGN="CENTER"><<Key(j)>></TD>
				\</TR>
			EndFor
			\</TABLE>
			\<BR><BR>
			USE IN cPRNTable
		ENDIF
	EndFor
EndIf
Release aDBTable

\</BODY>
\</HTML>
SET TEXTMERGE TO
SET TEXTMERGE OFF
Wait Clear

quit