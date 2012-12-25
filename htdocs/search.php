<?php

if( trim($_POST["term"])== "" )
{
	print "<p>No matches</p>";
	exit;
}

$lines = file( "lookup-en.txt" );

$terms = preg_split( '/\s+/', $_POST["term"] );
$results = array();
foreach( $lines as $line )
{
	$line = chop( $line );
	list( $name,$code,$type) = preg_split( '/\t/', $line );
	
	foreach( $terms as $term )
	{
		if( !preg_match( '/\b'.$term.'/i', $name ) ) { continue 2; }
	}
	$results []= "<tr><td><a href='/code-$code.html'>$code</a></td><td>$name</td><td>($type)</td></tr>";
}
if( sizeof( $results ) )
{
	print "<table>".join( "", $results  )."</table>";
}
else
{
	print "<p>No matches</p>";
}
