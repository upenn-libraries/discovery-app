<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:marc="http://www.loc.gov/MARC21/slim"
                xmlns:oai="http://www.openarchives.org/OAI/2.0/" 
                exclude-result-prefixes="oai"
                version="2.0">

    <!--
        Note that the marc-ruby gem can actually extract marc directly from OAI.
        Marc4J won't find the records though.
    -->
    <xsl:template match="/">
        <marc:collection xmlns="http://www.loc.gov/MARC21/slim">
            <xsl:apply-templates select="*//marc:record"/>
        </marc:collection>
    </xsl:template>
 
	<xsl:template match="marc:record">
        <!-- copy ID from the OAI envelope into an 035a marc field. we do this because traject only processes marc. -->
        <xsl:variable name="oai-id" select="../../oai:header/oai:identifier/text()"/>
        <marc:record>
            <marc:datafield tag="035" ind1=" " ind2=" ">
                <marc:subfield code="a">(HATHI-OAI)<xsl:value-of select="$oai-id"/></marc:subfield>
            </marc:datafield>
            <xsl:copy-of select="./*"/>
        </marc:record>
    </xsl:template>

</xsl:stylesheet>
