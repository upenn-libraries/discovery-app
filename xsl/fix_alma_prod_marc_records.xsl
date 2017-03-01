<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <!-- This stylesheet is for fixing some of the egregiously bad data in the Alma test sandbox
         that was making our code choke.
    -->
    <xsl:param name="uri">http://www.loc.gov/MARC21/slim</xsl:param>
    <xsl:template match="*">
        <xsl:choose>
            <!-- filter out datafields where tag="" -->
            <xsl:when test="(local-name() = 'datafield') and (@tag = '')">
                <xsl:comment>removed datafield with blank string for tag attribute</xsl:comment>
            </xsl:when>
            <!-- add namespace -->
            <xsl:otherwise>
                <xsl:element name="{local-name()}" namespace="{ $uri }" >
                    <xsl:copy-of select="attribute::*"/>
                    <xsl:apply-templates />
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose> 
    </xsl:template>
</xsl:stylesheet>
