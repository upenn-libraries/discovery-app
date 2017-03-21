<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:marc="http://www.loc.gov/MARC21/slim"
                version="2.0">
    <!--
        Note that the marc-ruby gem can actually extract marc directly from OAI.
        Marc4J won't find the records though.
    -->
    <xsl:template match="/">
        <marc:collection>
            <xsl:apply-templates select="*//marc:record"/>
        </marc:collection>
    </xsl:template>
 
    <!-- this assumes marc:record lives directly under oai:metadata, and is the only element. -->
	<xsl:template match="marc:record">
        <xsl:copy-of select="."/>
    </xsl:template>

</xsl:stylesheet>
