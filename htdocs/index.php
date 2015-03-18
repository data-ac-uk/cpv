<?php
date_default_timezone_set( "Europe/London" );
try {
    $f3=require('lib/base.php');
} catch (Exception $e) {
    echo 'Caught exception: ',  $e->getMessage(), "\n";
}
#	print $fh "Redirect /code-$basecode /turtle/code-$basecode.ttl\n";
#	print $fh "Redirect /code-$code /turtle/code-$basecode.ttl\n";
#	print $fh "Redirect /scheme-$scheme_code /turtle/scheme-$scheme_code.ttl\n";

#if ((float)strstr(PCRE_VERSION,' ',TRUE)<7.9)
#	trigger_error('Outdated PCRE library version');

# This site uses a file for the titles of pages in the template

if (function_exists('apache_get_modules') &&
	!in_array('mod_rewrite',apache_get_modules()))
	trigger_error('Apache rewrite_module is disabled');

$f3->set('DEBUG',2);
$f3->set('UI','ui/');
$f3->route('GET /',

	function() {
		$f3=Base::instance();

		$f3->set('title', 'homepage.title' );
		$f3->set('content','homepage.html');
		print Template::instance()->render( "page-template.html" );
	}
);
$f3->route('GET /@path' , 
	function() use($f3) {
		$path = $f3->get('PARAMS.path');
		if( preg_match( "/\.html$/", $path ) )
		{
			$path = preg_replace( '/\.html$/','',$path );
			$f3->set('title', "var/$path.title" );
			$f3->set('content',"var/$path.html");
			print Template::instance()->render( "page-template.html" );
			return;
		}
		elseif( preg_match( "/^(code|scheme)-[A-Z0-9]+$/", $path ) )
		{
			$wants = wants($f3); // do they like ttl or html?
			if( $wants == "ttl" )
			{
				header( "Location: http://cpv.data.ac.uk/turtle/$path.ttl" );
			}
			else	
			{
				header( "Location: http://cpv.data.ac.uk/$path.html" );
			}
		}
		else
		{
			$f3->error(404);
		}
		
	});
$f3->route('GET /ns/*', 
	function() {
		header( "Location: http://cpv.data.ac.uk/turtle/schema.ttl" );
		exit;
	} );
$f3->run();

exit;

function wants($f3)
{
	$req = $f3->get('SERVER');

	$views = array(
		array(
			"mimetypes"=>array( "text/html" ),
			"ext"=>"html" ),
		array(
			"mimetypes"=>array( "text/turtle", "application/x-turtle" ),
			"ext"=>"ttl" ),
	);
       
	$ext = "html";
	if( isset( $req["HTTP_ACCEPT"] ) )
	{      
		$opts = preg_split( "/,/", $req["HTTP_ACCEPT"] );
		$o = array( "text/html"=>0.1 , "text/turtle"=>0 );
		foreach( $opts as $opt)
		{      
			$opt = trim( $opt );
			$optparts = preg_split( "/;/", $opt );
			$mime = array_shift( $optparts );
			$o[$mime] = 1;
			foreach( $optparts as $optpart )
			{      
				$optpart = trim( $optpart );
				list( $k,$v ) = preg_split( "/=/", $optpart );
				$k = trim( $k );
				$v = trim( $v );
				if( $k == "q" ) { $o[$mime] = $v; }
			}
		}
	       
		$score = 0.1;
		foreach( $views as $view )
		{      
			foreach( $view['mimetypes'] as $mimetype )
			{      
				if( @$o[$mimetype] > $score )
				{      
					$score=$o[$mimetype];
					$ext = $view["ext"];
				}
			}
		}
	}
	return $ext;
}
