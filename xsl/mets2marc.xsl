<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
	            xmlns:mets="http://www.loc.gov/METS/"
                xmlns:marc="http://www.loc.gov/MARC21/slim" >

    <!-- Convert METS records, which is how ExLibris stores extracted
         data from Voyager in the 'voyagerdb_extract' directory, to
         MARC XML.
    -->
    
    <xsl:template match="/">
        <xsl:apply-templates select="mets:mets/mets:dmdSec/mets:mdWrap/mets:xmlData/marc:record"/>
    </xsl:template>
 
	<xsl:template match="marc:record">
        <marc:collection>
            <xsl:copy-of select="."/>
        </marc:collection>
    </xsl:template>

</xsl:stylesheet>
