package HTML::Parse;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(parse parsefile);

require HTML::Element;

# title base link meta isindex => header
# Plain text => p if body
# Plain text => body p if title or html

# Elements that does not have corresponding end tags
for (qw(title base link meta isindex
	h1 h2 h3 h4 h5 h6
	img br nobr wbr hr
	)
    ) {
    $noEndTag{$_} = 1;
}

%entities = (

 'lt'     => '<',
 'gt'     => '>',
 'amp'    => '&',
 'nbsp'   => "\240",

 'Aacute' => '�',
 'Acirc'  => '�',
 'Agrave' => '�',
 'Aring'  => '�',
 'Atilde' => '�',
 'Auml'   => '�',
 'Ccedil' => '�',
 'ETH'    => '�',
 'Eacute' => '�',
 'Ecirc'  => '�',
 'Egrave' => '�',
 'Euml'   => '�',
 'Iacute' => '�',
 'Icirc'  => '�',
 'Igrave' => '�',
 'Iuml'   => '�',
 'Ntilde' => '�',
 'AElig'  => '�',
 'Oacute' => '�',
 'Ocirc'  => '�',
 'Ograve' => '�',
 'Oslash' => '�',
 'Otilde' => '�',
 'Ouml'   => '�',
 'THORN'  => '�',
 'Uacute' => '�',
 'Ucirc'  => '�',
 'Ugrave' => '�',
 'Uuml'   => '�',
 'Yacute' => '�',
 'aelig'  => '�',
 'aacute' => '�',
 'acirc'  => '�',
 'agrave' => '�',
 'aring'  => '�',
 'atilde' => '�',
 'auml'   => '�',
 'ccedil' => '�',
 'eacute' => '�',
 'ecirc'  => '�',
 'egrave' => '�',
 'eth'    => '�',
 'euml'   => '�',
 'iacute' => '�',
 'icirc'  => '�',
 'igrave' => '�',
 'iuml'   => '�',
 'ntilde' => '�',
 'oacute' => '�',
 'ocirc'  => '�',
 'ograve' => '�',
 'oslash' => '�',
 'otilde' => '�',
 'ouml'   => '�',
 'szlig'  => '�',
 'thorn'  => '�',
 'uacute' => '�',
 'ucirc'  => '�',
 'ugrave' => '�',
 'uuml'   => '�',
 'yacute' => '�',
 'yuml'   => '�',

);


sub parse
{
    my $html = $_[1];
    $html = new HTML::Element 'html' unless defined $html;
    my $buf = \ $html->{'_buf'};
    $$buf .= $_[0];

    # Handle comments
    if ($html->{_comment}) {
	if ($$buf =~ s/.*-->//s) {        # end of comment
	    delete $html->{_comment};
	} else {
	    $$buf = '';          # still inside comment
	}
    }
    $$buf =~ s/<!--.*?-->//s;    # remove complete comments
    if ($$buf =~ s/<!--.*//s) {  # check for start of comment
	$html->{_comment} = 1;
    }
    return $html unless length $$buf;
    
    my @x = split(/(<[^>]+>)/, $$buf);
    if ($x[-1] =~ s/(<.*)//s) {
	$$buf = $1;
	pop(@x) unless length $x[-1];
    } else {
	$$buf = '';
    }
    for (@x) {
	if (m:^</:) {
	    endtag($html, $_);
	} elsif (m/^</) {
	    starttag($html, $_);
	} else {
	    text($html, $_);
	}
    }
    $html;
}

sub starttag
{
    my $html = shift;
    my $elem = shift;
    
    $elem =~ s/^<(\w+)\s*//;
    my $tag = $1;
    $elem =~ s/>$//;
    unless (defined $tag) {
	warn "Illegal start tag $_[0]";
    } else {
	print "START: $tag\n";
	my %attr;
	while ($elem =~ s/^([^\s=]+)\s*(=\s*)?//) {
	    $key = $1;
	    if (defined $2) {
		# read value
		if ($elem =~ s/^"([^"]+)"?\s*//) {
                   $val = $1;
		} elsif ($elem =~ s/^(\S*)\s*//) {
                   $val = $1;
                } else {
                   die "This should not happen";
                }
	    } else {
		# boolean attribute
		$val = 1;
	    }
	    $attr{$key} = $val;
	    print "$tag $key = '$val'\n";
	}
	my $e = new HTML::Element $tag, %attr;
	my $p = $html->pos;
	$e->parent($p);
	$p->pushContent($e);
	$html->pos($e) unless $noEndTag{$tag};
    }
}

sub endtag
{
    my $html = shift;
    my($tag) = $_[0] =~ m:^</(\w+)>$:;
    unless (defined $tag) {
	warn "Illegal end tag $_[0]";
    } else {
	print "END: $tag\n";
	my $p = $html->pos;
	while (defined $p and $p->tag ne $tag) {
	    $p = $p->parent;
	}
	$html->pos($p->parent) if defined $p;
    }
}

sub text
{
    my $html = shift;
    return if $_[0] =~ /^\s*$/;   # ignore empty string

    my $text = shift;
    $text =~ s/\s+/ /g;           # canonical space

    # Expand entities
    $text =~ s/&#(\d+);/chr($1)/eg;
    $text =~ s/&(\w+);/$entities{$1}/g;

    #print "TEXT: $text\n";
    $html->pos->pushContent($text);
}



sub parsefile
{
    my $file = shift;
    open(F, $file) or return undef;
    my $html = undef;
    while(<F>) {
	$html = parse($_, $html);
    }
    close(F);
    $html;
}

1;
