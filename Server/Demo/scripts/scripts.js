function init(){
   showFirstNews();
}

function loadHTML(URI,Div){
var xmlhttp;
if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp=new XMLHttpRequest();
  }
else
  {// code for IE6, IE5
  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }

xmlhttp.onreadystatechange=function(){
  if (xmlhttp.readyState==4 && xmlhttp.status==200)
    {
    document.getElementById(Div).innerHTML=xmlhttp.responseText;
    }
  }

xmlhttp.open("GET",URI,true);
xmlhttp.send();
}

function showFirstNews(){
	DisplayText(news1,'news')
}

function showNextNews(){
   var NewstoShow=currentNews+1;
   if (NewstoShow > totalNews){
      NewstoShow=1;
   }
   DisplayText(eval('news'+NewstoShow),'news');
   currentNews=NewstoShow;
}

function showPreviousNews(){
   var NewstoShow=currentNews-1;
   if (NewstoShow < 1){
      NewstoShow=totalNews;
   }
   DisplayText(eval('news'+NewstoShow),'news');
   currentNews=NewstoShow;
}

function DisplayText(text,fieldName){
   document.getElementById(fieldName).innerHTML=text
}

function teletype(textLayer) {
   if (textLayer.i == null) {
      textLayer.i = -1;
      textLayer.chri = 0;
      textLayer.txt = textLayer.innerHTML;
      textLayer.lng = textLayer.txt.length;
      textLayer.innerHTML = "";
      textLayer.style.visibility = "visible";
      textLayer.msg = "";
   }

   if (textLayer.i < textLayer.lng) {
      for (textLayer.i = 0; textLayer.i < textLayer.lng; textLayer.i++) {
         chr = textLayer.txt.charAt(textLayer.i)
         if (chr == "<") {
            aTag = "<";
            while (chr != ">") {
               textLayer.i++;
               chr = textLayer.txt.charAt(textLayer.i);
               aTag = aTag + chr;
            }
            aTag = aTag;
            textLayer.msg = textLayer.msg + aTag;
         }

         if (chr == "&") {
            aTag = "&";
            while (chr != ";") {
               textLayer.i++;
               chr = textLayer.txt.charAt(textLayer.i);
               aTag = aTag + chr;
            }
            chr = aTag;
         }

         if (chr != ">") {
            textLayer.msg = textLayer.msg + "<span style='display: none' id=" + textLayer.id + "_" + textLayer.chri + ">" + chr + "</span>";
            textLayer.chri++;
         }
      }
   }

   if (textLayer.i == textLayer.lng) {
      if (textLayer.cmpl == null) {
         textLayer.innerHTML = textLayer.msg;
         textLayer.cmpl = textLayer.chri;
         textLayer.chri = 0;
      }
      if (textLayer.chri < textLayer.cmpl) {
         t = eval(textLayer.id + "_" + textLayer.chri);
         t.style.display = "";
         textLayer.chri++;
         ab1 = window.setTimeout("teletype(" + textLayer.id + ")", 20);
      }
   }
}

function Array() {
   this.length = Array.arguments.length;
   for (var i = 0; i < this.length; i++)
   this[i+1] = Array.arguments[i];
}

function CabJornal() {
   var now = new Date();
   var mes = new Array("janeiro","fevereiro","março","abril","maio","junho","julho","agosto","setembro","outubro","novembro","dezembro");
   var dia = ((now.getDate()<10)?"0":"")+now.getDate();
   return dia+" de "+mes[now.getMonth()+1]+" de "+now.getFullYear();
}
