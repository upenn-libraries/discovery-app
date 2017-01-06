<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:param name="uri">http://www.loc.gov/MARC21/slim</xsl:param>
    <xsl:template match="*">
        <xsl:choose>
            <!-- replace bad char in leader -->
            <xsl:when test="(local-name() = 'leader') and (contains(string(.), '&#xFFFD;'))">
                <xsl:comment>bad character in leader replace with 'n'</xsl:comment>
                <xsl:element name="{local-name()}" namespace="{ $uri }" >
                    <xsl:copy-of select="attribute::*"/>
                    <xsl:value-of select="translate(string(.), '&#xFFFD;','n')"/>
                </xsl:element>
            </xsl:when>
            <!-- filter out illegal controlfields -->
            <xsl:when test="(local-name() = 'controlfield') and ((@tag != '000') and (@tag != '001') and (@tag != '002') and (@tag != '003') and (@tag != '004') and (@tag != '005') and (@tag != '006') and (@tag != '007') and (@tag != '008') and (@tag != '009'))">
                <xsl:comment>removed controlfield with bad code</xsl:comment>
            </xsl:when>
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
