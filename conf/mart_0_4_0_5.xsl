<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- deal with AttributeDescription conversion -->
<xsl:template match="AttributeDescription">
  <xsl:copy>
    <!-- call other templates eg identity copy on all the attributes-->
    <xsl:apply-templates select="@*"/>
  
    <!-- create the new placeholder attributes  -->
    <xsl:if test="contains(@internalName,'.')">
	<xsl:attribute name="pointerDataset"> <xsl:value-of select="substring-before(@internalName,'.')" /> </xsl:attribute>
	<xsl:attribute name="pointerInterface">default</xsl:attribute>
        <xsl:choose>
            <xsl:when test="contains(@internalName,'filter.')">
        	<xsl:attribute name="pointerFilter"> <xsl:value-of select="substring-after(@internalName,'filter.')" /> </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
	        <xsl:attribute name="pointerAttribute"> <xsl:value-of select="substring-after(@internalName,'.')" /> </xsl:attribute>
	    </xsl:otherwise>
        </xsl:choose>
    </xsl:if>
    
    <!-- call other templates eg identity copy on all the child elements -->
    <xsl:apply-templates select="node()"/>
    
  </xsl:copy>
</xsl:template>
	
<!-- deal with FilterDescription conversion -->
<xsl:template match="FilterDescription">
  <xsl:copy>
    <!-- call other templates eg identity copy on all the attributes-->
    <xsl:apply-templates select="@*"/>
  
    <!-- create the new placeholder attributes  -->
    <xsl:if test="contains(@internalName,'.')">
	<xsl:attribute name="pointerDataset"> <xsl:value-of select="substring-before(@internalName,'.')" /> </xsl:attribute>
	<xsl:attribute name="pointerInterface">default</xsl:attribute>
        <xsl:attribute name="pointerFilter"> <xsl:value-of select="substring-after(@internalName,'.')" /> </xsl:attribute>

    </xsl:if>

    <!-- create the displayType attribute  -->
    <xsl:choose>
	<xsl:when test="count(.//Option) &gt; 0 and .//Option/@tableConstraint != ''">
	    <xsl:attribute name="displayType">container</xsl:attribute>
	</xsl:when>	
	<xsl:when test="count(.//Option) &gt; 0 and .//Option/@value != ''" >
	    <xsl:attribute name="displayType">list</xsl:attribute>
        </xsl:when>
	<xsl:when test="@type = 'boolean' or @type = 'boolean_num'" >
	    <xsl:attribute name="displayType">list</xsl:attribute>
        </xsl:when>
	<xsl:when test="@qualifier != ''">
	    <xsl:attribute name="displayType">text</xsl:attribute>
	</xsl:when>

        

        <xsl:otherwise>
	   <xsl:attribute name="displayType"></xsl:attribute>
        </xsl:otherwise>
    </xsl:choose>

    <!-- create the multipleValues attribute  -->
    <xsl:choose>
	<xsl:when test="@multipleValues = 1 or (count(@filterList) &gt; 0 and @filterList != '')" >
	    <xsl:attribute name="multipleValues">1</xsl:attribute>
        </xsl:when>
	<xsl:otherwise>
	   <xsl:attribute name="multipleValues"></xsl:attribute>
        </xsl:otherwise>
    </xsl:choose>	

    <!-- create the graph attribute  -->
    <xsl:choose>
	<xsl:when test="@tableConstraint != '' and count(.//Option/Option) &gt; 0" >
	    <xsl:attribute name="graph">1</xsl:attribute>
        </xsl:when>
	<xsl:otherwise>
	   <xsl:attribute name="graph"></xsl:attribute>
        </xsl:otherwise>
    </xsl:choose>

    <!-- create the style attribute for displayType list filters -->
    <xsl:choose>
        <xsl:when test="count(@filterList) &gt; 0 and @filterList != ''" >
	    <xsl:attribute name="style">checkbox</xsl:attribute>
        </xsl:when>
        <xsl:when test="@type='boolean' or @type = 'boolean_num'" >
	    <xsl:attribute name="style">radio</xsl:attribute>
        </xsl:when>
	<xsl:when test="count(.//Option) &gt; 0 and .//Option/@tableConstraint != ''">
	    <xsl:attribute name="style"></xsl:attribute>
        </xsl:when>
        <xsl:when test="count(.//Option) &gt; 0 and .//Option/@value != ''" >
	    <xsl:attribute name="style">menu</xsl:attribute>
        </xsl:when>
	<xsl:otherwise>
	   <xsl:attribute name="style"></xsl:attribute>
        </xsl:otherwise>
    </xsl:choose>

    <!-- create the autoCompletion attribute  -->
    <xsl:if test="count(@autoCompletion) = 0">
		<xsl:attribute name="autoCompletion"></xsl:attribute>	   	
    </xsl:if>
 
    <!-- add value options for boolean filters for display purposes  -->
    <xsl:if test="count(.//Option) = 0 and (@type = 'boolean' or @type = 'boolean_num') " >
        <xsl:element name="Option">
		<xsl:attribute name="internalName">only</xsl:attribute>
                <xsl:attribute name="displayName">Only</xsl:attribute>
                <xsl:attribute name="value">only</xsl:attribute>
	</xsl:element>
        <xsl:element name="Option">
		<xsl:attribute name="internalName">excluded</xsl:attribute>
                <xsl:attribute name="displayName">Excluded</xsl:attribute>
                <xsl:attribute name="value">excluded</xsl:attribute>
	</xsl:element>
    </xsl:if>
    <!-- call other templates eg identity copy on all the child elements -->
    <xsl:apply-templates select="node()"/>
  </xsl:copy>
</xsl:template>










<!-- deal with Option filter conversion -->
<xsl:template match="Option">
  <xsl:copy>
    <!-- call other templates eg identity copy on all the attributes-->
    <xsl:apply-templates select="@*"/>
  
    <!-- create the displayType attribute  -->
    <xsl:choose>
	<xsl:when test="@type = 'boolean' or @type = 'boolean_num'" >
	    <xsl:attribute name="displayType">list</xsl:attribute>
        </xsl:when>
	<xsl:when test="@tableConstraint != ''">
	    <xsl:attribute name="displayType">text</xsl:attribute>
	</xsl:when>		
        <xsl:otherwise>
	   <xsl:attribute name="displayType"></xsl:attribute>
        </xsl:otherwise>
    </xsl:choose>

    <!-- create the multipleValues attribute  -->
    <xsl:choose>
	<xsl:when test="@tableConstraint != '' and @type != 'boolean' and @type != 'boolean_num'" >
	    <xsl:attribute name="multipleValues">1</xsl:attribute>
        </xsl:when>
	<xsl:otherwise>
	   <xsl:attribute name="multipleValues"></xsl:attribute>
        </xsl:otherwise>
    </xsl:choose>	

    <!-- create the graph attribute  -->
    <xsl:attribute name="graph"></xsl:attribute>

    <!-- create the style attribute for displayType list filters -->
    <xsl:choose>
        <xsl:when test="@type='boolean' or @type = 'boolean_num'" >
	    <xsl:attribute name="style">radio</xsl:attribute>
        </xsl:when>
	<xsl:otherwise>
	   <xsl:attribute name="style"></xsl:attribute>
        </xsl:otherwise>
    </xsl:choose>

    <!-- create the autoCompletion attribute  -->
    <xsl:attribute name="autoCompletion"></xsl:attribute>

    <!-- add value options for boolean filters for display purposes  -->
    <xsl:if test="count(.//Option) = 0 and (@type = 'boolean' or @type = 'boolean_num')" >
            <xsl:element name="Option">
		<xsl:attribute name="internalName">only</xsl:attribute>
                <xsl:attribute name="displayName">Only</xsl:attribute>
                <xsl:attribute name="value">only</xsl:attribute>
	    </xsl:element>
            <xsl:element name="Option">
		<xsl:attribute name="internalName">excluded</xsl:attribute>
                <xsl:attribute name="displayName">Excluded</xsl:attribute>
                <xsl:attribute name="value">excluded</xsl:attribute>
	    </xsl:element>
    </xsl:if>
    <!-- call other templates eg identity copy on all the child elements -->
    <xsl:apply-templates select="node()"/>
  </xsl:copy>
</xsl:template>










	
<!-- identity copy template - copies all attributes and child elements recursively -->
<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>