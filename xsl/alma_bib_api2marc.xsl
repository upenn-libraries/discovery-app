<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
                xmlns:marc="http://www.loc.gov/MARC21/slim" >

    <!-- convert the XML response from the Alma Bibs API to MARC XML -->
    
    <xsl:template match="/">
        <xsl:apply-templates select="bibs/bib/record"/>
    </xsl:template>
 
	<xsl:template match="record">
        <marc:collection>
            <xsl:copy-of select="."/>
        </marc:collection>
    </xsl:template>
    
</xsl:stylesheet>
