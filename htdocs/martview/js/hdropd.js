/*This file retrieved from the JS-Examples archives
  http://www.js-examples.com
  100s of free ready to use scripts, tutorials, forums.
  Author: Orange web soft team - http://javer.narod.ru/dropdinst.htm */

var ns ;
var ie ;
var n6;
var W;
var pForm;

//----------------------------------------------------------------------
function BrowserCheck() {
  var b = navigator.appName;
  if (b=="Netscape"){ 
    this.b = "ns";
    ns=true; 
  }
  else{
    if (b=="Microsoft Internet Explorer"){
      this.b = "ie";
      ie=true;
    }
    else{ this.b = b }
  }
  this.version = navigator.appVersion;
  this.v = parseInt(this.version);
  if(ns&&this.v>4){ns=false;n6=true;};
  if(ns||n6){W=window.innerWidth-16}else{W=document.body.offsetWidth-20;}
}

//----------------------------------------------------------------------
function TreeItem( id, parid, name )
{
    this.vname="DdMenu"+TreeItem.dmcount;
    TreeItem.dmcount++; 

    this.id     = id;
    this.parid  = parid;
    this.name   = name;

    this.frname="";
    this.parentItem=null;
    this.items=new Array();
    this.itemCount=0;
    this.Opened=true;

    this.fntColor    = "#202080";
    this.selFntColor = "#5484D7";
    this.fntSize     = 2;
    this.css         = null;
    this.bckColor    = "#FFFFCC";
    this.selBckColor = "#FFE75C";
    this.alinkColor  = "#ffff00";

    this.arrIm       = "/martview/images/bullet1.gif"; // Image src
    this.iHeight     = 21;                         // Row height
    this.imHeight    = 10;                         // Image height

    this.imSrc       = 
	"<img src='" + this.arrIm + "' height=10 width=10 border=0>" 

    this.xpos     = 12;
    this.ypos     = 17;
    this.selected = 0;
    this.height   = 600;
    this.width    = 250;
    this.focus    = -1;
    this.bSize    = 2;
    this.tW       = 0;
    this.tH       = 0;
    this.bColor   = "darkblue";

    this.WriteCSS    = TreeItemWriteCSS;
    this.Show        = TreeItemShow;
    this.Add         = TreeItemAdd;
    this.WriteDiv    = TreeItemWriteDiv;
    this.Get         = TreeItemGet;
    this.A           = TreeItemA;
    this.moveHandler = TreeItemMove;    
    this.downHandler = TreeItemDown;
    this.Reset       = TreeItemReset;
    this.EventInit   = TIEventInit;
    this.Write       = TreeItemWrite;
    this.normText    = "";
    this.selText     = "";

    eval(this.vname + "=this");
}

//----------------------------------------------------------------------
function TreeItemGet(id){
  if(id==this.id) return this;
  for(var i=0;i<this.itemCount;i++){
    It=this.items[i].Get(id);
    if(It!=null) return It;
  }
  return null;
}

//----------------------------------------------------------------------
function TreeItemA(id,parid,name){
  It=new TreeItem(id,parid,name);
  this.Add(It);
}

//----------------------------------------------------------------------
function TreeItemAdd(item){
    item.Opened=false;
    It=this.Get(item.parid);
    status="item got "+item.id;
    if(item.parid==this.id){
	item.width=this.width;
	item.bckColor=this.bckColor;
	item.selBckColor=this.selBckColor;
	item.fntColor=this.fntColor;
	item.fntSize=this.fntSize;
	item.iHeight=this.iHeight;
	//item.imWidth=this.imWidth;
	item.arrIm=this.arrIm;
	item.selFntColor=this.selFntColor;
	this.items[this.itemCount]=item;
	item.parentItem=this;
	item.bSize=this.bSize;
	item.bColor=this.bColor;
	//if(ie||n6)
	item.visibility="hidden";
	//if(ns)item.visibility="hide";
	this.itemCount++;
	return;
    }
    if(It!=null) {It.Add(item);return;}
}

//----------------------------------------------------------------------
//var foo=1;
function TreeItemWriteDiv(){

    if(this.itemCount<1) return false;

    document.write("<DIV ID='" + this.vname + "'>" +
		   "<table border='" + this.bSize +
		   "' width='"       + this.tW    +
		   "' height='"      + this.tH    +
		   "' bordercolor='" + this.bColor+
		   "' ><tr><td>");

    var startTable = 
	"<table border='0'" +
	"  width='"  + this.width +
	"' height='" + this.iHeight+
	"' cellspacing='0' cellpadding='0'><tr>"; 

    for(var i=0; i<this.itemCount; i++){
	im="";
	cl="";
	scl="";
	cl =" color='" + this.fntColor   +"'";
	scl=" color='" + this.selFntColor+"'";

	if( this.items[i].itemCount > 0 && this.arrIm != "" ){
	    im = this.imSrc;
	}

	this.items[i].normText= startTable +
	    "<td width='" + this.width  + "'>" +
            "<font " + cl + " size='" + this.fntSize + "'>" + 
	    "<div id='" + this.items[i].vname + "t'>&nbsp;" + 
	    this.items[i].name + 
	    "</div></font></td>"+
            "<td align='right' width="+ this.iHeight + ">" + im +
	    "</td></tr></table>";

	this.items[i].selText= startTable +
	    "<td width='" + this.width   + "'>" + 
	    "<font " + scl+" size='"  + this.fntSize + "'>" +
	    this.items[i].name +
	    "</font></td>" + 
	    "<td align='right' width='" + this.iHeight + "'>&nbsp;" + im +
	    "</td></tr></table>";

	document.write("<DIV ID='"+this.items[i].vname+"i' >");
	document.write(this.items[i].normText);
	document.write("</DIV>\r\n");

	if(ie){
	    this.items[i].ilayer=document.all[this.items[i].vname+"i"];
	    this.items[i].tlayer=document.all[this.items[i].vname+"t"];
	}

	if(n6){
	    this.items[i].ilayer=document.getElementById(this.items[i].vname+"i");
	    this.items[i].tlayer=document.getElementById(this.items[i].vname+"t");
	    this.items[i].tlayer.style.color=this.items[i].fntColor;
	    this.items[i].tlayer.style.fontSize=6+2*this.items[i].fntSize+"pt";
	};

	if(ns){
	    this.items[i].ilayer=eval("document."+
				      this.vname+
				      ".document."+
				      this.items[i].vname+
				      "i");
	}
    }

    document.write("</td></tr></table></DIV>\r\n");
    for(var i=0;i<this.itemCount;i++){
	this.items[i].WriteDiv();
    }
    if(ie){
	this.layer=document.all[this.vname];
	this.css=this.layer.style;
    }
    if(n6){
	this.layer=document.getElementById(this.vname);
	this.css=this.layer.style;
    }
    if(ns){
	this.layer=eval("document."+this.vname);
	this.css=this.layer;
    }
}

//----------------------------------------------------------------------
function TIEventInit()
{
    for(var i=0;i<this.itemCount;i++){
	this.items[i].EventInit();
    }
    
    for(var i=0;i<this.itemCount;i++){
	var style=this.items[i].ilayer;
	style.onmouseover=new Function(this.vname+
				       ".moveHandler("+
				       i+
				       ");return false;");
	style.onmousedown=new Function(this.vname+
				       ".downHandler("+
				       i+
				       ");return false;");
	if(ns){
	    style.captureEvents(Event.MOUSEDOWN | 
				Event.MOUSEMOVE | 
				Event.MOUSEUP);
	}
    }
    status="Menu inited"+this.id;
}

//----------------------------------------------------------------------
function TreeItemWriteCSS()
{
    var dx;
    var dy;
    var bCol=(ns) ? "layer-background-color:" : "background-color:";
    Height=this.itemCount*this.iHeight+2*this.bSize;
    Width=this.width+2*this.bSize;
    dx=0;
    dy=this.iHeight;
    this.tH=Height; 
    this.tW=Width;



    if(this.itemCount>0){
	if(this.parentItem==null){
	    document.write("<STYLE TYPE='text/css'><!--");
	}
	document.write("#" + this.vname +
		       " {position:absolute;" + ";"+
		       "left:"        + this.xpos + "px;" +
		       "top:"         + this.ypos + "px;" +
		       "width:"       + Width     + "px;" +
		       "visibility: " + this.visibility   +
		       "; cursor: hand; z-index:1;}\r\n");

	for(var i=0;i<this.itemCount;i++){
	    var nxpos=this.xpos+this.width;
	    var nypos=this.ypos+i*this.iHeight;

	    if(nxpos+this.width>W) nxpos=nxpos-2*this.width;
	    this.items[i].xpos=nxpos;this.items[i].ypos=nypos;

	    document.write("#" + this.items[i].vname +
			   "i {position:absolute;"   + 
			   bCol + this.items[i].bckColor + ";" +
			   "top:"   + (i*dy+this.bSize) + "px;" + 
			   "left:"  + (i*dx+this.bSize) + "px;" +
			   "width:" + this.width        + "px;" +
			   "height:"+ this.iHeight      +
			   "px; z-index:1;}\r\n");
		
	    this.items[i].WriteCSS();
	}
	if(this.parentItem==null)document.write("--></STYLE>\r\n");
    }
}

//----------------------------------------------------------------------
function TreeItemShow(o)
{
    if(this.itemCount<1){ return; }
    this.focus=-1;
    
    if( o==1 ){
	this.css.visibility=(ns)? "show":"visible";
    }
    else{
	for( var i=0; i<this.itemCount; i++){
	    this.items[i].Show(0);
	}
	this.css.visibility=(ns) ? "hide" : "hidden";
    }
}

//----------------------------------------------------------------------
function TreeItemMove(i)
{
    if(this.itemCount<1){ return; }
    sel=i;
    if(sel!=this.focus||sel==0){
	this.items[this.selected].Show(0);
	this.items[sel].Show(1);
	if(sel!=this.focus){
	    var c1=this.items[this.selected].bckColor;
	    var c2=this.items[sel].selBckColor;


	    if(ie||n6){
		this.items[this.selected].ilayer.style.backgroundColor=c1;
		this.items[sel].ilayer.style.backgroundColor=c2;
		this.items[this.selected].ilayer.style.background=c1;
		this.items[sel].ilayer.style.background=c2;
		this.items[this.selected].tlayer.style.color=this.items[this.selected].fntColor;
		this.items[sel].tlayer.style.color=this.items[sel].selFntColor;
	    }
	    if(ns){
		var style=this.items[this.selected].ilayer;
		var style1=this.items[sel].ilayer;
		style.document.bgColor=c1;
		style1.document.bgColor=c2; 
		this.Write(this.selected,this.items[this.selected].normText);
		this.Write(sel,this.items[sel].selText);
	    }
	    
	}
	this.selected=sel;this.focus=sel;
    }
}

//----------------------------------------------------------------------
function TreeItemDown(i)
{
    sel=i;
    // Ensembl specific action!     
    
    // Trim pForm - it has leading whitespace, but I don't know why.
    while (pForm.charAt(0) == ' ')
    pForm = pForm.substring(1);
    
    // Use search code copied from martview.js
	var existingParamElts = opener.document.getElementsByTagName("input");
    	var loop_length = existingParamElts.length; // vv important thing in JS, for DOM API. speeds up 
    	for(x = 0; x < loop_length; x++) 
    	{
    	
          if (existingParamElts[x].getAttribute("name") == pForm)
		{
			myForm =  existingParamElts[x];
    		myForm.value=this.items[sel].name;
    		myForm.onblur();
    		return;
          }
	}
	// Textareas are not inputs, unfortunately, so we have to search for them separately.
	existingParamElts = opener.document.getElementsByTagName("textarea");
    	loop_length = existingParamElts.length; // vv important thing in JS, for DOM API. speeds up 
    	for(x = 0; x < loop_length; x++) 
    	{
          if (existingParamElts[x].getAttribute("name") == pForm)
		{
			myForm =  existingParamElts[x];
    		myForm.value=this.items[sel].name;
    		myForm.onblur();
    		return;
          }
	}
    
}

//----------------------------------------------------------------------
function TreeItemReset()
{
    for(var i=0;i<this.itemCount;i++)this.items[i].Show(0);
    this.focus=-1;
}

//----------------------------------------------------------------------
function TreeItemWrite(i,text)
{
    if(n6||ie) this.items[i].ilayer.innerHTML=text;
    if(ns){
	var style=this.items[i].ilayer;
	style.document.open();
	style.document.write(text);
	style.document.close();
    }
}

//----------------------------------------------------------------------
TreeItem.dmcount=0;

//----------------------------------------------------------------------
function MenuInit()//Inits menu Events
{
    TE.EventInit();
}

//----------------------------------------------------------------------
function Reset()//Reseting menu
{
    TE.Reset();
}
