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
<!--
 To apply this stylesheet, use the following command on Linux or OSX.

 xsltproc cpv2rdf.xsl cpv_2008.xml > cpv_2008_rdf.rdf

 XSLT by Christopher Gutteridge, University of Southampton, cjg@ecs.soton.ac.uk
 This XSLT document is placed in the public domain.
-->

<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" omit-xml-declaration="no" />

<xsl:variable name="url">http://simap.europa.eu/news/new-cpv/cpv_2008_rdf.rdf</xsl:variable>

<xsl:template match="/CPV_CODE">
  <rdf:RDF>
    <void:Dataset rdf:about="{$url}">
      <rdfs:label>CPV 2008 RDF Description</rdfs:label>
      <rdfs:comment>Generated from the XML by an XSLT transform by Christopher Gutteridge at the University of Southampton, UK. cjg@ecs.soton.ac.uk</rdfs:comment>
      <foaf:primaryTopic rdf:resource="{$url}#cpv2008" />
    </void:Dataset>
    <skos:ConceptScheme rdf:about="{$url}#cpv2008">
      <rdfs:label>CPV 2008</rdfs:label>
      <foaf:page rdf:resource="http://simap.europa.eu/codes-and-nomenclatures/codes-cpv/codes-cpv_en.htm" />
    </skos:ConceptScheme>
 <xsl:text>

</xsl:text>
    <xsl:apply-templates match="CPV" />
  </rdf:RDF>
</xsl:template>

<xsl:template match="CPV">
 <skos:Concept rdf:about="{$url}#code-{substring(@CODE,1,8)}" />
   <owl:sameAs rdf:resource="{$url}#code-{@CODE}" />
 </skos:Concept>
 <skos:Concept rdf:about="{$url}#code-{@CODE}">
   <skos:inScheme rdf:resource="{$url}#cpv2008" />
   <xsl:choose>
     <xsl:when test="substring(@CODE,3,6) = '000000'">
       <rdf:type rdf:resource="{$url}#Division" />
     </xsl:when>
     <xsl:when test="substring(@CODE,4,5) = '00000'">
       <rdf:type rdf:resource="{$url}#Group" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,2)}000000" />
     </xsl:when>
     <xsl:when test="substring(@CODE,5,4) = '0000'">
       <rdf:type rdf:resource="{$url}#Class" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,2)}000000" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,3)}00000" />
     </xsl:when>
     <xsl:when test="substring(@CODE,6,3) = '000'">
       <rdf:type rdf:resource="{$url}#Category" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,2)}000000" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,3)}00000" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,4)}0000" />
     </xsl:when>
     <xsl:otherwise>
       <rdf:type rdf:resource="{$url}#Subcategory" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,2)}000000" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,3)}00000" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,4)}0000" />
       <skos:broader rdf:resource="{$url}#code-{substring(@CODE,1,5)}000" />
     </xsl:otherwise>
   </xsl:choose>
   <skos:inScheme rdf:resource="{$url}#cpv2008" />
   <xsl:for-each select="TEXT">
     <rdfs:label xml:lang="{translate(@LANG,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')}"><xsl:value-of select="." /></rdfs:label>
   </xsl:for-each>
 </skos:Concept>
 <xsl:text>

</xsl:text>
</xsl:template>

</xsl:stylesheet>

