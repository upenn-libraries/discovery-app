<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.loc.gov/MARC21/slim"
                xmlns:marc="http://www.loc.gov/MARC21/slim"
                version="2.0">

    <!-- Do transformations on data from Alma production
         environment. This fixes 'bad' data (invalid MARC that makes
         the marc-ruby gem choke) and merges holdings from boundwith
         records into normal bib records where needed.
    -->

    <!--
    <xsl:param name="bound_with_dir" required="yes"/>

    <xsl:variable name="bound_with_docs" select="collection(concat('file:', $bound_with_dir, '?select=boundwiths_*.xml'))"/>
    -->
    
    <xsl:template match="/">
        <collection>
            <xsl:apply-templates select="marc:collection/marc:record"/>
        </collection>
    </xsl:template>

    <xsl:template match="marc:record">
        <record>
            <xsl:for-each select="./*">
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
            </xsl:for-each>

            <!-- copy in the holdings datafields from boundwith xml files -->
            <!-- OBSOLETE: this is too slow -->
            <!--
            <xsl:for-each select="./marc:controlfield[@tag='001']">
                <xsl:variable name="id" select="./text()"/>
	            <xsl:variable name="bound_with_match" select="$bound_with_docs/bound_withs/record[id[text() = $id]]"/>
                <xsl:if test="count($bound_with_match) > 0">
	                <xsl:variable name="bound_with_id" select="$bound_with_match/id/text()"/>
                    <xsl:comment>Holdings copied from boundwith record=<xsl:value-of select="$bound_with_id"/></xsl:comment>
                    <xsl:copy-of select="$bound_with_match/holdings/*"/>
                </xsl:if>
                </xsl:for-each>
            -->
        </record>
    </xsl:template>
    
</xsl:stylesheet>
