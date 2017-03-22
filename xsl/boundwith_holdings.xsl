<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:marc="http://www.loc.gov/MARC21/slim"
                version="2.0">
    <!-- Extract all the 'boundwith' records into separte document, to be used for merging later on -->

    <xsl:template match="/">
        <bound_withs>
            <xsl:apply-templates select="*//marc:record"/>
            <xsl:apply-templates select="*//record"/>
        </bound_withs>
    </xsl:template>

    <!-- we match on local-name() so this works for both namespaced and non-namespaced elements -->

    <xsl:template match="marc:record | record">
		<xsl:variable name="record" select="."/>
        
        <xsl:if test="matches(./*[local-name()='datafield' and @tag='245'][1]/*[local-name()='subfield' and @code='a'][1]/text(), 'Host bibliographic record for boundwith')">

		    <xsl:variable name="boundwith_id" select="./*[local-name()='controlfield' and @tag='001'][1]/text()"/>

            <xsl:for-each select="./*[local-name()='datafield' and @tag='774']">
                <xsl:for-each select="./*[local-name()='subfield' and @code='w']">
                    <record>
                        <id><xsl:copy-of select="./text()"/></id>
                        <boundwith_id><xsl:value-of select="$boundwith_id"/></boundwith_id>
                        <xsl:comment><xsl:value-of select="base-uri()"/></xsl:comment>
                        <holdings>
                            <xsl:copy-of select="$record/*[local-name()='datafield' and (@tag='hld' or @tag='itm' or @tag='prt' or @tag='dig')]"/>
                        </holdings>
                    </record>
                </xsl:for-each>
            </xsl:for-each>
        </xsl:if>

    </xsl:template>

</xsl:stylesheet>
