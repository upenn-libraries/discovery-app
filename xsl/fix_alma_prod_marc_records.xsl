<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <!-- This stylesheet is for fixing bad data in the Alma prod environment
         that was making some code (in particular, the marc-ruby gem) choke.
    -->
    <xsl:param name="uri">http://www.loc.gov/MARC21/slim</xsl:param>
    <xsl:template match="*">
        <xsl:choose>
            <!-- filter out datafields where tag="" -->
            <xsl:when test="(local-name() = 'datafield') and (@tag = '')">
                <xsl:comment>removed datafield with blank string for tag attribute</xsl:comment>
            </xsl:when>
            <!-- filter out controlfields where tag is not numeric (this occurs in some NON_SFX records) -->
            <xsl:when test="(local-name() = 'controlfield') and (not(matches(@tag, '[0-9][0-9][0-9]')))">
                <xsl:comment>removed controlfield with non-numeric string for tag attribute</xsl:comment>
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
