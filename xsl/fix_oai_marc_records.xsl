<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <!--
        This stylesheet is for fixing bad MARC XML in the OAI feed
    -->
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
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
