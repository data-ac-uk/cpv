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

$schemes->{CPV2008}->{name} = "CPV 2008";
$schemes->{CPV2008}->{code} = "CPV2008";
open( $fh, "data/sections.txt" ) || die;
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

open( $fh, "-|:utf8", "xsltproc xml2table.xsl data/cpv_2008.xml" ) || die;
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

open( $fh, "-|:utf8", "xsltproc xml2table.xsl data/code_cpv_suppl_2008.xml" ) || die;
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

open( $fh, ">:utf8", "output/redirects.htaccess" ) || die;
my $URL_Base_Path = "/~cjg/cpv/RDF/output";
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

open( $fh, ">:utf8", "output/lookup-en.txt" ) || die;
foreach my $basecode ( keys %$codes )
{
	my $record = $codes->{$basecode};
	print $fh ($record->{names}->{EN})."\t$basecode\t".(defined $record->{type}?$record->{type}:"")."\n";
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
output( "schema", @ns );

# create individual records and complete dump
my @dump = ();
foreach my $basecode ( keys %$codes )
{
	my $record = $codes->{$basecode};
	my @data = $record->toTurtle;
	push @dump, @data;
	output( "code-".$basecode, @data );
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
	output( "scheme-".$scheme_code, @data );
}

output( "dump", @dump );

exit;

##############################

sub output
{
	my( $code, @data ) = @_;

	my $tmpfile = "output/$code.tmp.ttl";

	my $fh;
	open( $fh, ">:utf8", $tmpfile ) || die;
	print $fh $prefixes;
	print $fh join( "\n", @data );
	close $fh;

	my $cmd = "rapper -q -i turtle $tmpfile | sort -u | rapper -q -i ntriples -I http://purl.org/cpv/2008/ - -o turtle > output/$code.ttl";
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

sub CPV::Scheme::toTurtle
{
	my( $scheme ) = @_;

	my @data = ();

	push @data, "cpv:scheme-".$scheme->{code}." rdfs:label \"".turtleEscape($scheme->{name})."\"\@en .";
	push @data, "cpv:scheme-".$scheme->{code}." a skos:ConceptScheme .";

	return @data;
}

sub turtleEscape
{
	my( $string ) = @_;

	$string =~ s/\\/\\\\/g;
	$string =~ s/"/\\"/g;

	return $string;
}
