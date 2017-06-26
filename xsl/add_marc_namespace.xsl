<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <!-- Just add MARC namespace to elements. Alma exports are missing the namespace. -->
    <xsl:param name="uri">http://www.loc.gov/MARC21/slim</xsl:param>
    <xsl:template match="*">
        <xsl:element name="{local-name()}" namespace="{ $uri }" >
            <xsl:copy-of select="attribute::*"/>
            <xsl:apply-templates />
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
