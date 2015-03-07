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
			header( "Location: http://cpv.data.ac.uk/turtle/$path.ttl" );
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
