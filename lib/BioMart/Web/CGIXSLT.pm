# CGIXSLT
# CGI XSLT Processor
#
# Copyright (c) 2003-2004 Gennadii Varzugin
# All rights reserved.
# Documentation and support
# http://www.dopscripts.com
# This program is free software. You can redistribute it and/or
# modify it under the same terms as Perl itself.

package BioMart::Web::CGIXSLT;
use strict;
use vars qw($VERSION $XML_BASE $XSLT_BASE);
use XML::Parser;
$VERSION=1.0;
##############  initial bases and max content size #########
$XML_BASE='';
my $_xml_base_flag=0;
$XSLT_BASE='';
my $MAX_CONTENT_SIZE=1024;
my @stack_1=();
############## XML-tree  ###################################

sub newnode  
{   
my ($name, $data)=@_;
my $ret={};
$ret->{children}=[];
$ret->{nodename}=$name;
$ret->{nodedata}=$data;
return $ret;
};

my $_root=undef;
my $_source_style='';
my @_opened_stylesheets=();

sub is_file_name_notsafe
{my $name=shift;
  if ($name =~ /^\s*[|>+]/
      or $name =~ /\|\s*$/) {return 1;};
return 0;
}

sub file_name
{my ($base,$file)=@_;
#the following code from XML::Parser package of 
#Larry Wall and Clark Cooper is what we need here
my $newfile=$file;
  if ($base
      and not ($file =~ m!^(?:[\\/]|\w+:)!))
    {
      $newfile = $base;
      $newfile =~ s![^\\/:]*$!$file!;
    };
  if (is_file_name_notsafe($newfile)) {
  error_log("File ($newfile) contains Perl IO control characters\n");
  exiting_code("File heandling error\n");
  }

return $newfile;
}

my $CHARS_MODEL='';
sub createtree 
{my ($file,$f_type)=@_;

#my @stack=();
$_root=newnode('/','');
$_root->{attsnumb}=0;

sub elstart
   { 
	my ($p, $el, %atts)=@_;
	my $n={};
	$n->{nodename}=$el;
	$n->{children}=[];
	$n->{nodedata}='';
	my $i=0;
	for my $aname (keys %atts) {
		my $anode={};
		$anode->{nodename}=join('','@',$aname);
		$anode->{nodedata}=$atts{$aname};
		$anode->{children}=[];
		push @{$n->{children}}, $anode;
		$i++;
	};
	$n->{attslist}={%atts};
	$n->{attsnumb}=$i;
	push @{$_root->{children}}, $n;
	push @stack_1, $_root;
	$_root=$n;
   }

sub elstart_b
   { 
	my $p=$_[0];
	my $n={};
	my $elstr=$p->original_string();
	$elstr=~/^\<(.+?)[\s\/\>]/;
	my $el=$1;
	$n->{nodename}=$el;
	$n->{children}=[];
	$n->{nodedata}='';
	$elstr=substr($elstr,length($el)+2);
	$elstr=~s/\/?\>$//gs;
	$elstr=~s/^\s+//g;
	$elstr=~s/\s+$//g;
	my $nattslist={};
	if($elstr){
	$elstr=~s/\s*(.+?)\s*\=\s*(\"|\')(.*?)\2/$nattslist->{$1}=$3;/egs;
	};
	my $i=0;
	for my $aname (keys %{$nattslist})
		{
		my $anode={};
		$anode->{nodename}=join('','@',$aname);
		if($nattslist->{$aname}=~/\&/){
			my $str=$nattslist->{$aname};
		    $str=~s/\&lt\;/\</gs;
	        $str=~s/\&gt\;/\>/gs;
		    $str=~s/\&nbsp\;/\xA0/gs;
		    $str=~s/\&quot\;/\"/gs;
			$str=~s/\&apos\;/\'/gs;
			$str=~s/\&amp\;/\&/gs;
			$nattslist->{$aname}=$str;
		};
		$anode->{nodedata}=$nattslist->{$aname};
		$anode->{children}=[];
		push @{$n->{children}}, $anode;
		$i++;
		};
    $n->{attslist}=$nattslist;
	$n->{attsnumb}=$i;
	push @{$_root->{children}}, $n;
	push @stack_1, $_root;
	$_root=$n;
   }

sub elend
   {
	my ($p, $el)=@_;
	$_root=pop @stack_1;
   }

sub chdata_b
   {
	my $p=$_[0];
	my $str=$p->original_string();
	if($str=~/\&/){
		$str=~s/\&lt\;/\</gs;
	    $str=~s/\&gt\;/\>/gs;
		$str=~s/\&nbsp\;/\xA0/gs;
		$str=~s/\&quot\;/\"/gs;
		$str=~s/\&apos\;/\'/gs;
		$str=~s/\&amp\;/\&/gs;
				  };
	my $i=$#{$_root->{children}};
	if($i>=0)
	   {
	my $chlast=$_root->{children}->[$i];
	if($chlast->{nodename} eq 'text()'){$chlast->{nodedata}.=$str;goto END;};
	   };
	my $n={};
	$n->{nodename}='text()';
	$n->{children}=[];
	$n->{nodedata}=$str;
	push @{$_root->{children}}, $n;
	END:
   }

sub chdata
   {
	my ($p, $str)=@_;
	my $i=$#{$_root->{children}};
	if($i>=0)
	   {
	my $chlast=$_root->{children}->[$i];
	if($chlast->{nodename} eq 'text()'){$chlast->{nodedata}.=$str;goto END;};
	   };
	my $n={};
	$n->{nodename}='text()';
	$n->{children}=[];
	$n->{nodedata}=$str;
	push @{$_root->{children}}, $n;
	END:
   }

sub st_pi
	{my ($p,$target,$data)=@_;
     if($target eq 'xml-stylesheet')
		{if($data=~/href\s*=\s*(\"|\')(.+?)(\"|\')/s){$_source_style=$2;};
		 $p->setHandlers('Proc'=>undef);};
	}

sub decl
{my ($p, $ver, $enc, $stalone)=@_;
 if(defined($enc) && ($enc eq 'bytes')){$p->setHandlers('Char'=>\&chdata_b,'Start'=>\&elstart_b);
 if(not($CHARS_MODEL)){$CHARS_MODEL='bytes';};
 }else{if(not($CHARS_MODEL)){$CHARS_MODEL='unicode';};};
}

my $p0=new XML::Parser(ErrorContext=>1);
$p0->setHandlers('XMLDecl'=>\&decl, 'Start'=>\&elstart, 'End'=>\&elend, 'Char'=>\&chdata);

if($f_type eq 'xml')
{
$file=file_name($XML_BASE,$file);
$p0->setHandlers('Proc'=>\&st_pi);
$XML_BASE=$file;
}
elsif($f_type eq 'xsl')
{
$file=file_name($XSLT_BASE,$file);
$XSLT_BASE=$file;
}
else
{die "no file type\n";};


eval{$p0->parsefile($file);};
if($@){error_log("XML error in file \"$file\"\: $@ \n");exiting_code("XML error cannot read data or file, see log file\n");};
if($f_type eq 'xsl'){push @_opened_stylesheets, $file}; 
return $_root;
}

sub print_tree_text 
{
	my $node=shift;
	my $str=shift;
	my $rch=$node->{children};
	$$str.='<';
	$$str.=$node->{nodename};
	my $size=$#{$rch};
	my $ai=-1;
FOR:for(my $i=0;$i<=$size;$i++)
	{   my $ch=$rch->[$i]; 
		if($ch->{nodename}=~/^@/)
			{
             $ai++;
	         $$str.=join('',' ',substr($ch->{nodename},1),'=',"\"",$ch->{nodedata},"\"");
			}
		else{last FOR;}
	};
    if($ai==$size){$$str.='/>';}
	else
	{ $$str.='>';
	  $ai++; 
      for(my $k=$ai;$k<=$size;$k++)
		{
		   my $ch=$rch->[$k];
		   if($ch->{nodename} eq 'text()')
		     {$$str.=$ch->{nodedata};}
		   elsif($ch->{nodename} eq 'comment()')
			 {$$str.=join('','<!--',$ch->{nodedata},'-->');} 
		   else
		     {print_tree_text($ch,$str);};
		};
      $$str.=join('','</',$node->{nodename},'>');
	};
}
my %_html_empty=('area'=>1,'base'=>1,'basefont'=>1, 'br'=>1, 'col'=>1, 
'frame'=>1, 'hr'=>1, 'img'=>1, 'input'=>1, 'isindex'=>1, 'link'=>1, 'meta'=>1,'param'=>1,
'colgroup'=>1, 'dd'=>1, 'dt'=>1, 'li'=>1, 'option'=>1, 'p'=>1, 'td'=>1, 'tfoot'=>1, 'th'=>1,'thead'=>1,'tr'=>1);
my %_html_codes_el=('script'=>1,'SCRIPT'=>1,'Script'=>1,
'style'=>1,'STYLE'=>1,'Style'=>1);
sub print_tree_html #############################################
{
	my $node=shift;
	my $str=shift;
	my $rch=$node->{children};
	$$str.='<';
	$$str.=$node->{nodename};
	my $size=$#{$rch};
	my $ai=-1;
FOR:for(my $i=0;$i<=$size;$i++)
	{   my $ch=$rch->[$i]; 
		if($ch->{nodename}=~/^@/)
			{
             $ai++;
			 $$str.=' ';
			 my $aname=substr($ch->{nodename},1);
			 $$str.=$aname;
			 my $astr=$ch->{nodedata};
			 if($aname ne $astr)
				{$$str.='="';
			     if(($aname ne 'href') and ($aname ne 'HREF'))
					{
			     if($astr!~/\&\{/){$astr=~s/\&/\&amp;/g;};
				    };
			 	 $astr=~s/>/\&gt;/sg;
				 $astr=~s/\"/\&quot;/sg;
				 $astr=~s/\xA0/\&nbsp;/sg;
				 $$str.=$astr;
			     $$str.='"';
				};
			}
		else{last FOR;}
	};
    if($ai==$size)
	{
		my $nname=lc($node->{nodename});$$str.='>';
	    if(not($_html_empty{$nname})){$$str.=join('','</',$node->{nodename},'>');};
	}
	else
	{ $$str.='>';
	  $ai++;
	  if($_html_codes_el{$node->{nodename}})
		  {for(my $k=$ai;$k<=$size;$k++)
		   {my $ch=$rch->[$k];if($ch->{nodename} eq 'text()'){$$str.=$ch->{nodedata};};};
		   goto endel;};
       for(my $k=$ai;$k<=$size;$k++)
		{
		   my $ch=$rch->[$k];
		   if($ch->{nodename} eq 'text()')
		     {if($ch->{noe}){$$str.=$ch->{nodedata};}
		      else{
			  my $nstr=$ch->{nodedata};
		      $nstr=~s/\&/\&amp;/gs;
		      $nstr=~s/</\&lt;/gs;
              $nstr=~s/>/\&gt;/gs;
              $nstr=~s/\"/\&quot;/gs;
			  $nstr=~s/\xA0/\&nbsp;/gs;
		      $$str.=$nstr;};
		     }
		   elsif($ch->{nodename} eq 'comment()')
			 {$$str.=join('','<!--',$ch->{nodedata},'-->');} 
		   else
		     {print_tree_html($ch,$str);};
		};
      endel:
      $$str.=join('','</',$node->{nodename},'>');
	};
}
my $stylesheet_prefix='';
my $result_prefix='';
sub print_tree_xml #############################################
{
	my $node=shift;
	my $str=shift;
	my $rch=$node->{children};
	$$str.='<';
	my $nn=$node->{nodename};
	if(not($stylesheet_prefix)){$$str.=$nn;}
	else{$nn=~s/^$stylesheet_prefix\:/$result_prefix\:/;$$str.=$nn;};
	my $size=$#{$rch};
	my $ai=-1;
FOR:for(my $i=0;$i<=$size;$i++)
	{   my $ch=$rch->[$i]; 
		if($ch->{nodename}=~/^@/)
			{
             $ai++;
			 $$str.=' ';
			 my $aname=substr($ch->{nodename},1);
			 $$str.=$aname;
			 my $astr=$ch->{nodedata};
			 $$str.='="';
			 $astr=~s/\&/\&amp;/gs;
			 $astr=~s/</\&lt;/gs;
             $astr=~s/>/\&gt;/gs;
			 $astr=~s/\"/\&quot;/gs;
			 $$str.=$astr;
			 $$str.='"';
			}
		else{last FOR;}
	};
    if($ai==$size)
	{
		$$str.='/>';
	}
	else
	{ $$str.='>';
	  $ai++;
       for(my $k=$ai;$k<=$size;$k++)
		{
		   my $ch=$rch->[$k];
		   if($ch->{nodename} eq 'text()')
		     {if($ch->{noe}){$$str.=$ch->{nodedata};}
		      else{
			  my $nstr=$ch->{nodedata};
		      $nstr=~s/\&/\&amp;/gs;
			  $nstr=~s/</\&lt;/gs;
              $nstr=~s/>/\&gt;/gs;
              $nstr=~s/\"/\&quot;/gs;
			  $$str.=$nstr;};
		     }
		   elsif($ch->{nodename} eq 'comment()')
			 {$$str.=join('','<!--',$ch->{nodedata},'-->');} 
		   else
		     {print_tree_xml($ch,$str);};
		};
      $$str.=join('','</',$nn,'>');
	};
}

########### stylesheet parameters  ##################################
my %template_modes=();
my %template_names=();
my %key_names=();
my %stylesheet_keys=();
my %XS_PARAMS=();
my %glob_strings=();
my %glob_objects=();
my %glob_vars=();
my @local_vars_values=();
my @local_vars_names=();
my $param_nums=0;
my $output_indent='';
my $output_method='';
my $output_encoding='';
my $omit_xmldecl='no';
my $cgi_object=undef;
my $xsltp_error_message=undef;
my @_http_fields=();
my @_http_contents=();
my $_http_flag=1;
my $_http_output=1;

sub print_with_method
{my ($metod,$ch,$str)=@_;
		   if($ch->{nodename} eq 'text()')
		     {$$str.=$ch->{nodedata};}
		   elsif($ch->{nodename} eq 'comment()')
			 {$$str.=join('','<!--',$ch->{nodedata},'-->');}
		   else
		     {if($metod eq 'xml'){print_tree_xml($ch,$str);}
		      elsif($metod eq 'html'){print_tree_html($ch,$str);}
		      elsif($metod eq 'text'){print_tree_text($ch,$str);}
			  else
				 {my $nname=$ch->{nodename};
				  if(($nname eq 'html') or ($nname eq 'HTML')){print_tree_html($ch,$str);}
				  else{print_tree_xml($ch,$str);};
				 };
		     };
}

sub save_to_file
{my $doc=shift;
 my $chs=$doc->{children};
 my %docatts;
 my $i=0;
 my $ch=$chs->[0];
 my $size=$#{$chs};
 while($ch->{nodename}=~/^@/)
	 {my $aname=substr($ch->{nodename},1);$docatts{$aname}=$ch->{nodedata};
      $i++;$ch=$chs->[$i];};
my $file=$docatts{'system'};
my $str='';
if($file)
	{$file=file_name($XML_BASE,$file);
     my $metod=$docatts{'method'};
	 if(!$metod){$metod=$output_method;};
	 my $encod=$docatts{'encoding'};
	 if(!$encod){$encod=$output_encoding;};
	 my $omit_decl=$docatts{'omit-xml-declaration'};
	 if(!$omit_decl){$omit_decl=$omit_xmldecl;};
	 if(($metod eq 'xml') and ($omit_decl eq 'no')){$str.='<?xml version="1.0"';
	  if($encod){$str.=' encoding=';$str.="\"$encod\"";};
	  $str.='?>';if($output_indent){$str.="\n";};};

	  while($i<=$size)
		{$ch=$chs->[$i];
          print_with_method($metod,$ch,\$str);  
	      $i++;
		};
open(FILE,"> $file") or exiting_code("cannot open ($file) for writing\n");
if($CHARS_MODEL eq 'bytes'){binmode(FILE);}
else{
     if($] > 5.007){binmode(FILE,":utf8");};
    };
print FILE $str;
close(FILE);
	}
else{exiting_code("xml\-document has no system attribute\n");};
}

sub print_doc
{
	my $node=shift;
	my $str=shift;
	my $rch=$node->{children};
	if(($output_method eq 'xml') and ($omit_xmldecl eq 'no')){$$str.='<?xml version="1.0"';
	  if($output_encoding){$$str.=' encoding=';$$str.="\"$output_encoding\"";};
	  $$str.='?>';
	};
	for my $ch (@{$rch})
	{if($ch->{nodename} eq 'xml-document'){save_to_file($ch);}
	 else{print_with_method($output_method,$ch,$str);}};
}

sub set_template_key  
{
my ($str, $htempl,$templates_keys,$cond)=@_;
my @a=split('/',$str);
if($str eq '/'){push @a,'/';};
if($a[0] eq ''){$a[0]='/';};
my $next='';
my $hname=$templates_keys;
my $hstate={};
my $last=pop @a;
loop: while(1)
{   $next=pop @a;
	if(!defined($hname->{$last})){$hname->{$last}={};};
    $hstate=$hname->{$last};
if(defined($next))
  {
	if($next ne '')
	{
		if(!defined($hstate->{parent})){$hstate->{parent}={};};
		$hname=$hstate->{parent};
		$last=$next;
	}else
	{
		if(!defined($hstate->{ancestor})){$hstate->{ancestor}={};};
		$hname=$hstate->{ancestor};
		$last=pop @a;
	};
  }
  else {last loop;};
};
  if(!defined($hstate->{template}))
	 {$hstate->{template}=[$htempl];
      $hstate->{condition}=[$cond];}
  else
	 {my $conds=$hstate->{condition};
      my $bool=1;
locfor:for(my $i=0;$i<=$#{$conds};$i++){my $ocond=$conds->[$i];
		                               if($ocond==$cond){$bool=0;last locfor;};};
	  if($bool)
		 {if($cond!=0){
		   unshift @{$hstate->{template}}, $htempl;
	       unshift @{$hstate->{condition}}, $cond;}
		   else{
		   push @{$hstate->{template}}, $htempl;
	       push @{$hstate->{condition}}, $cond;};
		 };
	  };
};

my @_focus_stack_=();
my @_count_stack_=();
my $_focus_=[];
my $_position_=0;
my $_last_=0;
my $_index_=0;
my $_last_node_=0;
########################### xpath #################################
my $_xpath_expr_error_=undef;
my $_fotal_error_=undef;
my @_expr_errors_code_=("1 missing \) or extra \( in xpath expression\n",
"2 missing \( or extra \) in xpath expression\n",
"3 invalid number of square brackets\n",
"4 missing right or left arg of binary operation\n",
"5 invalid expression, may be forgotten space before and after minus\n or invalid params of function or missing operation\n",
"6 wrong use of current, local-time or key function\n",
"7 invalid number of function arguments or not suppored function\n",
"8 id function is not supported, use key function instead\n",
"9 invalid step pattern in expression\n");

my $_default_path_expr={'opname'=>'#','right'=>{'axis'=>0,'name'=>'node()'}};
my @compiled_expresions=(undef,$_default_path_expr);
my $namber_of_exprs=2;
#my $_is_number='^-?(?:\d+(?:\.\d*)?|\.\d+)$';
my $_is_number='^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$';

my %_xpath_boolean=('false'=>1,'true'=>1,'boolean'=>1,'not'=>1,
'='=>1,'!='=>1,'and'=>1,'or'=>1,'>'=>1,'<'=>1,'>='=>1,'<='=>1,
'contains'=>1,'starts-with'=>1,'save-file'=>1);

my @literal_replace=undef;

sub xpath_errors
{
   my $ecode=shift;
   if($_xpath_expr_error_)
	   {$_xpath_expr_error_.=$_expr_errors_code_[$ecode];}
   else
	   {$_xpath_expr_error_=$_expr_errors_code_[$ecode];};
}

sub group_op 
{
	my $gr=shift;
	my $groups=shift;
		 if($gr=~/^\s*\(\s*(.*)\s*\)\s*(.*)/s)
		   {push @{$groups}, $1;if($2 ne ''){$gr=' '.$2;}else{$gr='';};};
		 while($gr ne '')
			{$gr=' '.$gr;  
			 if($gr=~/^\s*^(.*?)\s*(\sor\s|\sand\s|<=|>=|\!=|>|<|=|\+|\s\-\s|\smod\s|\sdiv\s|\*|,|\|)\s*(.*)\s*/s)
	            {$gr=$3;
			     my $op=$2; my $arg=$1;
			     $op=~s/^\s+//g;$op=~s/\s+$//g;
				   if($arg ne '')
					   { if($op ne '*')
						   {push @{$groups},$arg;}
				         else
						   {if($arg=~/(@|\:|\/)$/){$op=$arg.$op;}
						    else{push @{$groups},$arg;}
						   };
 				       }
                   if($op=~/\*$/)
					{   
					   if($gr=~/^\s*(\/|\[)/)
						{if($gr=~/^\s*^(.*?)\s*(\sor\s|\sand\s|<=|>=|\!=|>|<|=|\+|\s\-\s|\smod\s|\sdiv\s|\s\*\s|,|\|)\s*(.*)\s*/s)
						 {$gr=$3;push @{$groups},$op.$1;$op=$2;$op=~s/^\s+//g;$op=~s/\s+$//g;}
					     else{$gr=~s/^\s+//g;$gr=~s/\s+$//g;$op.=$gr;$gr='';};
						};
					};
 				   push @{$groups},$op;
				}
			 else{$gr=~s/^\s+//g;$gr=~s/\s+$//g;push @{$groups}, $gr;$gr='';};
			};
}

sub group  
{
	my ($opened,$str,$gr,$groups)=@_;
	if($str=~/^(.*?)\((.+)/s)
	{ $gr.=$1;$gr.=' ';
	  my $strend=$2;
	  my $op2=$opened+1;
	  if($gr=~/(.*\)){$op2,}/s){$opened++; push @{$groups}, '';
	                            $gr='('.$gr;xpath_errors(1);$_fotal_error_='FOTALL ERROR';};
	  if(($gr=~/(.*\)){$opened}/s))
		{group_op($gr,$groups);
		    if($strend)
			{
             if($strend=~/.*\).*/s){group(1,$strend,'(',$groups);}
			 else{group(1,$strend.')','(',$groups);
				  xpath_errors(0);$_fotal_error_='FOTALL ERROR';};
		    };
		}
      else
		{my $nstr=$gr.$strend;
	     my $op=$opened+1;
		 if($nstr!~/(.*\)){$op,}/s)
	     {$strend.=')';xpath_errors(0);$_fotal_error_='FOTALL ERROR';};
	     $gr.='(';
		 $opened++;
		 group($opened,$strend,$gr,$groups);
		};
	}else{$gr.=$str;
	      my $op2=$opened+1; 
	      if($str=~/(.*\)){$op2,}/s){push @{$groups}, '';$gr='('.$gr;xpath_errors(1);$_fotal_error_='FOTALL ERROR';};
		  group_op($gr,$groups);};
}

sub op_code 
{
    my $op=shift;
	if($op eq '|'){return 8;}
	elsif($op eq 'div'){return 7;}
	elsif($op eq '*'){return 7;}
	elsif($op eq 'mod'){return 7;}
	elsif($op eq '+'){return 6;}
	elsif($op eq '-'){return 6;}
	elsif($op eq '!='){return 4;}
	elsif($op eq '='){return 4;}
	elsif($op eq '>'){return 5;}
	elsif($op eq '<'){return 5;}
	elsif($op eq '>='){return 5;}
	elsif($op eq '<='){return 5;}
	elsif($op eq 'and'){return 3;}
	elsif($op eq 'or'){return 2;}
	elsif($op eq ','){return 1;}
    else{return 0;};
}

sub try_correct_arg 
{
	my $c_op=shift;
	my $ngrs=shift;
		  if(($c_op eq '*')||($c_op eq 'mod')||($c_op eq 'div')||($c_op eq 'and')||($c_op eq 'or'))
		  {$c_op.=' ';$c_op=' '.$c_op;push @{$ngrs},$c_op;}
	      else{$_fotal_error_="FOTAL ERROR";xpath_errors(3);};
}

sub collect_arg  
{my $op=shift;
 my $args=shift;
 if($op->{opname} eq ',')
	{unshift @{$args},$op->{right};
     my $nop=$op->{left};
	 if(ref($nop)){if($nop->{opname} eq ','){collect_arg($nop,$args);}
	               else{unshift @{$args},$nop;};}
     else{unshift @{$args},$nop;};
	};
 return $args;
}

sub compile_expr_param
{my $f_par=shift;
if($f_par=~/^\s*\//s)
{
my $param=compile_expr($f_par);
if($param->{opname} ne '/'){$_fotal_error_='FOTAL ERROR';xpath_errors(5);};
$param->{opname}='#';
return $param;
}
else{$_fotal_error_='FOTAL ERROR';xpath_errors(5);};
return undef;
}

my %_one_arg_func=('boolean'=>1,'count'=>1,'false'=>1,
	'last'=>1,'name'=>1,'normalize-space'=>1,'time'=>1,
	'not'=>1,'number'=>1,'position'=>1,'string'=>1,'string-length'=>1,
	'sum'=>1,'true'=>1,'file-name'=>1,'system-property'=>1);
sub compile_func_call 
{    my $ngrs=shift;
     my $last_op=shift;
	 my $c_op=shift;
	 
	 my $last_arg=$#{$ngrs};
     if(($last_arg<0)&&($last_op<0))
	 {try_correct_arg($c_op,$ngrs);
	                                          return -1;}
	 elsif($last_arg==$last_op)
	 {    if(!op_code($ngrs->[$last_arg])){push @{$ngrs},$c_op;
	                                          return $last_arg+1;}
          elsif(($ngrs->[$last_arg] eq '*')||($ngrs->[$last_arg] eq 'mod')||($ngrs->[$last_arg] eq 'div')||($ngrs->[$last_arg] eq 'and')||($ngrs->[$last_arg] eq 'or'))
			  {$ngrs->[$last_arg]=' '.$ngrs->[$last_arg].' ';
		       while(($last_op>=0)and(!op_code($ngrs->[$last_op]))){$last_op--;};
		       goto func;}
	      else{try_correct_arg($c_op,$ngrs);
			                                  return $last_op;};
	 }
	 elsif(($last_arg-$last_op)==1){push @{$ngrs},$c_op;
	                                          return $last_arg+1;};
     
func:{   my @f_expr=();
	     while($last_arg>$last_op){unshift @f_expr, pop @{$ngrs};$last_arg--;}; 
			      my $f=shift @f_expr;
				  my $f_arg=shift @f_expr;
				  if($f eq '')
				    {          push @{$ngrs},compile_expr($f_arg);
					           $last_arg++;
					           if($c_op ne ''){push @{$ngrs},$c_op;
					                          $last_arg++;$last_op=$last_arg;};
				    }
				  else
					{
		              my $hr={};
	                  $hr->{opname}=$f;
                      if($_one_arg_func{$f}){if($f_arg!~/^\s*$/){$hr->{right}=compile_expr($f_arg);};}
					  elsif($f eq 'id'){$_fotal_error_='FOTAL ERROR';xpath_errors(7);}						 
					  elsif($f eq 'current')
						  {if(!$f_arg)
						     {$f_arg=shift @f_expr;
					                   if($f_arg)
						               {$hr->{right}=compile_expr_param($f_arg);}
									   else{$hr->{right}='';};
							 }else{$_fotal_error_='FOTAL ERROR';xpath_errors(5);};
						  }
                      elsif($f eq 'gmtime')
						  {if($f_arg){$hr->{left}=compile_expr($f_arg);};
					       $f_arg=shift @f_expr;if($f_arg){$hr->{right}=compile_expr_param($f_arg);};
						  }
                      elsif($f eq 'document')
						  {if($f_arg)
							  {my $harg=compile_expr($f_arg);
					           if(ref($harg))
								  {if($harg->{opname} eq ',')
									  {my $arg_list=[];
						               $arg_list=collect_arg($harg,$arg_list);
									   if($#{$arg_list}==1)
										  {$hr->{left}=$arg_list->[0];$hr->{right}=$arg_list->[1];
										  }else{$_fotal_error_='FOTAL ERROR';xpath_errors(5);};
									  }else{$hr->{left}=$harg;};
								  }else{$hr->{left}=$harg;};
							  }else{$_fotal_error_='FOTAL ERROR';xpath_errors(5);};
							  my $f_par=shift @f_expr;
					                   if($f_par)
						               {$hr->{param}=compile_expr_param($f_par);}
									   else{$hr->{param}='';};
						  }
                      else
					  { my $harg=compile_expr($f_arg);
					    if(ref($harg))
						  {if($harg->{opname} eq ',')
							{my $arg_list=[];
						     $arg_list=collect_arg($harg,$arg_list);
							 my $num_arg=$#{$arg_list};

                             if($f eq 'key')
						     {if($num_arg==1){$hr->{left}=$arg_list->[0];$hr->{right}=$arg_list->[1];}
							  else{$_fotal_error_='FOTAL ERROR';xpath_errors(6);};
						      my $f_par=shift @f_expr;
					                   if($f_par)
						               {$hr->{param}=compile_expr_param($f_par);}
									   else{$hr->{param}='';};
						     }
                             elsif(($f eq 'contains')||($f eq 'starts-with')||($f eq 'substring-after')||($f eq 'substring-before')||($f eq 'save-file'))
						     {if($num_arg==1){$hr->{left}=$arg_list->[0];$hr->{right}=$arg_list->[1];}
							  else{$_fotal_error_='FOTAL ERROR';xpath_errors(6);};
							 }
							 elsif($f eq 'substring')
						     {if($num_arg<=2)
							  {$hr->{left}=$arg_list->[0];$hr->{right}=$arg_list->[1];
							   if($num_arg==2){$hr->{param}=$arg_list->[2];}
							   else{$hr->{param}='';};
							  }else{$_fotal_error_='FOTAL ERROR';xpath_errors(6);};
						     }
                             elsif($f eq 'translate')
						     {if($num_arg==2)
							   {$hr->{left}=$arg_list->[0];$hr->{right}=$arg_list->[1];$hr->{param}=$arg_list->[2];}
					           else{$_fotal_error_='FOTAL ERROR';xpath_errors(6);};
						     }
							 elsif($f eq 'concat')
							 {if($num_arg>=1){$hr->{right}=$arg_list->[0];shift @{$arg_list};$hr->{param}=$arg_list;}
							 else{$_fotal_error_='FOTAL ERROR';xpath_errors(6);};  
							 };
							}else{$_fotal_error_='FOTAL ERROR';xpath_errors(6);};
						  }
						  else
						  {$_fotal_error_='FOTAL ERROR';xpath_errors(6);};
					  };
		              
					  push @{$ngrs},$hr;
					  $last_arg++;
					  if($c_op ne ''){push @{$ngrs},$c_op; 
					                          $last_arg++;$last_op=$last_arg;};
					};
 				  my $rest=$#f_expr;
				  if($rest>=0)
		          {$_fotal_error_='FOTAL ERROR';xpath_errors(4);};
  				                              return $last_op;
	 };
}

sub conditions_array
{my $str=shift;
 my $array=[];
 while($str=~/^\[(.+?)\](.*)/)
	{push @{$array},$1;$str=$2;};
 return $array;
}

my %_axis_code=('descendant-or-self'=>1,'self'=>2,'parent'=>3,
'descendant'=>4,'preceding-sibling'=>5,'following-sibling'=>6,
'ancestor'=>7,'ancestor-or-self'=>8);
sub parse_step_pattern
{my $str=shift;
 my $name='';
 my $cond='';
 my $newstr='';
if($str=~/^\/([@\w\.\:\-\(\)\*]+)(\[[\-\d\[\]]+\])?(\/.+)/)
	{$name=$1;$cond=$2;$newstr=$3;}
elsif($str=~/^\/([@\w\.\:\-\(\)\*]+)(\[[\-\d\[\]]+\])?/)
	{$name=$1;$cond=$2;}
else{$_fotal_error_='ERROR';xpath_errors(8);return undef;};
     if($name eq '.'){$name='self::node()';};
	 my $h={};
	 if($cond){$h->{conds}=conditions_array($cond);};
	 if($name=~/^([\w\-]+)\:\:([\w\.\:\-\*\(\)]+)/)
		{my $namepre=$1;$name=$2;
	     my $acode=$_axis_code{$namepre};
		 if($acode){$h->{axis}=$acode;$h->{name}=$name;}
		 else{$_fotal_error_='ERROR';xpath_errors(8);$_xpath_expr_error_.="unknown axis \"$namepre\"\n";return undef;};
		}
     else
		{$h->{axis}=0;$h->{name}=$name;};
	 if($newstr){$h->{'next'}=parse_step_pattern($newstr);};
	 return $h;
}

sub prepare_step_path
{my $str=shift;
 my $h={};
 if($str!~/^\//){$h->{opname}='#';$str=join('','/',$str);$h->{right}=parse_step_pattern($str);}
 else{$h->{opname}='/';
 if($str ne '/'){$h->{right}=parse_step_pattern($str);}
 else{my $hr={};$hr->{axis}=2;$hr->{name}='/';$h->{right}=$hr;};};
return $h;
}

sub prepare_var_expr
{my $str=shift;
    if($str=~/^\$(.+)/)
	{if(defined($glob_strings{$1})){return $glob_strings{$1};}
	 else
	  {my $vn=$1;
	   my $he={};$he->{opname}='$';
	   if($vn=~/^[\w\.\:\-]+$/){$he->{left}=$vn;}
	   elsif($vn=~/^([\w\.\:\-]+)(\[[\d\-\[\]]+\])\/(.+)/){$he->{left}=$1;$he->{conds}=conditions_array($2);$he->{right}=prepare_step_path($3);}
	   elsif($vn=~/^([\w\.\:\-]+)\/(.+)/){$he->{left}=$1;$he->{right}=prepare_step_path($2);}
	   elsif($vn=~/^([\w\.\:\-]+)(\[[\d\-\[\]]+\])/){$he->{left}=$1;$he->{conds}=conditions_array($2);}
	   else{exiting_code("invalid variable name \"$vn\"\n");};
	   return $he;
	  };
	}else{return prepare_step_path($str);};
}

sub prepare_path  
{
my $str=shift;
$str=~s/^\s*//g;
$str=~s/\s*$//g;
if($str=~/^\'(.*)\'$/)
{return $literal_replace[$1];}
else
{
  $str=~s/\s+//gs;
  if($str=~/$_is_number/)
	{return $str;}
  else
	{
	 $str=~s/\&\%1/node\(\)/g;
     $str=~s/\&\%2/text\(\)/g;
	 $str=~s/\&\%3/comment\(\)/g;
	 $str=~s/\&\%4/processing\-instruction\(\)/g;
     $str=~s/child\:\://g;
     $str=~s/attribute\:\:/@/g;
     $str=~s/\.\./parent\:\:node\(\)/g;
     $str=~s/\/\//\/descendant\-or\-self\:\:node\(\)\//g;
	 return prepare_var_expr($str);
    };
};
}

sub compile_expr  
{ my $expr=shift;
if(!$_fotal_error_)
{
 if(!ref($expr))
 {
  my @groups=();
  group(0,$expr,'',\@groups);
  my $size=$#groups;
  if($size<0){return '';}
  elsif($size==0){return prepare_path($groups[0]);
  }
  elsif($size==1)
	{
	  compile_func_call(\@groups,-1,'');
	  if($_fotal_error_){return undef;};
	  return $groups[0];
	}
  else
	{ my $op_priority=0;
      my $op_min=8;
	  my $ngrs=[];
	  my $last_op=-1;
	    for my $arg (@groups)
		{   my $op_c=op_code($arg);
			if($op_c)
			{if($op_c>$op_priority){$op_priority=$op_c;};
			 if($op_min>$op_c){$op_min=$op_c;};
			 $last_op=compile_func_call($ngrs,$last_op,$arg);
			 if($_fotal_error_){return undef;};
			}
			else{push @{$ngrs}, $arg;};
	    };
		compile_func_call($ngrs,$last_op,'');
		if($_fotal_error_){return undef;};
		my $cgrs=$ngrs;
		$ngrs=[];
        while($op_priority>=$op_min)
		{   my $op_arg=shift @{$cgrs};
			while(defined($op_arg))
			{
 			if($op_priority==op_code($op_arg))
				{if($op_priority!=8)
					{
				 my $pre=pop @{$ngrs};
			     my $hr={};
				 $hr->{opname}=$op_arg;
				 $hr->{left}=compile_expr($pre);
                 $op_arg=shift @{$cgrs};
				 $hr->{right}=compile_expr($op_arg);
                 push @{$ngrs},$hr;
					}
                 else
					{
                 my $pre=pop @{$ngrs};
				 if(not(ref($pre)&&($pre->{opname} eq '|')))
				 {
					 my $hr={};$hr->{opname}='|';$hr->{param}=[];
				     push @{$hr->{param}},compile_expr($pre);
				     $pre=$hr;
				 };
				 $op_arg=shift @{$cgrs};push @{$pre->{param}},compile_expr($op_arg);
				 push @{$ngrs},$pre;
					};
				}
             else{push @{$ngrs}, $op_arg;};
			 $op_arg=shift @{$cgrs};
			};
			$op_priority--;
			$cgrs=$ngrs;
			$ngrs=[];
		};
		return $cgrs->[0];
	};
 }
 else {return $expr;};
}
else {return undef;};
}

sub install_expresion  
{
	my $expr=shift;
	my @subexprs=split('\[',$expr);
	my $s=$#subexprs;
	my $i=1;
    my $subexpr=$subexprs[0];
	while($s>=$i)
	{ my $nsubex=$subexprs[$i];
	  my $op=1;
	    while($nsubex!~/(.*\].*){$op}/s)
		{$i++; $op++;
		 if($s>=$i) 
			 {$nsubex.='['; $nsubex.=$subexprs[$i];}
		 else{$_fotal_error_='FOTALL ERROR';xpath_errors(2);return 0;};
		};
		if($nsubex=~/(.+)\](.*?)$/s)
		{$nsubex=$1;
		 my $end=$2;
		 if($nsubex!~/^[0-9]+$/)
			 {$subexpr=join('',$subexpr,'[',install_expresion($nsubex),']',$end);}
		 else{
			 if($nsubex>=0)
			 {$subexpr=join('',$subexpr,'[',$nsubex,']',$end);}
			 else{$subexpr.=$end;};
		     };
		}else{$_fotal_error_='FOTALL ERROR';xpath_errors(2);return 0;};
		 $i++;
	};
	my $ret=-$namber_of_exprs;
	push @compiled_expresions,compile_expr($subexpr);
	if(!$_fotal_error_)
	{$namber_of_exprs++;return $ret;}
	else{return 0;};
}

sub parse_expresion 
{
my $expr=shift;
my $oexpr=$expr;
if($expr=~/\$/s)
	{my @vnames=keys %glob_objects;
     for my $vname (@vnames)
		 {$expr=~s/\$$vname(\W)/$glob_objects{$vname}$1/gs;
	      $expr=~s/\$$vname$/$glob_objects{$vname}/;};
	};
@literal_replace=();
my $i=-1;
$expr=~s/(\'|\")(.*?)\1/push @literal_replace,$2;$i++;"\'$i\'"/egs;
$expr=~s/node\s*\(\s*\)/\&\%1 /gs;
$expr=~s/text\s*\(\s*\)/\&\%2 /gs;
$expr=~s/comment\s*\(\s*\)/\&\%3 /gs;
$expr=~s/processing\-instruction\s*\(\s*\)/\&\%4 /gs;
my $ret=install_expresion($expr);
@literal_replace=undef;
if($ret==0){$_xpath_expr_error_.=$oexpr;$_xpath_expr_error_.="\n";};
return $ret;
}

#################################### end xpath #########################

sub select_condition 
{
my $ha=shift;
my $ts=shift;
my $conds=$ts->{condition};
my $tms=$ts->{template};
my $size=$#{$conds};
	for (my $i=0;$i<=$size;$i++) {
		my $cond=$conds->[$i];
		if($cond==0){return $tms->[$i];}
		elsif($cond>0){if($_position_==$cond){return $tms->[$i];};}
		else
		{my $expr=$compiled_expresions[-$cond];
		 if(eval_expr($expr,$ha,0)){return $tms->[$i];};};
	}
return undef;
}

sub select_template  
{my ($ha,$templates_keys)=@_;
 my $str=$ha->[0]->{nodename};

 my @stack=();
 my @idx=();
 my @depths=();

 my $i=1;
 my $depth=1;
	 
 my $hstep=$templates_keys->{$str};
 if($hstep)
	 {
	 if(defined($ha->[0]->{attsnumb}))
		 {
	     if($templates_keys->{'*'})
	       {unshift @stack, $templates_keys->{'*'};
	        unshift @idx,1;
	        unshift @depths,1;};
		 }
     else
		 {if($str=~/^@/){
	       if($templates_keys->{'@*'})
	       {unshift @stack, $templates_keys->{'@*'};
	        unshift @idx,1;
	        unshift @depths,1;};};
		 };
     }
 else{if(defined($ha->[0]->{attsnumb})){$hstep=$templates_keys->{'*'};}
      else{if($str=~/^@/){$hstep=$templates_keys->{'@*'};};};
     };

 my $ret=undef;
 my $order=0;
    while($hstep)
	{   my $bool=0;
		if($hstep->{template}){if($order<$depth){
			                    if($hstep->{condition}->[0]==0)
			                       {$order=$depth;
		                            $ret=$hstep->{template}->[0];
									}
                                else{my $t=select_condition($ha,$hstep);
								     if($t){$order=$depth;$ret=$t;};  
									};
							   };};
		
		if($ha->[$i])
		{  $str=$ha->[$i]->{nodename};  
		   my $hn=$hstep->{ancestor};
           my $hnp=$hstep->{parent};
		   my $i0=$i;
		   if($hn){if($hn->{'*'}){$bool=1;$i++;$depth++;$hstep=$hn->{'*'};
		                          };};
		   if($hnp){if($hnp->{'*'}){
			                      if($bool){
			                      unshift @stack,$hstep;
								  unshift @idx,$i;
								  unshift @depths, $depth;
								  }else{$i++;$depth++;};
								  $bool=1;
								  $hstep=$hnp->{'*'};
		                          };};
		   if($hn)
				{
		         my $str0=$str;
			     loop: while($str0)
					{
					 if($hn->{$str0}){
						          if($bool){
                                  unshift @stack,$hstep;
								  unshift @idx,$i;
								  unshift @depths, $depth;
					              }else{$depth++;$i++;};
								  $bool=$i;$i0++;
								  $i=$i0;
								  $hstep=$hn->{$str0};
								  last loop;
								  };
					   $i0++;
					   if($ha->[$i0]){$str0=$ha->[$i0]->{nodename};}else{$str0='';};
					};
                };
		   if($hnp){if($hnp->{$str}){
			                      if($bool){
			                      unshift @stack,$hstep;
								  unshift @depths, $depth;
								  unshift @idx,$i;
								    if($bool>1){$i=$bool;};
								  }else{$depth++;$i++;};
								  $bool=1;
                                  $hstep=$hnp->{$str}; 
		                          };};
		};
		if(!$bool){
	   $hstep=shift @stack;
	   $i=shift @idx;
	   $depth=shift @depths;
		};
	};
 return $ret;
}

sub strip_st_spaces 
{my $el=shift;
 my $bi=$el->{attsnumb};
 if(defined($bi))
	{my $chs=$el->{children};
	 my $size=$#{$chs};
	 my $rm=0;
loop: while($bi<=$size)
		{my $ch=$chs->[$bi];
	      if($ch->{nodename} eq 'text()')
			{if($ch->{nodedata}=~/^\s*$/s)
				{my $pnode=$chs->[$bi-1];
		         my $fnode=$chs->[$bi+1];
				 if($pnode && $fnode)
				 {if(($pnode->{nodename}=~/^xsl\:/)&&($fnode->{nodename}=~/^xsl\:/))
					{$rm++;$bi++;}
				  else{
                  if(($pnode->{nodename}=~/^@/)&&($fnode->{nodename}=~/^xsl\:/)&&($el->{nodename}=~/^xsl\:/))
					  {$rm++;$bi++};
				      };
                 }
				 elsif($pnode)
				 {if(($el->{nodename}=~/^xsl\:/)&&($pnode->{nodename}=~/^xsl\:/))
					{$rm++;last loop;};
				 }
				 elsif($fnode)
				 {if(($el->{nodename}=~/^xsl\:/)&&($fnode->{nodename}=~/^xsl\:/))
					 {$rm++;$bi++;};
				 };
				};
			};
         if($rm){$chs->[$bi-$rm]=$chs->[$bi];};
         $bi++;
		};
    while($rm>0){pop @{$chs};$rm--;};
	for my $ch (@{$chs}) {
    if(defined($ch->{attsnumb})){strip_st_spaces($ch);};
	};
	};
}

sub strip_all_spaces  
{my $el=shift;
 my $bi=$el->{attsnumb};
 if(defined($bi))
	{my $chs=$el->{children};
	 my $size=$#{$chs};
	 my $rm=0;
loop: while($bi<=$size)
		{my $ch=$chs->[$bi];
	     if($ch->{nodename} eq 'text()')
		 {if($ch->{nodedata}=~/^\s*$/s){
			 if($bi<$size){$rm++;$bi++;}
			 else{if($size!=0){my $pnode=$chs->[$bi-1];
			     if(defined($pnode->{attsnumb})){$rm++;last loop;};};};
			 };
		 };
         if($rm){$chs->[$bi-$rm]=$chs->[$bi];};
         $bi++;
		};
    while($rm>0){pop @{$chs};$rm--;};
	for my $ch0 (@{$chs}) {
    if(defined($ch0->{attsnumb})){strip_all_spaces($ch0);};
	};
	};
}

sub is_template_not_empty
{ my $t=shift;
  my $tchs=$t->{children}; 
  my $size=$#{$tchs};
  if($size>0) {return 1;}
  elsif($size==0)
	{my $ch=$tchs->[0];
     if($ch->{nodename} eq 'text()'){if($ch->{nodedata}=~/^\s*$/){pop @{$tchs};};};
	 return 0;}
  else{return 0;};
}

sub install_template
{
my $template=shift;
my $match=$template->{attslist}->{match};
my $name=$template->{attslist}->{name};
my $mode=$template->{attslist}->{mode};
if(!$mode){$mode='no';};
my $t_keys=$template_modes{$mode};
if(!$t_keys){$t_keys={};$template_modes{$mode}=$t_keys;};
	if($match)
	{my @patterns=split('\|',$match);
	 for my $s (@patterns)
	 {if($s){
			 my $patern=$s;
			 my $cond=0;
			 if($patern=~/([^\[]+)\[(.+)\]\s*$/s){$patern=$1;$cond=$2;};
			  
			     if($cond!~/^\d+$/)
				  {$cond=parse_expresion($cond);
			       if($cond==0){
					   exiting_code("invalid predicate in pattern $match\n");
					   };
				  };
			      if($patern=~/(.*)node\(\)$/)
					  {my $newp=$1.'text()';
			           $newp=~s/node\(\)/\*/g;
					   $newp=~s/child\:\://g;
					   $newp=~s/\s+//g;
					   set_template_key($newp,$template,$t_keys,$cond);};
               $patern=~s/node\(\)/\*/g;
			   $patern=~s/attribute\:\:/@/g;
			   $patern=~s/child\:\://g;
			   $patern=~s/\s+//g;
			   set_template_key($patern,$template,$t_keys,$cond);
		    };
	 };
	};
	if($name)
	{if(!defined($template_names{$name})){$template_names{$name}=$template;};
	};
}

sub install_templates
{my $ts=shift;
 for my $t (@{$ts})
	{if(is_template_not_empty($t)){
	  if($output_indent){strip_st_spaces($t);}
	  else{strip_all_spaces($t);};};
     install_template($t);};
}

sub set_glob_params
{
			my $parame=shift;
			my $pname=$parame->{attslist}->{name};
			if($pname)
			{if((!defined($glob_strings{$pname}))&&(!defined($glob_objects{$pname}))&&(!defined($glob_vars{$pname})))
				{my $type=$parame->{attslist}->{as};
			        if(defined($type))
					{my $passval=$XS_PARAMS{$pname};
						if(defined($passval))
						{if($CHARS_MODEL ne 'bytes'){
							if($] > 5.007){require Encode; Encode::_utf8_on($passval);}
							else{$passval=pack('U0C*', unpack ('C*', $passval));};};
					     my $dsize=$parame->{attslist}->{'max-size'};
					     if(defined($dsize))
						 {if($dsize=~/^\d+$/)
							 {if(length($passval)>$dsize){exiting_code("exceed length limitation for value of param \"$pname\"\n");};}
						  else
							 {exiting_code("invalid value of max\-size attribute\n");};};

						 if($type eq 'expression')
						 {if(($passval!~/\$/s)and($passval!~/document\s*\(/s)){$glob_objects{$pname}=$passval;}
						  else{exiting_code("illegal value of expression \"$pname\" of expression type\n");};
						 }
						 elsif($type eq 'number')
						 {if($passval=~/$_is_number/){$glob_objects{$pname}=$passval;}
						      else{exiting_code("illegal value of number \"$pname\"\n");};
						 }
                         elsif($type eq 'int')
						 {if($passval=~/^-?[0-9]+/){$glob_objects{$pname}=$passval;}
						      else{exiting_code("illegal value of int \"$pname\"\n");};
						 }
                         elsif($type eq 'unsigned-int')
						 {if($passval=~/^[0-9]+/){$glob_objects{$pname}=$passval;}
						      else{exiting_code("illegal value of unsigned-int \"$pname\"\n");};
						 }
                         elsif($type eq 'string'){$glob_strings{$pname}=$passval;}
						 elsif($type eq 'set'){
							 my $pset=newnode('/','');$pset->{attsnumb}=0;
							 my @values=split("\0",$passval);
							 for my $value (@values) {
                             my $vnode=newnode('value','');$vnode->{attsnumb}=0;
							 if($value ne ''){
							 push @{$vnode->{children}},newnode('text()',$value);};
							 push @{$pset->{children}},$vnode;
							 };
							 my $ppset=[$pset];
							 $glob_vars{$pname}=[$ppset];
						 }
						 elsif($type eq 'file'){$glob_vars{$pname}=$passval;}
						 else{exiting_code("unknown type \"$type\" of param \"$pname\"\n");};
						}
						else
						{my $default=$parame->{attslist}->{'select'};
						 if(($type ne 'file') and ($type ne 'set')){
						 if(defined($default))
							 {if($default=~/^(\'|\")(.*)(\'|\")$/s){$glob_strings{$pname}=$2;}
						      else{$glob_objects{$pname}=$default;};
							 }
                         else{$default=node_text($parame);
						      if($default){$glob_strings{$pname}=$default;}
							  else{exiting_code("param \"$pname\" is not passed\n");};
							 };
						 }else{if($type eq 'file'){$glob_vars{$pname}='';}
						       else{my $sp=[newnode('/','')];$sp->[0]->{attsnumb}=0;
							        my $set=tree_fragment($parame,$sp);
									if($set->[0]){$glob_vars{$pname}=$set;}
									else{exiting_code("param \"$pname\" is not passed\n");};
							   };
						      };
						};
					}
					else
					{my $pval=$parame->{attslist}->{'select'};
					 if(defined($pval))
					 {if($pval=~/^(\'|\")(.*)(\'|\")$/s)
						  {$glob_strings{$pname}=$2;}
					  else{$glob_objects{$pname}=$pval;};
					 }
					 else{$pval=node_text($parame);$glob_strings{$pname}=$pval;};		   
					};
				}
				else{exiting_code("redefined param or variable name \"$pname\"\n");};
			};
}

sub install_stylesheet
{
	my ($style,$ts,$vars)=@_;
	my $ch=$style->{children};
	my $i=$#{$ch};
	while($i>=0)
	{my $name=$ch->[$i]->{nodename};
	    if($name eq 'xsl:template'){push @{$ts},$ch->[$i];}
		elsif($name eq 'xsl:key'){
			my $key=$ch->[$i];my $key_n=$key->{attslist}->{name};
		    if($key_n){if(!defined($key_names{$key_n})){$key_names{$key_n}=$key;}else{exiting_code("redefined key function name \"$key_n\"\n");};
			}else{exiting_code("xsl:key has no name attribute\n");};
		}
		elsif(($name eq 'xsl:include')||($name eq 'xsl:import')){
			my $incl=$ch->[$i];my $file=$incl->{attslist}->{'href'};
			if($file){
				for my $st (@_opened_stylesheets){if($st eq $file){goto end;};};
				my $old_base=$XSLT_BASE;
				my $incst=read_xsl_file($file);
                install_stylesheet($incst,$ts,$vars);
				$XSLT_BASE=$old_base;
				end: };
		}
		elsif($name eq 'xsl:variable'){push @{$vars},$ch->[$i];}
		elsif($name eq 'xsl:param'){set_glob_params($ch->[$i]);}
		elsif($name eq 'xsl:namespace-alias'){
        my $alias=$ch->[$i];my $stpre=$alias->{attslist}->{'stylesheet-prefix'};
		my $rpre=$alias->{attslist}->{'result-prefix'};
		if(not($stylesheet_prefix)){
			if($stpre){$stylesheet_prefix=$stpre;if($rpre){$result_prefix=$rpre;}else{$result_prefix='xsl';};};};
		}
		elsif($name eq 'xsl:output'){
        my $out=$ch->[$i];my $outparam=$out->{attslist}->{indent};
		 if($outparam eq 'yes'){$output_indent='yes';};
		 $outparam=$out->{attslist}->{method};
		 if($outparam){if(!$output_method){$output_method=$outparam;};};
		 $outparam=$out->{attslist}->{encoding};
		 if($outparam){if(!$output_encoding){$output_encoding=$outparam;};};
		 $outparam=$out->{attslist}->{'omit-xml-declaration'};
		 if($outparam){$omit_xmldecl=$outparam;};
		 $outparam=$out->{attslist}->{'omit-http-headers'};
		 if($outparam eq 'yes'){$_http_output=0;};
		}
		elsif($name eq 'xsltp:max-content-length'){
        my $add=$ch->[$i]->{attslist}->{'select'};
		if($add=~/^-?\d+$/){$MAX_CONTENT_SIZE+=$add;};
		}
		elsif($name eq 'xsltp:xml-base'){
		if(not($_xml_base_flag)){
		my $newbase=$ch->[$i]->{attslist}->{'select'};
		$newbase=~s/\s+//g;
		if($newbase){$_xml_base_flag=1;$XML_BASE=$newbase;};
		}
		else{exiting_code("more than one xsltp:xml\-base elements\n");};
		}
		elsif($name eq 'xsltp:http-output'){
        my $h=$ch->[$i]->{attslist}->{'name'};$h=lc($h);$h=ucfirst($h);
		if($h){unshift @_http_fields, $h;unshift @_http_contents,$ch->[$i];};
		}
		elsif($name eq 'xsl:message'){if(!defined($xsltp_error_message)){$xsltp_error_message=$ch->[$i];};};

		$i--;
	};
}

sub read_xsl_file
{
	my $file=shift;
	my $root=createtree($file,'xsl');
	my $chs=$root->{children};
	for my $st (@{$chs})
	{if(($st->{nodename} eq 'xsl:stylesheet')||($st->{nodename} eq 'xsl:transform'))
	  {return $st;};};
	my $t=newnode('xsl:template','');
	$t->{attsnumb}=1;
	$t->{attslist}={};
	$t->{attslist}->{'match'}='/';
	push @{$t->{children}}, newnode('@match','/');
#	push @{$t->{children}},@{$chs};
	my $newst=newnode('xsl:stylesheet','');
	$newst->{attsnumb}=0;
    $newst->{attslist}={};
	push @{$newst->{children}},$t;
	  return $newst;
}

sub read_xml_file
{
	my $file=shift;
	my $root=createtree($file,'xml');
	strip_all_spaces($root);
	return $root;
}

sub scannodes
{
my ($newselect,$path,$seq)=@_;
my $chen=$path->[0]->{children};
  for my $ch (@{$chen})
	{ if($ch->{nodename}!~/^@/){
	     my $newpath=[$ch,@{$path}];
	     node_seq($newselect,$newpath,$seq);
		 if($ch->{children}->[0]){
		 scannodes($newselect,$newpath,$seq);};
		};
	};
}

sub scannames
{
my ($name,$newselect,$path,$seq)=@_;
my $chen=$path->[0]->{children};
FOR:for my $ch (@{$chen})
	{ if($ch->{nodename} eq $name)
		{my $newpath=[$ch,@{$path}];
	     node_seq($newselect,$newpath,$seq);
	     if($ch->{children}->[0]){scannames($name,$newselect,$newpath,$seq);};
		 next FOR;
		};
      if($ch->{children}->[0])
		{my $newpath=[$ch,@{$path}];
	     scannames($name,$newselect,$newpath,$seq);
		};
	};
}

sub scanelemets
{
my ($newselect,$path,$seq)=@_;
my $chen=$path->[0]->{children};
my $i=$path->[0]->{attsnumb};
my $ch=$chen->[$i];
  while($ch)
	{ if(defined($ch->{attsnumb}))
		{my $newpath=[$ch,@{$path}];
	     node_seq($newselect,$newpath,$seq);
		 if($ch->{children}->[0]){
		 scanelemets($newselect,$newpath,$seq);};
		};
      $i++;
	  $ch=$chen->[$i];
	};
}

sub ancestors
{
  my ($tselect,$newpath,$tseq)=@_;
  					  while($newpath->[0])
						 {my $tpath=[@{$newpath}];
						  node_seq($tselect,$newpath,$tseq);
						  shift @{$tpath};
						  $newpath=$tpath;
						 };
}

sub named_ancestors
{
  my ($name,$tselect,$newpath,$tseq)=@_;
					  my $c=$newpath->[0];
					  while($c)
						 {if($c->{nodename} eq $name)
							 {
						      my $tpath=[@{$newpath}];
						      node_seq($tselect,$newpath,$tseq);
						      shift @{$tpath};
						      $newpath=$tpath;
							 }
                          else{shift @{$newpath};};
						  $c=$newpath->[0];
						 };
}

sub find_child_position
{
	my $path=shift;
	my $ch=$path->[0];
	my $p=$path->[1];
	my $i=0;
	if($p)
	{   my $ch0=$p->{children}->[$i];
		while($ch0!=$ch){$i++;$ch0=$p->{children}->[$i];
		                 if(!$ch0){return -1;};};
		return $i;
	}
	else{return -1;};
}

sub find_child_at
{
  my ($name,$cnode,$count,$start,$inc)=@_;
	  $count--;
	  my $chs=$cnode->{children};
	  my $i=$start; my $ch=$chs->[$i];
	  if($name eq '*')
		{ while($ch)
			{if(defined($ch->{attsnumb}))
		        {if($count==0){return $ch;};$count--;};
	         $i=$i+$inc;if($i>=0){$ch=$chs->[$i];}else{return undef;};
			};
		}
	  elsif($name eq 'node()')
		{ while($ch)
			{if($ch->{nodename}!~/^@/)
		        {if($count==0){return $ch;};$count--;};
	         $i=$i+$inc;if($i>=0){$ch=$chs->[$i];}else{return undef;};
			};
		}
	  else
		{ 
		  while($ch)
			{if($ch->{nodename} eq $name)
		        {if($count==0){return $ch;};$count--;};
	         $i=$i+$inc;if($i>=0){$ch=$chs->[$i];}else{return undef;};
			};
		};
     return undef;
};

sub filter_node_seq
{
	my ($tseq,$cond)=@_;
	my $ret=[];
	for my $c (@{$cond})
	{if($c>0){my $npath=$tseq->[$c-1];if($npath){push @{$ret},$npath;};}
	 else
		{my $expr=$compiled_expresions[-$c];
	     my $lastnode=$#{$tseq}+1;
	     for (my $idx=0;$idx<$lastnode;$idx++) 
			{ my $path=$tseq->[$idx];
		      $_index_=$idx+1;
			  $_last_node_=$lastnode;
			  if(eval_expr($expr,$path,0)){push @{$ret},$path;};
			};
		};
    $tseq=$ret;$ret=[];
	};
	$_index_=0;
	return $tseq;
}

sub node_seq
{
	my ($select,$path,$seq)=@_;
	if($select)
	{  my $cnode=$path->[0];
		{  my $name=$select->{name};
		   my $cond=$select->{conds};
		   my $namepre=$select->{axis};
		   my $newselect=$select->{'next'};
		   my $tseq=[];
		   my $tselect=undef;
		   if(!$cond){$tselect=$newselect; $tseq=$seq;}
		   else{$cond=[@{$select->{conds}}];};
		   if($namepre>0)  
		   {		       
			   if($namepre==1)
			   {   if($newselect){if($name eq 'node()'){$name='*';};};
				   if($name eq '*')
					   {
					   if(defined($cnode->{attsnumb})){
						                            my $newpath=[@{$path}];
					                                node_seq($tselect,$newpath,$tseq);
													if($cnode->{children}->[0]){
													scanelemets($tselect,$newpath,$tseq);};
													};
					   }
				   elsif($name eq 'node()')
					   {
					    if($cnode->{nodename}!~/^@/){
						                            my $newpath=[@{$path}];
					                                node_seq($tselect,$newpath,$tseq);
													if($cnode->{children}->[0]){
													scannodes($tselect,$newpath,$tseq);};
													};
					   }
				   else
				       {
					   if($cnode->{nodename} eq $name){
						                            my $newpath=[@{$path}];
					                                node_seq($tselect,$newpath,$tseq);
													if($cnode->{children}->[0]){
												    scannames($name,$tselect,$newpath,$tseq);};
													  }
                                                  else{ 
													if($cnode->{children}->[0]){
												    scannames($name,$tselect,$path,$tseq);};
												      };
				       };
		       }
			   elsif($namepre==2)
			   {
				   if($name eq 'node()')
					   {
					   
						                            my $newpath=[@{$path}];
					                                node_seq($tselect,$newpath,$tseq);
					   }
				   elsif($name eq '*')
					   {
					   if(defined($cnode->{attsnumb})){
						                            my $newpath=[@{$path}];
					                                node_seq($tselect,$newpath,$tseq);
													};
					   }
				   else
				       {
					   if($cnode->{nodename} eq $name){
						                            my $newpath=[@{$path}];
					                                node_seq($tselect,$newpath,$tseq);
													};
				       };
			   }
			   elsif($namepre==3)
			   {my $pnode=$path->[1];
			    if($pnode)
				 {
				   if(($name eq 'node()')||($name eq '*'))
					   {
						  my $newpath=[@{$path}];
						  shift @{$newpath};
					      node_seq($tselect,$newpath,$tseq);
					   }
				   else
				       {
					   if($pnode->{nodename} eq $name)
					      {
						   my $newpath=[@{$path}];
						   shift @{$newpath};
					       node_seq($tselect,$newpath,$tseq);
				          };
					   };
				 };
			   }
			   elsif($namepre==4)
			   {   if($newselect){if($name eq 'node()'){$name='*';};};
			         if($cnode->{children}->[0])
				     {
				      if($name eq '*')
					   {scanelemets($tselect,$path,$tseq);}
				      elsif($name eq 'node()')
					   {scannodes($tselect,$path,$tseq);}
				      else
				       {scannames($name,$tselect,$path,$tseq);};
					 };
		       }
			   elsif($namepre==5)
			   {my $pos=find_child_position($path);
			      if($pos>0)
				   {
					  my $newpath=[@{$path}];shift @{$newpath};
					  $pos--;
			          if($cond)
			            {if($cond->[0]>0)
			              {my $num=shift @{$cond};
					        if(!defined($cond->[0]))
			                {$tselect=$newselect; $tseq=$seq;$cond=undef;};
				            my $node=find_child_at($name,$path->[1],$num,$pos,-1);
				            if($node){unshift @{$newpath},$node;
				                      node_seq($tselect,$newpath,$tseq);};
				            goto end;
				          };
			            };
					  my $chs=$newpath->[0]->{children};
					  if($name eq '*')
					  {  while($pos>=0)
						  {if(defined($chs->[$pos]->{attsnumb}))
							  {my $tpath=[$chs->[$pos],@{$newpath}];
					           node_seq($tselect,$tpath,$tseq);};
                           $pos--;
						  };
					  }
					  elsif($name eq 'node()')
					  {  while($pos>=0)
						  {if($chs->[$pos]->{nodename}!~/^@/)
							  {my $tpath=[$chs->[$pos],@{$newpath}];
					           node_seq($tselect,$tpath,$tseq);};
                           $pos--;
						  };
					  }
					  else
					  {  while($pos>=0)
						  {if($chs->[$pos]->{nodename} eq $name)
							  {my $tpath=[$chs->[$pos],@{$newpath}];
					           node_seq($tselect,$tpath,$tseq);};
                           $pos--;
						  };

					  };
				   };
			   }
			   elsif($namepre==6)
		       {my $pos=find_child_position($path);

				  if($pos>=0)
				   {
					  my $newpath=[@{$path}];shift @{$newpath};
                      $pos++;
			          if($cond)
			            {if($cond->[0]>0)
			              {my $num=shift @{$cond};
					        if(!defined($cond->[0])){$tselect=$newselect; $tseq=$seq;$cond=undef;};
				            my $node=find_child_at($name,$path->[1],$num,$pos,1);
				            if($node){unshift @{$newpath},$node;
				                      node_seq($tselect,$newpath,$tseq);};
				            goto end;
				          };
			            };
					  my $chs=$newpath->[0]->{children};
					  my $size=$#{$chs};
					  if($name eq '*')
					  {  while($pos<=$size)
						  {if(defined($chs->[$pos]->{attsnumb}))
							  {my $tpath=[$chs->[$pos],@{$newpath}];
					           node_seq($tselect,$tpath,$tseq);};
                           $pos++;
						  };
					  }
					  elsif($name eq 'node()')
					  {  while($pos<=$size)
						  {if($chs->[$pos]->{nodename}!~/^@/)
							  {my $tpath=[$chs->[$pos],@{$newpath}];
					           node_seq($tselect,$tpath,$tseq);};
                           $pos++;
						  };
					  }
					  else
					  {  while($pos<=$size)
						  {if($chs->[$pos]->{nodename} eq $name)
							  {my $tpath=[$chs->[$pos],@{$newpath}];
					           node_seq($tselect,$tpath,$tseq);};
                           $pos++;
						  };

					  };
				   };
			   }
			   elsif($namepre==7)
			   {  if($name eq 'node()'){$name='*';};
			         if($name eq '*')
				     {
					  my $newpath=[@{$path}];
					  shift @{$newpath};
                      ancestors($tselect,$newpath,$tseq);
					 }
					 else
				     {
					  my $newpath=[@{$path}];
					  shift @{$newpath};
					  named_ancestors($name,$tselect,$newpath,$tseq);
					 };
			   }
			   elsif($namepre==8)
			   {     if($name eq '*')
				     {
					  my $newpath=[@{$path}];
					  if(defined($cnode->{attsnumb}))
						 {my $tpath=[@{$newpath}];
					      node_seq($tselect,$tpath,$tseq);
						  shift @{$newpath};};
                      ancestors($tselect,$newpath,$tseq);
					 }
					 elsif($name eq 'node()')
				     {
					  my $newpath=[@{$path}];
					  if($cnode->{nodename}!~/^@/)
						 {my $tpath=[@{$newpath}];
					      node_seq($tselect,$tpath,$tseq);
						  shift @{$newpath};};
                      ancestors($tselect,$newpath,$tseq);
					 }
					 else
				     {
					  my $newpath=[@{$path}];
					  if($cnode->{nodename} eq $name)
						 {my $tpath=[@{$newpath}];
					      node_seq($tselect,$tpath,$tseq);
						  shift @{$newpath};};
					  named_ancestors($name,$tselect,$newpath,$tseq);
					 };
			   };
		   }else
		   { 
			   if($cond)
			   {if($cond->[0]>0)
			     {my $num=shift @{$cond};
					if(!defined($cond->[0])){$tselect=$newselect; $tseq=$seq;$cond=undef;};
				    if($name!~/^@/)
					 {
					  my $node=find_child_at($name,$cnode,$num,0,1);
				      if($node){my $newpath=[$node,@{$path}];
				                node_seq($tselect,$newpath,$tseq);};
					 };
				     goto end;
				 };
			   };
			   
			   if($name eq '*')
			   {
		        for my $child (@{$cnode->{children}})
			    {
			     if(defined($child->{attsnumb}))
				 {
				   my $newpath=[$child,@{$path}];
				   node_seq($tselect,$newpath,$tseq);
				 };
				};
			   }
			   elsif($name eq '@*')
			   {my $i=$cnode->{attsnumb};
			      if($i)
				  {
					  for (my $k=0;$k<$i ;$k++) {
						  my $newpath=[@{$path}];
						  unshift @{$newpath},$cnode->{children}->[$k];
						  node_seq($tselect,$newpath,$tseq);
					  };
				  };
			   }
			   elsif($name eq 'node()')
			   {
		        for my $child (@{$cnode->{children}})
			    {
			     if($child->{nodename}!~/^@/)
				 {
				   my $newpath=[$child,@{$path}];
				   node_seq($tselect,$newpath,$tseq);
				 };
				};
			   }
			   else
			   {
		        for my $child (@{$cnode->{children}})
			    {
			     if($child->{nodename} eq $name)
				 {
				   my $newpath=[$child,@{$path}];
				   node_seq($tselect,$newpath,$tseq);
				 };
			    };
			   };
		   };
           end:
		   if($cond){
                $tseq=filter_node_seq($tseq,$cond);
		   for my $np (@{$tseq}){node_seq($newselect,$np,$seq);};
		   };
		};
									   
	}
	else{push @{$seq}, $path;};
}

sub node_seq_from_root
{	my ($select,$path,$seq)=@_;
		  my $last=$#{$path};
	      my $root=$path->[$last];
          my $npath=[$root];
		  node_seq($select,$npath,$seq);
}

sub node_text
{
	my $node=shift;
	my $str=$node->{nodedata};
	if(!$str)
	{
		for my $ch (@{$node->{children}})
		{if($ch->{nodename}!~/^@/){$str.=node_text($ch);};};
	};
	return $str;
}

sub node_set_to_str
{
	my $nodeset=shift;
		if($nodeset->[0])
		{ my $snode=$nodeset->[0]->[0];
		  return node_text($snode);
		}else{return '';};
}

sub norm_space
{
	my $str=shift;
	$str=~s/^\s+//g;
	$str=~s/\s+$//g;
	$str=~s/\s+/ /g;
	return $str;
};

sub is_boolean
{
	my $expr=shift;
	if(!ref($expr)){return 0;}
	else
	{my $op=$expr->{opname};
	 return $_xpath_boolean{$op};};
}

sub n_comparison
{
	my ($expr,$stpath,$op)=@_;
	my $left=eval_expr($expr->{left},$stpath,2);
	my $right=eval_expr($expr->{right},$stpath,2);
	if(ref($left) && ref($right))
	{
		for my $rarg (@{$right})
			{my $rstr=node_text($rarg->[0]);$rstr=~s/^\s+//g;$rstr=~s/\s+$//g;
		       for my $larg (@{$left}) 
				   {my $lstr=node_text($larg->[0]);$lstr=~s/^\s+//g;$lstr=~s/\s+$//g;
				    if(($rstr=~/$_is_number/)&&($lstr=~/$_is_number/))
					{ 
					  if($op eq '>')
						{if($lstr>$rstr){return 1;};}
					  elsif($op eq '>=')
                        {if($lstr>=$rstr){return 1;};}
					  elsif($op eq '<')
                        {if($lstr<$rstr){return 1;};}
					  else
                        {if($lstr<=$rstr){return 1;};};
					};
				   };
		    };
        return 0;
	}
	else
	{   if(ref($left))
		{$right=~s/^\s+//g;$right=~s/\s+$//g;
		 if($right=~/$_is_number/)
			{
		     for my $arg (@{$left})
			  {my $lstr=node_text($arg->[0]);
		       $lstr=~s/^\s+//g;
			   $lstr=~s/\s+$//g;
			   if($lstr=~/$_is_number/)
			   {
					  if($op eq '>')
						{if($lstr>$right){return 1;};}
					  elsif($op eq '>=')
                        {if($lstr>=$right){return 1;};}
					  elsif($op eq '<')
                        {if($lstr<$right){return 1;};}
					  else
                        {if($lstr<=$right){return 1;};};
			   };
			  };
			};
			return 0;
		}
	    elsif(ref($right))
		{$left=~s/^\s+//g;$left=~s/\s+$//g;
		 if($left=~/$_is_number/)
			{
		     for my $arg (@{$right})
			  {my $rstr=node_text($arg->[0]);
		       $rstr=~s/^\s+//g;
			   $rstr=~s/\s+$//g;
			   if($rstr=~/$_is_number/)
			   {
					  if($op eq '>')
						{if($left>$rstr){return 1;};}
					  elsif($op eq '>=')
                        {if($left>=$rstr){return 1;};}
					  elsif($op eq '<')
                        {if($left<$rstr){return 1;};}
					  else
                        {if($left<=$rstr){return 1;};};
			   };
			  };
			};
			return 0;
		}
	    else
		{$right=~s/^\s+//g;$right=~s/\s+$//g;
		 $left=~s/^\s+//g;$left=~s/\s+$//g; 
		 if(($right=~/$_is_number/)&&($left=~/$_is_number/))
		 {
					  if($op eq '>')
						{if($left>$right){return 1;};}
					  elsif($op eq '>=')
                        {if($left>=$right){return 1;};}
					  elsif($op eq '<')
                        {if($left<$right){return 1;};}
					  else
                        {if($left<=$right){return 1;};};
		 };
		 return 0;
		};
	};
}

sub is_equal
{
	my ($expr,$stpath)=@_;
	my $left=eval_expr($expr->{left},$stpath,2);
	my $right=eval_expr($expr->{right},$stpath,2);
	if(ref($left) && ref($right))
	{
		for my $rarg (@{$right})
			{my $rstr=node_text($rarg->[0]);
		       for my $larg (@{$left}) 
				   {my $lstr=node_text($larg->[0]);
				    if($rstr eq $lstr){return 1;};};
		    };
        return 0;
	}
	else
	{ my $scaler=undef;
	  my $nodeset=undef;
	  my $stype=undef;

	    if(ref($left)){$scaler=$right;$nodeset=$left;$stype=$expr->{right};}
	    elsif(ref($right)){$scaler=$left;$nodeset=$right;$stype=$expr->{left};}
	    else
		   {if(is_boolean($expr->{left})||is_boolean($expr->{right}))
			   {
			        if($right){$right=1;}else{$right=0;};
		            if($left){$left=1;}else{$left=0;};
			     if($right==$left){return 1;}else{return 0;};
			   }
             elsif(($right=~/$_is_number/)&&($left=~/$_is_number/))
			   {if($right==$left){return 1;}else{return 0;};}
			 else
			   {if($right eq $left){return 1;}else{return 0;};};
		   };

      if($scaler=~/$_is_number/)
		{ if(($scaler==0)||($scaler==1))
		  {
		    if(is_boolean($stype))
			{my $nb=$nodeset->[0]?1:0;
	         if($nb==$scaler){return 1;}
			 else{return 0;};};
		  };
          
		  for my $arg (@{$nodeset})
			{my $str=node_text($arg->[0]);
		     $str=~s/^\s+//g;
			 $str=~s/\s+$//g;
			 if($str && $str==$scaler){return 1;};
			};
          return 0;
		}
      else
		{ for my $arg (@{$nodeset})
		  {my $str=node_text($arg->[0]);
	       if($str eq $scaler){return 1;};};
          return 0;
		};
	};
}

sub compile_instr_attr_f
{
	my $instr=shift;
	my $attr_name=shift;
	my $attrval=$instr->{attslist}->{$attr_name};
	if(!defined($attrval)){exiting_code("$instr->{nodename} has no $attr_name attribute\n");};
	my $cattr_name='c'.$attr_name;
	my $code=parse_expresion($attrval);
	     if($code<0){$instr->{$cattr_name}=$compiled_expresions[-$code];}
		 else{exiting_code("$instr->{nodename} has invalid $attr_name attribute\n");};
   return $compiled_expresions[-$code];
}

sub pattern_to_expr
{my $p=shift;
 if($p->{opname} eq '#')
	{
	   my $h={};$h->{axis}=1;$h->{name}='node()';
	   $h->{'next'}=$p->{right};
	   $p->{opname}='/';
	   $p->{right}=$h;
	};
}

sub install_key
{  my ($k_name,$stpath)=@_;
   my $k_el=$key_names{$k_name};
   if(!$k_el){exiting_code("no key with such a name=\"$k_name\"\n");};
   my $match=$k_el->{attslist}->{cmatch};
   if(defined($match)){exiting_code("illegal call of key function \"$k_name\"\n");};
   $match=compile_instr_attr_f($k_el,'match');
   if(not(is_expr_nodeset($match))){exiting_code("key function \"$k_name\" has invalid match attribute\n");};
   if($match->{opname} eq '|'){
    my $es=$match->{param};
    for my $e (@{$es}){pattern_to_expr($e);};
   }else{pattern_to_expr($match);};

   my $use=compile_instr_attr_f($k_el,'use');
   my $nodeset=eval_expr($match,$stpath,2);
   my $key={};

	push @_focus_stack_,$_focus_;
	push @_count_stack_,$_position_;
	$_focus_=$nodeset;
	$_position_=0;
   for my $path (@{$nodeset})
	   {  $_position_++;
	      my $ruse=eval_expr($use,$path,2);
		  if(ref($ruse))
		   {  for my $path2 (@{$ruse})
			  {my $str=node_text($path2->[0]);
		         if($str){if(!defined($key->{$str})){$key->{$str}=[$path];}
				          else{push @{$key->{$str}},$path;};};
		      };
		   }
          else
		   { 
		     if($ruse){if(!defined($key->{$ruse})){$key->{$ruse}=[$path];}
				       else{push @{$key->{$ruse}},$path;};
			   }
			 else
			   {
		         if(is_boolean($use)){if(!defined($key->{0})){$key->{0}=[$path];}
				           else{push @{$key->{0}},$path;};};
			   };
		   };
       };
	$_focus_=pop @_focus_stack_;
	$_position_=pop @_count_stack_;
	$_last_=0;
    $stylesheet_keys{$k_name}=$key;
	return $key;
}

sub convert_nodeset
{
if($_[0]==1){return node_set_to_str($_[1]);}
elsif($_[0]==2){return $_[1];}
else{if($_[1]->[0]){return 1;}else{return 0;};};
}

sub eval_key_func
{
	my ($expr,$stpath)=@_;
        my $k_name=eval_expr($expr->{left},$stpath,1);
        my $key=$stylesheet_keys{$k_name};
	    if(!$key){$key=install_key($k_name,$stpath);};
		my $rstr=eval_expr($expr->{right},$stpath,1);
		my $nset=$key->{$rstr};
		     if($nset)
				 {if($expr->{param})
					{my $ns=[];
			         my $pexpr=$expr->{param};
					 for my $path (@{$nset})
					  {node_seq($pexpr->{right},$path,$ns);};
                       $nset=$ns;
					};
                  return $nset;
				 }
		     else{return [];};
}

sub get_var_val
{my $expr=shift;
 my $name=$expr->{left};
	 my $i=-1;
	 for my $vname (@local_vars_names)
		 {$i++;if($vname eq $name){return $local_vars_values[$i];};};
if(defined($glob_vars{$name})){return $glob_vars{$name};}
else{exiting_code("unknown variable \"$name\"\n");};
}

sub var_value
{my ($expr,$stpath,$type)=@_;
 my $value=get_var_val($expr);
if(ref($value))
	{my $cond=$expr->{conds};
     my $ret=$value;
	 if($cond){$ret=filter_node_seq($value,$cond);};
	 my $pexpr=$expr->{right};
     if($pexpr)
		{my $newns=[];
	     for my $path (@{$ret})
		 {node_seq($pexpr->{right},$path,$newns);};
	     $ret=$newns;
		};
     return convert_nodeset($type,$ret);
	}
else
	{return $value;};
}

sub xsl_union
{my ($expr,$stpath,$type)=@_;
 my $bool=0;
 my $ns=[];my $es=$expr->{param};
 for my $e (@{$es})
 {if($e->{opname} eq '#'){node_seq($e->{right},$stpath,$ns);}
  elsif($e->{opname} eq '/'){node_seq_from_root($e->{right},$stpath,$ns);}
  else{my $tns=eval_expr($e,$stpath,2);if(ref($tns)){$bool=1;push @{$ns},@{$tns};};};
 };
if($bool)
	{my $fns=[];
	 my %tmp=();
	 for my $n (@{$ns}){my $n0=$n->[0];if(!defined($tmp{$n0})){push @{$fns},$n;$tmp{$n0}=1;};};
	 $ns=$fns;
	};
return convert_nodeset($type,$ns);
}

sub xml_file
{my ($files,$ns)=@_;
 my $old_base=$XML_BASE; 
 if(ref($files))
	{for my $path (@{$files})
		{my $spath=node_text($path->[0]);
         my $ds=read_xml_file($spath,'xml');
		 $XML_BASE=$old_base;
		 my $rp=[$ds];push @{$ns},$rp;};
	}
 else
	{my $ds=read_xml_file($files,'xml');
	 $XML_BASE=$old_base;
     my $rp=[$ds];push @{$ns},$rp;
	};
}

sub xsl_document
{my ($expr,$stpath,$type)=@_;
 my $left=eval_expr($expr->{left},$stpath,2);
 my $right=undef;
 if($expr->{right}){$right=eval_expr($expr->{right},$stpath,2);};
 my $ns=[];
 my $old_base=$XML_BASE; 
if(!$right)
{xml_file($left,$ns);}
else
{if(ref($right))
	{for my $path (@{$right})
	 {my $n_base=node_text($path->[0]);
      $XML_BASE=$n_base;
	  xml_file($left,$ns);};
	}
 else
	{$XML_BASE=$right;
     xml_file($left,$ns);};
};
$XML_BASE=$old_base;

if($expr->{param})
{my $nns=[];
 my $pexpr=$expr->{param};
 for my $path (@{$ns})
 {node_seq($pexpr->{right},$path,$nns);};
  $ns=$nns;
};
return convert_nodeset($type,$ns);
}

sub save_upload_file
{my ($expr,$stpath)=@_;
 my $hfile=$expr->{left};
 my $newfile=eval_expr($expr->{right},$stpath,1);
 if((!ref($hfile)) or ($hfile->{opname} ne '$')){exiting_code("save\-file function has invalid first arg\n");};
 $newfile=~s/\s+//sg;
 if($newfile)
	{if(is_file_name_notsafe($newfile)){exiting_code("File name ($newfile) contains Perl IO chars\n");};
	 if(defined($cgi_object)){
	 my $fname=$hfile->{left};
	 my $fh=undef;
	 eval{$fh=$cgi_object->upload($fname);};
	 if($@){exiting_code("Error in CGI $@\n");};
	 if($fh){
	 my $com='> '.$newfile;
	 open(FILEUPLOAD,$com) or exiting_code("Cannot open file ($newfile) for uploading\n");
	 binmode(FILEUPLOAD);
	 my $buff='';
	 while(read($fh,$buff,4096)){print FILEUPLOAD $buff;};
	 close(FILEUPLOAD);
	 }else{$newfile='';};
	 }else{$newfile='';};
	}
else{exiting_code("save\-file function has invalid second arg\n");};
return $newfile;
}

sub gmt_time
{ my ($t,$expr,$type)=@_;
if(($expr->{right}) or ($type==2))
	{my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday)=gmtime($t);
     my $root=newnode('/','');$root->{attsnumb}=0;
	 my $nyear=newnode('year','');$nyear->{attsnumb}=0;
	 push @{$nyear->{children}},newnode('text()',$year+1900);
	 push @{$root->{children}},$nyear;

	 my $nmonth=newnode('month','');$nmonth->{attsnumb}=0;
	 push @{$nmonth->{children}},newnode('text()',$mon+1);
	 push @{$root->{children}},$nmonth;

	 my $nday=newnode('day','');$nday->{attsnumb}=0;
	 push @{$nday->{children}},newnode('text()',$mday);
	 push @{$root->{children}},$nday;

	 my $nhour=newnode('hours','');$nhour->{attsnumb}=0;
	 push @{$nhour->{children}},newnode('text()',$hour);
	 push @{$root->{children}},$nhour;

	 my $nmin=newnode('minutes','');$nmin->{attsnumb}=0;
	 push @{$nmin->{children}},newnode('text()',$min);
	 push @{$root->{children}},$nmin;

	 my $nsec=newnode('seconds','');$nsec->{attsnumb}=0;
	 push @{$nsec->{children}},newnode('text()',$sec);
	 push @{$root->{children}},$nsec;

	 my $nwday=newnode('weekday','');$nwday->{attsnumb}=0;
	 push @{$nwday->{children}},newnode('text()',$wday+1);
	 push @{$root->{children}},$nwday;

	 my $nyday=newnode('yearday','');$nyday->{attsnumb}=0;
	 push @{$nyday->{children}},newnode('text()',$yday+1);
	 push @{$root->{children}},$nyday;

	 my $proot=[$root];
	 my $pexpr=$expr->{right};
	 if($pexpr){
		 my $nset=[];node_seq($pexpr->{right},$proot,$nset);
		 return convert_nodeset($type,$nset);
	 }
	 else{return [$proot];};
	}
else{my $st=gmtime($t);
     if($type){return $st;}
	 else{return 1;};
    };
}

sub eval_expr
{my ($expr,$stpath,$type)=@_;
   if(ref($expr))
	{ my $op=$expr->{opname};
         if($op eq '#'){my $nodeset=[];node_seq($expr->{right},$stpath,$nodeset);
          return convert_nodeset($type,$nodeset);
		 }
		 elsif($op eq '/'){my $nodeset=[];node_seq_from_root($expr->{right},$stpath,$nodeset);
          return convert_nodeset($type,$nodeset);
		 }
         elsif($op eq '$'){return var_value($expr,$stpath,$type);}
		 elsif($op eq '|'){return xsl_union($expr,$stpath,$type);}
		 elsif($op eq '='){return is_equal($expr,$stpath);}
		 elsif($op eq '!=')
			 {my $eq=is_equal($expr,$stpath);if($eq){return 0;}else{return 1;};}
         elsif($op eq '>'){return n_comparison($expr,$stpath,$op);}
		 elsif($op eq '<'){return n_comparison($expr,$stpath,$op);}
		 elsif($op eq '<='){return n_comparison($expr,$stpath,$op);}
		 elsif($op eq '>='){return n_comparison($expr,$stpath,$op);}
		 elsif($op eq 'and')
			 {my $r=eval_expr($expr->{left},$stpath,0);
		                    if(!$r){return 0;}
							else{$r=eval_expr($expr->{right},$stpath,0);
							if($r){return 1;}else{return 0;};};
		     }
		 elsif($op eq 'or')
			 {my $r=eval_expr($expr->{left},$stpath,0);
		                    if($r){return 1;}
							else{$r=eval_expr($expr->{right},$stpath,0);
							if($r){return 1;}else{return 0;};};
		     }
		 elsif($op eq 'false'){return 0;}
		 elsif($op eq 'true'){return 1;}
		 elsif($op eq 'not')
			 {my $r=eval_expr($expr->{right},$stpath,0);
		      if($r){return 0;}else{return 1;};}
		 elsif($op eq 'boolean')
			 {my $r=eval_expr($expr->{right},$stpath,0);
		      if($r){return 1;}else{return 0;};}
         elsif($op eq 'contains')
		     {my $str1=eval_expr($expr->{left},$stpath,1);
		      my $str2=eval_expr($expr->{right},$stpath,1);
		      $str2=~s/(\W)/\\$1/gs;
		      if($str1=~/$str2/s){return 1;}
		      else{return 0;};
			 }
         elsif($op eq 'starts-with')
		     {my $str1=eval_expr($expr->{left},$stpath,1);
		      my $str2=eval_expr($expr->{right},$stpath,1);
		      $str2=~s/(\W)/\\$1/gs;
		      if($str1=~/^$str2/s){return 1;}
		      else{return 0;};
			 }
          elsif($op eq 'key')
			 {my $nodeset=eval_key_func($expr,$stpath);
		      return convert_nodeset($type,$nodeset);}
		  elsif($op eq 'position'){if($_index_){return $_index_}else{return $_position_;};}
		  elsif($op eq 'last')
			 { if($_index_){return $_last_node_;}
			    else
			    {if($_last_){return $_last_;}else{$_last_=$#{$_focus_}+1;return $_last_;};
			    };
		     }
          elsif($op eq 'count')
			  {my $node_paths=eval_expr($expr->{right},$stpath,2);
	                       if(ref($node_paths))
				           {my $i=$#{$node_paths}; $i++; return $i;}
			               else{return 0;};
			  }
          elsif($op eq 'current')
			  {my $cstpath=$_focus_->[$_position_-1];
	                       if($expr->{right}){return eval_expr($expr->{right},$cstpath,$type);};
	                       if($type==1){return node_text($cstpath->[0]);}
						   elsif($type==2){my $path=[@{$cstpath}];return [$path];}
						   else{return 1;};
			  }
          elsif($op eq 'normalize-space')
		      {
			   if(defined($expr->{right})){return norm_space(eval_expr($expr->{right},$stpath,1));}
	           else{return norm_space(node_text($stpath->[0]));};
			  }
          elsif($op eq 'save-file'){return save_upload_file($expr,$stpath);}
		  elsif($op eq 'file-name')
		      {if($expr->{right}){my $name=eval_expr($expr->{right},$stpath,1);
		        if($name=~/[\\\/\:]?([\w\-\.]+)$/){return $1;}else{return ''};
		       }else{return '';}
		      }
          elsif($op eq 'string'){return eval_expr($expr->{right},$stpath,1);}
          elsif($op eq 'string-length')
		      {if(defined($expr->{right})){return length eval_expr($expr->{right},$stpath,1);}
	           else{return length node_text($stpath->[0]);};
			  }
          elsif($op eq 'substring-after')
		      {my $str1=eval_expr($expr->{left},$stpath,1);
		       my $str2=eval_expr($expr->{right},$stpath,1);
		       $str2=~s/(\W)/\\$1/gs;
		       if($str1=~/^(.*?)$str2(.*)/s){return $2;}
		       else{return '';};
			  }
          elsif($op eq 'substring-before')
		      {my $str1=eval_expr($expr->{left},$stpath,1);
		       my $str2=eval_expr($expr->{right},$stpath,1);
		       $str2=~s/(\W)/\\$1/gs;
		       if($str1=~/^(.*?)$str2/s){return $1;}
		       else{return $str1;};
			  }
          elsif($op eq 'substring')
		      {my $str=eval_expr($expr->{left},$stpath,1);
		       my $n1=eval_expr($expr->{right},$stpath,1);
		       if($expr->{param} ne '')
				   {my $n2=eval_expr($expr->{param},$stpath,1);
				    return substr($str,$n1-1,$n2);}
			   else{return substr($str,$n1-1);};
		      }
          elsif($op eq 'translate')
		      {my $str=eval_expr($expr->{left},$stpath,1);
		       my $rlist=eval_expr($expr->{right},$stpath,1);
			   my $slist=eval_expr($expr->{param},$stpath,1);
			   $rlist=~s/(\W)/\\$1/gs;
			   $slist=~s/(\W)/\\$1/gs;
			   eval "\$str=\~tr\/$rlist\/$slist\/d";
#			   if($@){print "translate error $@\n";};
			   return $str;
			  }
          elsif($op eq 'concat')
			  {my $str=eval_expr($expr->{right},$stpath,1);
		       my $args=$expr->{param};
			   for my $arg (@{$args}){my $addstr=eval_expr($arg,$stpath,1);
			   $str.=$addstr;};
			   return $str;
			  }
          elsif($op eq 'document')
			  {return xsl_document($expr,$stpath,$type);
			  }
          elsif($op eq '-')
		      {my $l=eval_expr($expr->{left},$stpath,1);
		       my $r=eval_expr($expr->{right},$stpath,1);
			   return $l - $r;
			  }
          elsif($op eq '+')
		      {my $l=eval_expr($expr->{left},$stpath,1);
		       my $r=eval_expr($expr->{right},$stpath,1);
			   return $l + $r;
			  }
          elsif($op eq '*')
		      {my $l=eval_expr($expr->{left},$stpath,1);
		       my $r=eval_expr($expr->{right},$stpath,1);
			   return $l * $r;
			  }
          elsif($op eq 'div')
		      {my $l=eval_expr($expr->{left},$stpath,1);
		       my $r=eval_expr($expr->{right},$stpath,1);
			   return $l / $r;
			  }
          elsif($op eq 'number'){my $d=eval_expr($expr->{right},$stpath,1);
		      if($d=~/$_is_number/){return $d;}else{return 'NaN';};}
          elsif($op eq 'sum')
			  {my $ns=eval_expr($expr->{right},$stpath,2);
		       if(ref($ns))
				  {my $sum=0;
		           for my $n (@{$ns}){$sum+=node_text($n->[0]);};
			       return $sum;
				  }else{if($ns=~/$_is_number/){return $ns}else{return 'NaN';}};
			  }
          elsif($op eq 'mod')
		      {my $l=eval_expr($expr->{left},$stpath,1);
		       my $r=eval_expr($expr->{right},$stpath,1);
			   return $l % $r;
			  }
          elsif($op eq 'name')
		      {my $node=$stpath->[0];
			   if($expr->{right}){my $nset=eval_expr($expr->{right},$stpath,2);
			    if(ref($nset)&&($nset->[0])){$node=$nset->[0]->[0];}else{return '';};
				};
	           my $name=$node->{nodename};
			   if($name eq 'text()'){return '';}
			   elsif($name=~/^@/){return substr($name,1);}
			   else{return $name;};
			  }
          elsif($op eq 'system-property'){
			  my $sprop=eval_expr($expr->{right},$stpath,1);
			  if($sprop and defined($ENV{$sprop})){return $ENV{$sprop};}else{return '';};
		  }
		  elsif($op eq 'time'){return time();}
		  elsif($op eq 'gmtime'){
			  my $t=0;
			  if($expr->{left}){$t=eval_expr($expr->{left},$stpath,1);}
			  else{$t=time();};
			  return gmt_time($t,$expr,$type);
		  }
		  else{};
	  
	}
   else
	{ return $expr;};
}

my $_default_template={'nodename'=>'xsl:apply_templates','nodedata'=>'','children'=>[],
'attslist'=>{'cselect'=>$_default_path_expr,'select'=>'node()','mode'=>'no','nparams'=>0}};

sub is_expr_nodeset
{my $cexpr=shift;
if(!ref($cexpr)){return 0;};
my $op=$cexpr->{opname};
if(($op eq '#')||($op eq '/')||($op eq 'key')||($op eq '|')||($op eq 'document')||($op eq 'gmtime'))
	{return 1;}
elsif($op eq '$')
	{if(ref(get_var_val($cexpr))){return 1;}else{return 0;};}
else{return 0;};
}

sub init_sort
{my $sinstr=shift;
 my $select=$sinstr->{attslist}->{'select'};
 if(!$select){$sinstr->{attslist}->{'select'}='.';};
 compile_instr_attr_f($sinstr,'select');
 if(!($sinstr->{attslist}->{order})){$sinstr->{attslist}->{order}='ascending';};
 if(!($sinstr->{attslist}->{'data-type'})){$sinstr->{attslist}->{'data-type'}='text';};
return $sinstr;
}

sub do_sort
{my ($sort_i_num,$sort_instrs,$node_set)=@_;
 my $si=$sort_instrs->[$sort_i_num];
 if($si)
	{my $expr=$si->{cselect};
     my $d_type=$si->{attslist}->{'data-type'};
	 my $order=$si->{attslist}->{order};
	 my %skeys=();
	 for my $path (@{$node_set})
		{my $val=eval_expr($expr,$path,1);
	     if($skeys{$val}){push @{$skeys{$val}},$path;}
		 else{$skeys{$val}=[$path];};
		};
    my @sorted;
	if($d_type eq 'number')
		{if($order eq 'descending')
			{@sorted=sort{$CGIXSLT::b <=> $CGIXSLT::a} keys %skeys;}
         else
			{@sorted=sort{$CGIXSLT::a <=> $CGIXSLT::b} keys %skeys;};
		}
    else
		{if($order eq 'descending')
			{@sorted=sort{$CGIXSLT::b cmp $CGIXSLT::a} keys %skeys;}
         else
			{@sorted=sort keys %skeys;};
	    };
	my $r_node_set=[];
	for my $sval (@sorted)
		{my $l_ns=$skeys{$sval};
	     if($#{$l_ns}>0){$l_ns=do_sort($sort_i_num+1,$sort_instrs,$l_ns);};
		 push @{$r_node_set},@{$l_ns};
	    };
    return $r_node_set;
	}
 else{return $node_set;};
};

sub set_loc_params
{my $instr=shift;
my $npar=0;
for my $ch (@{$instr->{children}})
	{if($ch->{nodename} eq 'xsl:with-param')
		{
         my $name=$ch->{attslist}->{name};
		 my $sel=$ch->{attslist}->{'select'};
	    if($name)
			{$npar++;
		     if(!defined($instr->{params})){$instr->{params}=[];};
			 if($sel){compile_instr_attr_f($ch,'select');};
			 push @{$instr->{params}},$ch;
			}
		else{exiting_code("xsl:with\-param has no name attribute\n");};
		}
     elsif($ch->{nodename} eq 'xsl:sort')
		{if(!defined($instr->{'sort'})){$instr->{'sort'}=[];};
	     push @{$instr->{'sort'}}, init_sort($ch);
		};
	};
$instr->{nparams}=$npar;
}

sub set_atts_flag
{my $rtf=shift;
 my $inum=0;
 for my $ch (@{$rtf->{children}})
	{if($ch->{nodename}=~/^@/){$inum+=1;}
     else{my $nname=$ch->{nodename};
	 if(($nname ne 'text()')and($nname ne 'comment()')){set_atts_flag($ch);};
	     };
	};
$rtf->{attsnumb}=$inum;
}

sub tree_fragment
{my ($varel,$stpath)=@_;
 my $rtf=newnode('/','');
 my $rtfpath=[$rtf];
 eval_template($varel,$stpath,$rtfpath);
 set_atts_flag($rtf);
 my $nset=[$rtfpath];
 if($rtf->{attsnumb}){exiting_code("result tree fragment cannot have attribute nodes");};
 if($rtf->{children}->[0]){return $nset;}
 else{return [];};
}

sub init_loc_params
{my ($instr,$stpath)=@_;
 my $params=$instr->{params};
 my $npar=$instr->{nparams};
 while($npar>0){$npar--;my $p=$params->[$npar];
 my $name=$p->{attslist}->{name};
 my $expr=$p->{cselect};
 if($expr){unshift @local_vars_values,eval_expr($expr,$stpath,2);}
 else{unshift @local_vars_values,tree_fragment($p,$stpath);};
      unshift @local_vars_names,$name;
 };
}

sub apply_templates
{
	my ($instr,$stpath,$rtpath)=@_;
	my $code=$instr->{cselect};
 if(defined($code))
 {  my $mode=$instr->{attslist}->{'mode'};
    my $t_keys=$template_modes{$mode};
	my $nump=$instr->{nparams};
	my $node_paths=eval_expr($code,$stpath,2);
	if($instr->{'sort'}){$node_paths=do_sort(0,$instr->{'sort'},$node_paths);};
	if($nump){init_loc_params($instr,$stpath);};
	push @_focus_stack_,$_focus_;
	push @_count_stack_,$_position_;
	$_focus_=$node_paths;
	$_position_=0;
	$_last_=0;
	for my $path (@{$node_paths})
	{   $_position_++;
		my $t=select_template($path,$t_keys);
		if($t){$param_nums=$nump;eval_template($t,$path,$rtpath);}
		else{
			my $node=$path->[0];
			my $rnode=$rtpath->[0];
			if($node->{nodename} eq 'text()')
				{push @{$rnode->{children}},$node;}
			elsif($node->{nodename}=~/^@/)
				{push @{$rnode->{children}},newnode('text()',$node->{nodedata});}
			else{apply_templates($_default_template,$path,$rtpath);};
		    };
	};
	$_focus_=pop @_focus_stack_;
	$_position_=pop @_count_stack_;
	$_last_=0;
    while($nump>0){shift @local_vars_names;shift @local_vars_values;$nump--;};
 }
 else
	{ my $mode=$instr->{attslist}->{'mode'};
      $code=$instr->{attslist}->{'select'};
      if(!$mode){$instr->{attslist}->{'mode'}='no';};
	   if(!defined($code)){$instr->{cselect}=$_default_path_expr;
	                       set_loc_params($instr);
	                       apply_templates($instr,$stpath,$rtpath);}
	   else
		{ my $cexpr=compile_instr_attr_f($instr,'select');
		  if(is_expr_nodeset($cexpr))
			{set_loc_params($instr);apply_templates($instr,$stpath,$rtpath);}
	      else{exiting_code("xsl:apply\-templates has invalid select attribute\n$code\n");};
		};
	};
}

sub extract_sort
{my $instr=shift; 
forloop:for my $ch (@{$instr->{children}})
	{if($ch->{nodename}=~/^xsl\:/)
		{if($ch->{nodename} eq 'xsl:sort')
			{
		     if(!defined($instr->{'sort'})){$instr->{'sort'}=[];};
	         push @{$instr->{'sort'}}, init_sort($ch);
			}
         else{last forloop;};
		};
	};
}

sub for_each
{
	my ($instr,$stpath,$rtpath)=@_;
	my $code=$instr->{cselect};
	if(defined($code))
	{   push @_focus_stack_,$_focus_;
	    push @_count_stack_,$_position_;
	    my $node_paths=eval_expr($code,$stpath,2);
	    if($instr->{'sort'}){$node_paths=do_sort(0,$instr->{'sort'},$node_paths);};
	    $_focus_=$node_paths;
	    $_position_=0;
		$_last_=0;
		for my $path (@{$node_paths})
		{$_position_++;eval_template($instr,$path,$rtpath);};
		 $_focus_=pop @_focus_stack_;
	     $_position_=pop @_count_stack_;
		 $_last_=0;
	}
    else
	{  my $cexpr=compile_instr_attr_f($instr,'select');
	   if(is_expr_nodeset($cexpr))
			  {extract_sort($instr);for_each($instr,$stpath,$rtpath);}
	   else{my $sel=$instr->{attslist}->{'select'};
		    exiting_code("xsl:for\-each has invalid select attribute\n$sel\n");
	   };
	};
}

sub value_of
{
	my ($instr,$stpath,$rtpath)=@_;
	my $code=$instr->{cselect};
	if(defined($code))
	{   my $text=eval_expr($code,$stpath,1);
        if($text ne ''){my $rnode=$rtpath->[0];
		    my $n={};
			$n->{nodename}='text()';
	        $n->{children}=[];
	        $n->{nodedata}=$text;
			if($instr->{noe}){$n->{noe}=1;};
		    push @{$rnode->{children}},$n;};			 
	}
    else
	{   compile_instr_attr_f($instr,'select');
	    if(defined($instr->{attslist}->{'disable-output-escaping'}) &&($instr->{attslist}->{'disable-output-escaping'} eq 'yes')){$instr->{noe}=1;};
		value_of($instr,$stpath,$rtpath);
	};
}

sub choose
{	my ($instr,$stpath,$rtpath)=@_;
    my $chs=$instr->{children};
FOR: for my $ch (@{$chs})
	 {  
		if($ch->{nodename} eq 'xsl:when')
		{my $code=$ch->{ctest};
 		   if(defined($code))
			{if(eval_expr($code,$stpath,0)){eval_template($ch,$stpath,$rtpath);last FOR;};}
           else
			{my $testexpr=compile_instr_attr_f($ch,'test');
		     if(eval_expr($testexpr,$stpath,0)){eval_template($ch,$stpath,$rtpath);last FOR;};
			};
		}
		else
		{     if($ch->{nodename} eq 'xsl:otherwise')
			  {eval_template($ch,$stpath,$rtpath);last FOR;};
		};
	 };
}

sub xsl_if
{
	my ($instr,$stpath,$rtpath)=@_;
	my $code=$instr->{ctest};
	if(defined($code))
	 {if(eval_expr($code,$stpath,0)){eval_template($instr,$stpath,$rtpath);};}
	else
	 {my $testexpr=compile_instr_attr_f($instr,'test');
	  if(eval_expr($testexpr,$stpath,0)){eval_template($instr,$stpath,$rtpath);};
	 };
}

sub xsl_copy
{
	my ($instr,$stpath,$rtpath)=@_;
	my $cnode=$stpath->[0];
	my $snode=$rtpath->[0];
 if($cnode->{nodename} ne '/')
  {   
	if($cnode->{nodename}=~/^@/)
	{unshift @{$snode->{children}},newnode($cnode->{nodename},$cnode->{nodedata});}
	elsif($cnode->{nodename} eq 'text()')
	{push @{$snode->{children}},newnode('text()',$cnode->{nodedata});}
	else
	{my $n=newnode($cnode->{nodename},'');
	 push @{$snode->{children}},$n;
	 unshift @{$rtpath},$n;
	 eval_template($instr,$stpath,$rtpath);
	 shift @{$rtpath};
	};
  }else{eval_template($instr,$stpath,$rtpath);};
}

sub get_attr_value
{my ($name,$el,$stpath,$rtpath)=@_;
 my $chs=$el->{children};
 my $aname='@';
 $aname.=$name;
 my $size=$el->{attsnumb};
 my $i=0;
 while($i<$size)
	{my $ch=$chs->[$i];
     if($ch->{nodename} eq $aname){return attr_value($ch,$stpath,$rtpath);};
     $i++;};
 return '';
}

sub attr_value
{
	my ($anode,$snodepath,$rtpath)=@_;
	my $elist=$anode->{compiled};
	if(!defined($elist))
	{ my $str=$anode->{nodedata};
	  $elist=[];
	  while($str=~/^(.*?)\{(.*?)\}(.*)/s)
	  {if($1 ne ''){push @{$elist}, $1;};
	   my $sexpr=$2;
	   $str=$3;
           my  $code=parse_expresion($sexpr);
			 if($code<0)
		      {push @{$elist},$compiled_expresions[-$code];}
             else
		      {exiting_code("invalid expression $anode->{nodedata} in attribute value\n");};
	  };
	  if($str ne ''){push @{$elist}, $str;};
	  $anode->{compiled}=$elist;
	};
	my $nstr='';
	for my $ex (@{$elist}){$nstr.=eval_expr($ex,$snodepath,1);};
	return $nstr;
}

sub has_preceding_node
{my ($stpath,$k,$els)=@_;
 my $cnode=$stpath->[$k];
 my $name=$cnode->{nodename};
 if($name ne '/')
	{ my $pcnode=$stpath->[$k+1];
      my $chs=$pcnode->{children};
	  for my $ch (@{$chs})
		  {for my $en (@{$els})
			  {
		       if($ch->{nodename} eq $en)
		       {if($ch!=$cnode){return 1;}else{return 0;};};
			  };
		  };
		  return 0;
	}else{return 0;};
}

sub xsl_number
{my ($instr,$stpath,$rtpath)=@_;
 my $val=$instr->{attslist}->{value};
 my $level=$instr->{attslist}->{level};
 my $format=$instr->{attslist}->{'format'};
 if(!$format){$format='1';};
 my $rt=$rtpath->[0];
 if(!$val)
	{
     if($level)
		{my $nances=$#{$stpath};
	     my $from=$instr->{attslist}->{from};
		 if($from){for (my $k=0;$k<=$nances;$k++){if($stpath->[$k]->{nodename} eq $from){$nances=$k-1;};};};
		 my $count=$instr->{attslist}->{count};
		 my @els=split('\|',$count);
		 if($level eq 'multiple')
			{
			 if(!defined($instr->{attslist}->{numbers})){$instr->{attslist}->{numbers}=[];
			 $instr->{attslist}->{cash}={};};
			 my $ns=$instr->{attslist}->{numbers};
			 my $cash=$instr->{attslist}->{cash};
			 my $snode=$stpath->[0];
			 if($cash->{$snode}){$ns=$cash->{$snode};}
			 else
				{my $i=-1;
				 my $startbit=0;
			     if($count)
				 {
			     for my $el (@els){for (my $k=0;$k<=$nances;$k++)
				 {my $stn=$stpath->[$k];if($stn->{nodename} eq $el){$i++;if($startbit==0){if(has_preceding_node($stpath,$k,\@els)){$startbit=1;};};};};};
				 }else{$i=$nances;$startbit=1;};
			     if($startbit==0){$instr->{attslist}->{numbers}=[];$ns=$instr->{attslist}->{numbers};};
			     if($i>=0)
				  {my $size=$#{$ns};
			       if($size==$i){$ns->[$i]=$ns->[$i]+1;}
				   elsif($size>$i){$ns->[$i]=$ns->[$i]+1;while($size>$i){pop @{$ns};$size--;};}
				   else{while($size<$i){push @{$ns},1;$size++;};};
				   $cash->{$snode}=[@{$ns}];
				  }else{$instr->{attslist}->{numbers}=[];goto blockend;};
				};
				 my $str='';
				    if($format=~/^(\W+)(.*)/){$str.=$1;$format=$2;};
					my $lastsep='';
					my $strend='';
					if($format=~/(.*)(\W+)$/){$format=$1;$strend=$2;};
					for my $n (@{$ns})
						{$str.=$lastsep;
					     if($format=~/^(\w+)(\W+)(\w.*)/){$format=$3;$lastsep=$2;}
						 else{if($lastsep eq ''){$lastsep='.';};};
						 $str.=$n;
					    };
                 $str.=$strend;
				 push @{$rt->{children}},newnode('text()',$str);
				 blockend:
			}
        elsif($level eq 'any')
			{
			 if(!defined($instr->{attslist}->{numbers})){$instr->{attslist}->{numbers}=[0];};
			 my $ns=$instr->{attslist}->{numbers};
			 if($count)
				{
			 for my $el (@els){for (my $k=0;$k<=$nances;$k++)
				 {my $stn=$stpath->[$k];
			      if($stn->{nodename} eq $el){$ns->[0]=$ns->[0]+1;goto end;};};};
				}else{if($nances>0){$ns->[0]=$ns->[0]+1;goto end;};};
             goto finish;
			 end:
             my $num=$ns->[0];
				 my $str='';
			     if($format=~/^(\W+)(.*)/){$str.=$1;$format=$2;};
				 $str.=$num;
				 if($format=~/^(\w+)(.*)/){$str.=$2;};
				 push @{$rt->{children}},newnode('text()',$str);
             finish:
			}
        elsif($level eq 'single')
			{
			};
		}
	 else
		{    my $n=$_position_;
	         if($format=~/^(\W*)(\w+?)(\W*)/){my $fn=$1;$fn.=$n;$fn.=$3;
			 push @{$rt->{children}},newnode('text()',$fn);}
			 else{push @{$rt->{children}},newnode('text()',$n);}
		};
	}
 else
	{
	};
}

sub xsl_element
{  my ($instr,$stpath,$rtpath)=@_;
	my $ename=get_attr_value('name',$instr,$stpath,$rtpath);
	  if($ename=~/^[\w\-\:\.]+$/){my $ne=newnode($ename,'');my $ce=$rtpath->[0];
	                              push @{$ce->{children}}, $ne;
	                              unshift @{$rtpath},$ne;
								  eval_template($instr,$stpath,$rtpath);shift @{$rtpath};
								 }
      else{exiting_code("invalid name of new element: \"$ename\"\n");};
}

sub xsl_attribute
{my ($instr,$stpath,$rtpath)=@_;
      my $aname=get_attr_value('name',$instr,$stpath,$rtpath);
	  if($aname=~/^[\w\-\:\.]+$/){$aname='@'.$aname;my $anode=newnode($aname,'');
	                              my $newrtpath=[$anode];eval_template($instr,$stpath,$newrtpath);
	                              my $avalue=node_text($anode);
								  $anode->{children}=[];
								  #if($avalue ne '')
		                           {$anode->{nodedata}=$avalue;
								    my $ce=$rtpath->[0];
								    my $size=$#{$ce->{children}};
								    if($size>=0){
										for (my $i=0;$i<=$size;$i++) {
                                         my $n=$ce->{children}->[$i];
										 if($n->{nodename} eq $aname){$n->{nodedata}=$avalue;goto end;};
										};
										my $lastn=$ce->{children}->[$size];
									    if($lastn->{nodename}=~/^@/){push @{$ce->{children}}, $anode;};
										end:
												}else{push @{$ce->{children}}, $anode;};
								   };
	                             }
     else{exiting_code("invalid name of new attribute: \"$aname\"\n");};
}

sub xsl_var
{my ($instr,$stpath,$rtpath)=@_;
	my $code=$instr->{attslist}->{'select'};
	my $name=$instr->{attslist}->{name};
if($name)
{ if(defined($code))
	{my $select=$instr->{cselect}; 
	 if(defined($select))
	   {   my $value=eval_expr($select,$stpath,2);
		   unshift @local_vars_values,$value;
		   unshift @local_vars_names,$name;
	   }
      else
	   {compile_instr_attr_f($instr,'select');
	    xsl_var($instr,$stpath,$rtpath);};
	}
  else
	{
	 unshift @local_vars_values,tree_fragment($instr,$stpath);
	 unshift @local_vars_names,$name;
	};
}else{exiting_code("xsl:variable has no name attribute\n");};  
}

sub xsl_param
{my ($instr,$stpath,$rtpath)=@_;
my $name=$instr->{attslist}->{name};
if($name)
	{for (my $k=0;$k<$param_nums;$k++) {
	 if($name eq $local_vars_names[$k]){return 0;};};
	 xsl_var($instr,$stpath,$rtpath);
	 $param_nums++;
	 return 1;
	}
	else{exiting_code("xsl:param has no name attribute\n");};
}

sub xsl_call_template
{my ($instr,$stpath,$rtpath)=@_;
 my $name=$instr->{attslist}->{name};
 my $t=$template_names{$name};
 my $nump=$instr->{nparams};
 if(!defined($nump)){set_loc_params($instr);$nump=$instr->{nparams};};
 $param_nums=$nump;
 if($nump){init_loc_params($instr,$stpath);};
 if($t){eval_template($t,$stpath,$rtpath);}
 else{exiting_code("no template with name\"$name\"\n")};
 while($nump>0){shift @local_vars_names;shift @local_vars_values;$nump--;};
 return 0;
}

sub xsl_copy_of
{my ($instr,$stpath,$rtpath)=@_;
	my $code=$instr->{cselect};
	if(defined($code))
	{	my $res=eval_expr($code,$stpath,2);
		if(ref($res))
		{my $rnode=$rtpath->[0];
		 for my $ns (@{$res}){my $n=$ns->[0];
		 if($n->{nodename} eq '/'){push @{$rnode->{children}},@{$n->{children}};}
		 else{if($n->{nodename}!~/^@/){push @{$rnode->{children}},$n};};
		 };
		}
		else
		{if($res ne ''){my $rnode=$rtpath->[0];
		 push @{$rnode->{children}},newnode('text()',$res);};
		};
	}
    else
	{ compile_instr_attr_f($instr,'select');
	  xsl_copy_of($instr,$stpath,$rtpath);
	};
}

sub xsl_comment
{my ($instr,$stpath,$rtpath)=@_;
 my $rnode=$rtpath->[0];
 my $comnode=newnode('/','');$comnode->{attsnumb}=0;
 my $cpath=[$comnode];
 eval_template($instr,$stpath,$cpath);
 my $str=node_text($comnode);
 if($str ne '')
	{push @{$rnode->{children}},newnode('comment()',$str);};
}

sub xsl_text
{my ($instr,$stpath,$rtpath)=@_;
 my $rnode=$rtpath->[0];
 my $i=$instr->{attsnumb};
 my $n=$instr->{children}->[$i];
 if($n->{nodename} eq 'text()')
	{
 if(!defined($n->{noe}))
	{if($instr->{attslist}->{'disable-output-escaping'} eq 'yes')
	 {$n->{noe}=1;}else{$n->{noe}=0;};
	};
 push @{$rnode->{children}},$n;
	};
}

sub xsl_message
{my ($instr,$stpath,$rtpath)=@_;
 my $message=newnode('/','');$message->{attsnumb}=0;
 my $mpath=[$message];
 eval_template($instr,$stpath,$mpath);
 print_output($message);
 if($instr->{attslist}->{terminate} eq 'yes'){exit;};
}

sub eval_instruction
{
my ($instr,$stpath,$rtpath)=@_;
my $iname=$instr->{nodename};
  if($iname eq 'xsl:apply-templates'){
	  &apply_templates;}
  elsif($iname eq 'xsl:value-of'){
	  &value_of;}
  elsif($iname eq 'xsl:for-each'){
	  &for_each;}
  elsif($iname eq 'xsl:choose'){
	  &choose;}
  elsif($iname eq 'xsl:copy-of'){
	  &xsl_copy_of;}
  elsif($iname eq 'xsl:if'){
	  &xsl_if;}
  elsif($iname eq 'xsl:text'){
	  &xsl_text;}
  elsif($iname eq 'xsl:call-template'){
	  &xsl_call_template;}
  elsif($iname eq 'xsl:copy'){
      &xsl_copy;}
  elsif($iname eq 'xsl:variable'){
	  &xsl_var;return 1;}
  elsif($iname eq 'xsl:param'){
      return &xsl_param;}
  elsif($iname eq 'xsl:element'){
	  &xsl_element;}
  elsif($iname eq 'xsl:attribute'){
	  &xsl_attribute;}
  elsif($iname eq 'xsl:message'){
	  &xsl_message;}
  elsif($iname eq 'xsl:number'){
	  &xsl_number;}
  elsif($iname eq 'xsl:comment'){
	  &xsl_comment;}
  else{
  };
  return 0;
}

sub eval_element
{
my ($e,$stpath,$rtpath)=@_;
my $ech=$e->{children};
my $ne={};
$ne->{children}=[];
$ne->{nodename}=$e->{nodename};
$ne->{nodedata}='';
my $ce=$rtpath->[0];
push @{$ce->{children}}, $ne;
unshift @{$rtpath},$ne;
my $varnum=0;
	for my $child (@{$ech})
	{	if($child->{nodename} eq 'text()')
		{push @{$ne->{children}},$child;}
		elsif($child->{nodename}=~/^@/){
			my $avalue=attr_value($child,$stpath,$rtpath);
			push @{$ne->{children}},newnode($child->{nodename},$avalue);}
		else
		{if($child->{nodename}!~/^xsl\:/){eval_element($child,$stpath,$rtpath);}
		 else{$varnum=$varnum+eval_instruction($child,$stpath,$rtpath);};};
	};
shift @{$rtpath};
while($varnum>0){shift @local_vars_names;shift @local_vars_values;$varnum--;};
}

sub eval_template
{
my ($t,$stpath,$rtpath)=@_;
my $tch=$t->{children};
my $size=$#{$tch};
my $varnum=0;
	for (my $k=$t->{attsnumb};$k<=$size;$k++)
	{	my $tchild=$tch->[$k];
		if($tchild->{nodename}!~/^xsl\:/)
		{ if(defined($tchild->{attsnumb}))
		  {eval_element($tchild,$stpath,$rtpath);}
		  else
		  {my $sn=$rtpath->[0];push @{$sn->{children}},$tchild;};
		}
		else
		{$varnum=$varnum+eval_instruction($tchild,$stpath,$rtpath);};
	};
while($varnum>0){shift @local_vars_names;shift @local_vars_values;$varnum--;};
}

sub compile_stylesheet
{my $st=shift;
 my $xml=shift;
 my $ts=[];
 my $vars=[];
 install_stylesheet($st,$ts,$vars);
 install_templates($ts);
 for my $var (@{$vars})
	{my $varname=$var->{attslist}->{name};
     if($varname)
	 {if((!defined($glob_vars{$varname}))&&(!defined($glob_strings{$varname}))&&(!defined($glob_objects{$varname})))
	  {my $startp=[$xml];
	   my $select=$var->{attslist}->{'select'};
	   if($select)
		 {my $code=parse_expresion($select);
	      if($code<0){$glob_vars{$varname}=eval_expr($compiled_expresions[-$code],$startp,2);}
		  else{exiting_code("glob var \"$varname\" has invalid select attribute\n");};
		 }
	   else
		 { if(is_template_not_empty($var)){strip_all_spaces($var);};
		   $glob_vars{$varname}=tree_fragment($var,$startp);};
	  }else{exiting_code("glob variable \"$varname\" has been defined already\n");};
	 };
	};
 for (my $i=0;$i<=$#_http_fields;$i++) {
	 my $startp=[$xml];
	 $_http_contents[$i]=norm_space(node_set_to_str(tree_fragment($_http_contents[$i],$startp)));
 };
}

sub  transform
{

my $xml=undef;
my $xml_file=$XS_PARAMS{'source'};
if($xml_file){
	if($xml_file=~/\0/sg){error_log("File ($xml_file) contains string end (0) character\n");
    exiting_code("Illigal name of file\n");};
	if($xml_file!~/\.xml$/){$xml_file=join('',$xml_file,'.xml');};$xml=read_xml_file($xml_file);}
else{$xml=newnode('/','');$xml->{attsnumb}=0;};
my $st_file='';
if($XS_PARAMS{'style'}){$st_file=$XS_PARAMS{'style'};
	if($st_file=~/\0/sg){error_log("File ($st_file) contains string end (0) character\n");
    exiting_code("Illigal name of file\n");};
if($st_file!~/\.xsl$/){$st_file=join('',$st_file,'.xsl');};}
else{if($_source_style){$st_file=$_source_style;$XSLT_BASE=$XML_BASE;}
     else{if($xml_file=~/\.xml$/){$st_file=$xml_file;$st_file=~s/\.xml$/\.xsl/;};};};
if($st_file)
{
my $xsl_stylesheet=read_xsl_file($st_file);
compile_stylesheet($xsl_stylesheet,$xml);
if(defined($ENV{'CONTENT_LENGTH'}) && ($ENV{'CONTENT_LENGTH'}>$MAX_CONTENT_SIZE)){exiting_code("exceed data length ($MAX_CONTENT_SIZE) limitation\n");};

my $new_xml=newnode('/','');
$new_xml->{attsnumb}=0;
my $start_source_path=[$xml];
my $start_result_path=[$new_xml];
my $t_mode=$template_modes{'no'};
my $t=select_template($start_source_path,$t_mode);
if($t){eval_template($t,$start_source_path,$start_result_path);}
else{apply_templates($_default_template,$start_source_path,$start_result_path);};
return $new_xml;
}else{print_error("Stylesheet is not passed");};
}

sub error_log
{my $err=shift;
	open(LOG,'>> xsltp.log') or die "cannot open log file";
	binmode(LOG);
	print LOG "ERROR:\n", $err;
	my $t=localtime(time);
	print LOG "DATE: ", $t,"\n";
	print LOG "REMOTE_ADDR: ", $ENV{'REMOTE_ADDR'},"\n";
	print LOG "PARAMETERS PASSED:\n";
	for my $key (keys %XS_PARAMS)
		{print LOG $key,'="',$XS_PARAMS{$key},'"',"\n";};
	print LOG '****************************',"\n";
	close(LOG);
}
sub exiting_code  ####################################################
{
	my $error=shift;
	$_xpath_expr_error_.=$error;
	if($xsltp_error_message){
	error_log($_xpath_expr_error_);
	my $error_el=$xsltp_error_message;$xsltp_error_message=undef;
	my $e_xml=newnode('/','');
    $e_xml->{attsnumb}=0;
    my $xml=newnode('/','');
    $xml->{attsnumb}=0;
    my $start_source_path=[$xml];
    my $error_path=[$e_xml];
	eval_template($error_el,$start_source_path,$error_path);
	print_output($e_xml);
	exit;
	}
	else{print_error($_xpath_expr_error_);}; 
}

sub print_error
{my $err=shift;
if($_http_output)
	{print "Content-type:text/html\n\n",'<html><body>',$err,'</body></html>';}
else{print $err;};
exit;
}

sub print_http_headers
{if($_http_output)
{
 my %https=();
 for (my $i=0;$i<=$#_http_fields;$i++) {
 if($_http_contents[$i]){
	 if(not($https{$_http_fields[$i]})){
		 print $_http_fields[$i],':',$_http_contents[$i],"\n";
         $https{$_http_fields[$i]}=1;
	 };
 };
 };
 if($https{'Content-type'}){print "\n";}
 else{
	#print "Content-type:text/html\n\n";
	};
};
}

sub print_output
{
my $result_tree=shift;
my $output_str='';
print_doc($result_tree,\$output_str);
if($_http_flag){print_http_headers();$_http_flag=0;
if($CHARS_MODEL eq 'bytes'){binmode(STDOUT);}
else{
	if($] > 5.007){binmode(STDOUT,":utf8");};
	};
	           };

#print $output_str;

return $output_str;

}

sub init {
$CHARS_MODEL='';
$stylesheet_prefix='';
$result_prefix='';
$_source_style='';
@_opened_stylesheets=();
$XML_BASE='';
$_xml_base_flag=0;
$XSLT_BASE='';
$MAX_CONTENT_SIZE=1024;
%template_modes=();
%template_names=();
%key_names=();
%stylesheet_keys=();
%XS_PARAMS=();
%glob_strings=();
%glob_objects=();
%glob_vars=();
@local_vars_values=();
@local_vars_names=();
$param_nums=0;
$output_indent='';
$output_method='';
$output_encoding='';
$omit_xmldecl='no';
$cgi_object=undef;
$xsltp_error_message=undef;
@_http_fields=();
@_http_contents=();
$_http_flag=1;
$_http_output=1;
@_focus_stack_=();
@_count_stack_=();
$_focus_=[];
$_position_=0;
$_last_=0;
$_index_=0;
$_last_node_=0;
$_xpath_expr_error_=undef;
$_fotal_error_=undef;
@compiled_expresions=(undef,$_default_path_expr);
$namber_of_exprs=2;
return \%XS_PARAMS;
}

sub read_https
{init();
 my $params_string;
 my $cgi_metod=$ENV{'REQUEST_METHOD'};
 my $content_length=$ENV{'CONTENT_LENGTH'};
 my $content_type=$ENV{'CONTENT_TYPE'};
if(defined($cgi_metod))
{
if ($cgi_metod eq 'POST')
    { if($content_type eq 'application/x-www-form-urlencoded')
		{if(read(STDIN, $params_string, $content_length)!=$content_length)
		 {exiting_code("Cannot read parameters passed\n");};
		}
	 else
		{eval{require CGI;
	     $cgi_object=new CGI();
		 %XS_PARAMS=$cgi_object->Vars();};
		 if($@){error_log("CGI error $@\n");exiting_code("CGI error: cannot read parameters\n");};
		 goto start_prog;
	    };
    }
elsif ($cgi_metod eq 'GET' || $cgi_metod eq 'HEAD')
    {
      $params_string=$ENV{'QUERY_STRING'};
    }
else{exiting_code("Unknown method $cgi_metod\n");};
 my @params_array=split(/[&;]/,$params_string);
 for my $param (@params_array)
	{my ($key,$value)=split(/=/,$param,2);
     $value=~tr/+/ /;
     $value=~s/%([\dA-Fa-f][\dA-Fa-f])/pack ("C", hex ($1))/eg;
     $key=~tr/+/ /;
     $key=~s/%([\dA-Fa-f][\dA-Fa-f])/pack ("C", hex ($1))/eg;
	 if(!defined($XS_PARAMS{$key}))
	 {$XS_PARAMS{$key}=$value;}else{$XS_PARAMS{$key}=join("\0",$XS_PARAMS{$key},$value)};
	};
};

start_prog:
 my $cookie_string='';
 if($ENV{'HTTP_COOKIE'})
	{$cookie_string=$ENV{'HTTP_COOKIE'};}
 elsif($ENV{'COOKIE'})
	{$cookie_string=$ENV{'COOKIE'};};
 if($cookie_string)
	{my @params_cookie=split(/;/,$cookie_string);
     for my $kv (@params_cookie)
	 {$kv=~s/^\s+//sg;
	  $kv=~s/\s+$//sg;
	  if($kv)
		 {my ($key,$value)=split(/=/,$kv,2);
	      if($key){
	      if(!defined($XS_PARAMS{$key})){$XS_PARAMS{$key}=$value;};};
		 };
     }; 
	};
return \%XS_PARAMS;
}

1;
__END__
