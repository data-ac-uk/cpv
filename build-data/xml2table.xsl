<?xml version="1.0" encoding='utf-8'?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"

  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:void="http://rdfs.org/ns/void#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:owl="http://www.w3.org/2002/07/owl#"

>

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" omit-xml-declaration="yes" />

<xsl:variable name="url">http://simap.europa.eu/news/new-cpv/cpv_2008_rdf.rdf</xsl:variable>

<xsl:template match="/CPV_CODE|/CPV_SUPPLEMENT">
<xsl:for-each select="CPV|SUPPL"><xsl:value-of select="@CODE" /><xsl:for-each select="TEXT">|<xsl:value-of select="@LANG" />|<xsl:value-of select="." /></xsl:for-each>
<xsl:text>
</xsl:text>
</xsl:for-each>
</xsl:template>

</xsl:stylesheet>
