#!/usr/bin/perl 
use strict;
use warnings;
use FindBin;
use Data::Dumper;

chdir($FindBin::Bin);
binmode( STDOUT, ":utf8" );

# this script processes the CPV data into RDF documents

# outputs: 
## one big file
## one file per scheme
## one file per item
## a redirect list for the checksum varients
## an english lookup table for quick searches
## the concepts in the namespace

my $codes = {};
my $schemes = {};

my $fh;
open( $fh, "template.html" ) || die;
my $HTML_TEMPLATE = join( "",<$fh> );
close $fh;

$schemes->{CPV2008}->{name} = "CPV 2008";
$schemes->{CPV2008}->{code} = "CPV2008";
open( $fh, "sections.txt" ) || die;
my $levl1 = "";
while( my $line = readline( $fh ) )
{
	chomp $line;
	my( $code, $label ) = split( /: /, $line );

	if( length( $code ) == 1 )
	{
		$levl1 = "Section A: $label";
		$schemes->{$code}->{name} = "CPV 2008 Supplementary vocabulary: $levl1";
		$schemes->{$code}->{code} = $code;
	}
	
	if( length( $code ) == 2 )
	{
		$schemes->{$code}->{name} = "CPV 2008 Supplementary vocabulary: $levl1, Group ".substr( $code,1,1).": $label";
		$schemes->{$code}->{code} = $code;
	}
}	
close $fh;
foreach my $scheme ( values %{$schemes} )
{
	bless $scheme, "CPV::Scheme";
}

open( $fh, "-|:utf8", "xsltproc xml2table.xsl cpv_2008.xml" ) || die;
while( my $line = readline($fh) )
{
	chomp $line;
	next if $line =~ m/^\s*$/;
	my( @row ) = split( /\|/, $line );
	my $code = shift @row;
	my $basecode = $code;
	$basecode=~s/-\d$//; # lost the checksum

	my $scheme = "CPV2008";

	my %names = @row;
	my $record = { basecode=>$basecode, code=>$code, names=>\%names, scheme=>[$scheme] };
	bless $record, "CPV::Code";

	if( substr( $basecode, 2,6) eq "000000" )
	{
		# top level code
		$record->{type} = "division";
	}
	elsif( substr( $basecode, 3,5 ) eq "00000" )
	{
		$record->{type} = "group";
		$record->{parent} = substr( $basecode,0,2 )."000000";
	}
	elsif( substr( $basecode, 4,4 ) eq "0000" )
	{
		$record->{type} = "class";
		$record->{parent} = substr( $basecode,0,3 )."00000";
	}
	elsif( substr( $basecode, 5,3 ) eq "000" )
	{
		$record->{type} = "category";
		$record->{parent} = substr( $basecode,0,4 )."0000";
	}
	elsif( substr( $basecode, 6,2 ) eq "00" )
	{
		$record->{type} = "subcategory";
		$record->{parent} = substr( $basecode,0,5 )."000";
	}
	elsif( substr( $basecode, 7,1 ) eq "0" )
	{
		$record->{type} = "subcategory";
		$record->{parent} = substr( $basecode,0,6 )."00";
	}
	else
	{
		$record->{type} = "subcategory";
		$record->{parent} = substr( $basecode,0,7 )."0";
	}

	$codes->{$basecode} = $record;
	$schemes->{$scheme}->{items}->{$basecode} = $record;
}
close $fh;
foreach my $code ( keys %$codes )
{
	my $record = $codes->{$code};
 	next if( !defined $record->{parent} );

	# if this doesn't have an immediate parent go up levels until it does
	while( !defined $codes->{$record->{parent}} )
	{
		$record->{parent} =~ s/[^0](0*)$/0$1/;
	}
	$codes->{$record->{parent}}->{children}->{$code} = $code;
}

open( $fh, "-|:utf8", "xsltproc xml2table.xsl code_cpv_suppl_2008.xml" ) || die;
while( my $line = readline($fh) )
{
	next if $line =~ m/^\s*$/;

	chomp $line;
	my( @row ) = split( /\|/, $line );
	my $code = shift @row;
	my $basecode = $code;
	$basecode=~s/-\d$//; # lost the checksum

	my $scheme1 = substr( $code,0,1);
	my $scheme2 = substr( $code,0,2);

	my %names = @row;
	my $record = {  basecode=>$basecode,code=>$code, names=>\%names, scheme=>[$scheme1,$scheme2] };
	bless $record, "CPV::Code";

	$codes->{$basecode} = $record;
	$schemes->{$scheme1}->{items}->{$basecode} = $record;
	$schemes->{$scheme2}->{items}->{$basecode} = $record;
}
close $fh;

###################################
# OUTPUT
###################################

my @classes = qw/ Division Group Class Category Subcategory /;

# Output Redirect map

open( $fh, ">:utf8", "../htdocs/redirects.htaccess" ) || die;
my $URL_Base_Path = "/";
foreach my $class ( @classes )
{
	print $fh "Redirect $URL_Base_Path/$class $URL_Base_Path/schema.ttl\n";
}
foreach my $basecode ( keys %$codes )
{
	my $record = $codes->{$basecode};
	my $code = $record->{code};
	print $fh "Redirect $URL_Base_Path/code-$basecode $URL_Base_Path/code-$basecode.ttl\n";
	print $fh "Redirect $URL_Base_Path/code-$code $URL_Base_Path/code-$basecode.ttl\n";
}
foreach my $scheme_code ( keys %$schemes )
{
	print $fh "Redirect $URL_Base_Path/scheme-$scheme_code $URL_Base_Path/scheme-$scheme_code.ttl\n";
}
close $fh;

# Output URI lookup table (English)

open( $fh, ">:utf8", "../htdocs/lookup-en.txt" ) || die;
foreach my $basecode ( keys %$codes )
{
	my $record = $codes->{$basecode};
	print $fh "".($record->{names}->{EN})."\t$basecode\t".(defined $record->{type}?$record->{type}:"")."\n";
}
close $fh;




# Output RDF TTL Files:

my $prefixes = "
\@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
\@prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
\@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
\@prefix void: <http://rdfs.org/ns/void#> .
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
\@prefix owl:  <http://www.w3.org/2002/07/owl#> .
\@prefix cpv:  <http://purl.org/cpv/2008/> .
";

my @ns = ();
foreach my $class ( @classes )
{
	push @ns, "cpv:$class a rdfs:Class .";
	push @ns, "cpv:$class rdfs:label \"CPV2008 $class\"\@en .";
	push @ns, "cpv:$class rdfs:comment \"The CPV concept scheme is divided by Division then Group then Class then Category then 3 levels of Subcategory.\"\@en .";
}
outputTTL( "schema", @ns );

# create individual records and complete dump
my @dump = ();
foreach my $basecode ( keys %$codes )
{
	my $record = $codes->{$basecode};
	my @data = $record->toTurtle;
	push @dump, @data;
	outputTTL( "code-".$basecode, @data );

	my $html = $record->toHTML;
	outputHTML( "code-".$basecode, $html );
}

# create scheme records
foreach my $scheme_code ( keys %$schemes )
{
	my $scheme = $schemes->{$scheme_code};
	my @data = ();
	push @data, $scheme->toTurtle;
	foreach my $item ( values %{$scheme->{items}} )
	{
		push @data, $item->toTurtle;
	}
	outputTTL( "scheme-".$scheme_code, @data );

	my $page = $scheme->toHTML;
	outputHTML( "scheme-".$scheme_code, $page );

	my $tsv = $scheme->toTSV;
	outputTSV( "scheme-".$scheme_code, $tsv );
}
	
outputTTL( "dump", @dump );

exit;

##############################

sub outputTSV
{
	my( $code, $tsv ) = @_;

	my $file = "../htdocs/tsv/$code.tsv";

	my $fh;
	open( $fh, ">:utf8", $file ) || die;
	foreach my $row ( @{ $tsv } )
	{
		print $fh join( "\t", @$row )."\n";
	}
	close $fh;
}

##############################

sub outputHTML
{
	my( $code, $page ) = @_;

	my $file = "../htdocs/$code.html";

	my $document = $HTML_TEMPLATE;
	$document =~ s/\$CONTENT/$page->{content}/g;
	$document =~ s/\$TITLE/$page->{title}/g;

	my $fh;
	open( $fh, ">:utf8", $file ) || die;
	print $fh $document;
	close $fh;
}

##############################

sub outputTTL
{
	my( $code, @data ) = @_;

	my $tmpfile = "../htdocs/turtle/$code.tmp.ttl";
	my $file = "../htdocs/turtle/$code.ttl";

	my $fh;
	open( $fh, ">:utf8", $tmpfile ) || die;
	print $fh $prefixes;
	print $fh join( "\n", @data );
	close $fh;

	my $features = " -f 'xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"' -f 'xmlns:skos=\"http://www.w3.org/2004/02/skos/core#\"' -f 'xmlns:owl=\"http://www.w3.org/2002/07/owl#\"' ";

	my $cmd = "rapper -q -i turtle $tmpfile | sort -u | rapper -q -i ntriples -I http://purl.org/cpv/2008/ $features - -o turtle > $file";
	`$cmd`;
	unlink( $tmpfile );
}

##############################

sub CPV::Code::toTurtle
{
	my( $record ) = @_;

	my $basecode = $record->{basecode};

	my @data;
	push @data, "cpv:code-$basecode a skos:Concept .";
	if( defined $record->{type} ) { push @data, "cpv:code-$basecode a cpv:".ucfirst( $record->{type} )." ."; }

	if( defined $record->{children} ) 
	{
		foreach my $child_code ( values %{$record->{children}} )
		{
			 push @data, "cpv:code-$basecode skos:narrower cpv:code-".$codes->{$child_code}->{basecode}." .";
		}
	}
	if( defined $record->{parent} ) 
	{
		my $parent_record = $codes->{ $record->{parent} };
		if( !defined $parent_record ) { die; }
		if( !defined $parent_record->{basecode} ) { print STDERR Dumper( $parent_record); die; }
		push @data, "cpv:code-$basecode skos:broader cpv:code-".$parent_record->{basecode}." .";
	}
	push @data, "cpv:code-$basecode owl:sameAs cpv:code-".$record->{code}." .";
	foreach my $scheme ( @{$record->{scheme}} )
	{
		push @data, "cpv:code-$basecode skos:inScheme cpv:scheme-$scheme .";
		push @data, $schemes->{$scheme}->toTurtle;
	}
	foreach my $lang ( keys %{$record->{names}} )
	{
		push @data, "cpv:code-$basecode rdfs:label \"".turtleEscape($record->{names}->{$lang})."\"\@\L$lang .";
	}
	return @data;
}
sub CPV::Code::uri
{
	my( $record ) = @_;

	return "http://purl.org/cpv/2008/code-".$record->{basecode};
}
sub CPV::Code::toHTML
{
	my( $record ) = @_;

	my $page = {};
	$page->{title} = $record->{names}->{EN};
	$page->{content} .= "";
	$page->{content} .= "<div class='metadata'><strong>ID:</strong> ".$record->{basecode}."</div>";
	$page->{content} .= "<div class='metadata'><strong>ID with checksum:</strong> ".$record->{code}."</div>";

	$page->{content} .= "<div class='metadata'><strong>URI:</strong> ".$record->uri."</div>";
	$page->{content} .= "<div class='download'><strong>Download:</strong> <a href='turtle/code-".$record->{basecode}.".ttl'>RDF in Turtle</a>.</div>";
	my @scheme_links = ();
	foreach my $scheme ( sort @{$record->{scheme}} )
	{
		push @scheme_links, "<a href='scheme-$scheme.html'>".$schemes->{$scheme}->{name}."</a>";
	}
	$page->{content} .= "<div class='metadata'><strong>Scheme:</strong> ".join( ", ", @scheme_links )."</div>";
	if( defined $record->{parent} || defined $record->{children} )
	{
		my $tree = "<strong>".$record->{basecode}." - ".$record->{names}->{EN}."</strong>";
		if( defined $record->{children} )
		{
			$tree.= "<ul>";
			foreach my $child_code ( values %{$record->{children}} )
			{
				my $child = $codes->{$child_code};
				$tree .= "<li><a href='code-".$child->{basecode}.".html'>".$child->{code}." - ".$child->{names}->{EN}."</a></li>";
			}
			$tree.= "</ul>";
		}
		my $current = $record;
		while( defined $current->{parent} )
		{
			$current = $codes->{ $current->{parent} };
			$tree = "<a href='code-".$current->{basecode}.".html'>".$current->{code}." - ".$current->{names}->{EN}."</a><ul><li>$tree</li></ul>";
		}
		
		$page->{content}.= "<h2>Location in the scheme</h2>";
		$page->{content}.= "<ul><li>$tree</li></ul>";
	}
	$page->{content}.= "<h2>Translations</h2>";
	$page->{content}.= "<table class='translations'>";
	foreach my $lang_id ( sort keys %{ $record->{names} } )
	{
		$page->{content}.= "<tr><td>$lang_id</td><td>".$record->{names}->{$lang_id}."</td></tr>";
	}
	$page->{content}.= "</table>";
	return $page;
}

sub CPV::Scheme::toTurtle
{
	my( $scheme ) = @_;

	my @data = ();

	push @data, "cpv:scheme-".$scheme->{code}." rdfs:label \"".turtleEscape($scheme->{name})."\"\@en .";
	push @data, "cpv:scheme-".$scheme->{code}." a skos:ConceptScheme .";

	return @data;
}
sub CPV::Scheme::uri
{
	my( $scheme ) = @_;

	return "http://purl.org/cpv/2008/scheme-".$scheme->{code};
}
sub CPV::Scheme::toHTML
{
	my( $scheme ) = @_;

	my $page = {};
	$page->{title} = $scheme->{name};
	$page->{content} .= "";
	$page->{content} .= "<div class='metadata'><strong>URI:</strong> ".$scheme->uri."</div>";
	$page->{content} .= "<div class='download'><strong>Download:</strong> <a href='turtle/scheme-".$scheme->{code}.".ttl'>RDF in Turtle</a>, <a href='tsv/scheme-".$scheme->{code}.".tsv'>Tab-Separated Values (these load in Excel and other spreadsheets)</a>.</div>";

	$page->{content} .= "<table class='scheme'>";
	foreach my $code ( sort keys %{$scheme->{items}} )
	{
		my $item = $scheme->{items}->{$code};
		$page->{content} .= "<tr>";
		$page->{content} .= "<td><a href='code-".$item->{basecode}.".html'>".$item->{"code"}."</a></td>";
		$page->{content} .= "<td>".$item->{"names"}->{EN}."</td>";
		$page->{content} .= "</tr>";
	}
	$page->{content} .= "</table>";

	return $page;
}
sub CPV::Scheme::toTSV
{
	my( $scheme ) = @_;

	my $tsv = [ ["code","label" ] ];

	foreach my $code ( sort keys %{$scheme->{items}} )
	{
		my $item = $scheme->{items}->{$code};
		push @$tsv, [ $item->{"code"} , $item->{"names"}->{EN} ];
	}

	return $tsv;
}

sub turtleEscape
{
	my( $string ) = @_;

	$string =~ s/\\/\\\\/g;
	$string =~ s/"/\\"/g;

	return $string;
}
