require 5.004;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	   => 'HTML-Tree',
    'VERSION'      => '0.53',
    'PREREQ_PM'    => {	
	                 'HTML::Parser' => 2.19,
		         'Font::AFM'    => 1.17,
		      },
    dist           => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
