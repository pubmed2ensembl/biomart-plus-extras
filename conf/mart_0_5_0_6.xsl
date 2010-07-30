<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- deal with Importable conversion -->
<xsl:template match="Importable">
  <xsl:copy>
    <!-- call other templates eg identity copy on all the attributes-->
    <xsl:apply-templates select="@*"/>

    <xsl:if test="count(@type) = 0 or @type = ''">
    	<xsl:attribute name="type">link</xsl:attribute>
    </xsl:if>

  </xsl:copy>
</xsl:template>

<!-- deal with Exportable conversion -->
<xsl:template match="Exportable">
  <xsl:copy>
    <!-- call other templates eg identity copy on all the attributes-->
    <xsl:apply-templates select="@*"/>

    <xsl:if test="count(@type) = 0 or @type = ''">
    	<xsl:attribute name="type">link</xsl:attribute>
    </xsl:if>

  </xsl:copy>
</xsl:template>


<!-- identity copy template - copies all attributes and child elements recursively -->
<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>