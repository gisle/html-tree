package HTML::Parse;

# $Id$

=head1 NAME

parse - Parse HTML text

parsefile - Parse HTML text from file

=head1 SYNOPSIS

 use HTML::Parse;
 $h = parsefile("test.html");
 print $h->asHTML;
 $h = parse("<p>Some more text", $h);
 $h->delete;

=head1 DESCRIPTION

This module provides functions to parse HTML text.  The result of
parsing text is a HTML syntax tree with HTML::Element objects as
nodes.

You must delete the parse tree explicitly to free the memory
assosiated with it.  The reason for this is that the parse tree
contains circular references (parents have references to their
children and children have a reference to their parent).

The following variables control how parsing takes place:

=over 4

=item $HTML::Parse::IMPLICIT

Setting this variable to true will instruct the parser to try to
deduce implicit elements and implicit end tags.  If this variable is
false you get a parse tree that just reflects the text as it stands.
Might be useful for quick & dirty parsing.  Default is true.

=item $HTML::Parse::IGNORE_UNKNOWN

This variable contols whether unknow tags should be represented as
elements in the parse tree.  Default is true.

=item $HTML::Parse::SPLIT_TEXT

This variable controls whether the text content of elements should be
cut into pieces. Default is false.

=back

=head1 COPYRIGHT

Copyright (c) 1995 Gisle Aas. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Gisle Aas <aas@oslonett.no>

=cut


require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(parse parsefile);

require HTML::Element;

$IMPLICIT = 1;
$SPLIT_TEXT = 0;
$IGNORE_UNKNOWN = 1;

# Elements that should only be present in the header
for (qw(title base link meta isindex nextid)) {
    $isHeadElement{$_} = 1;
}

# Elements that should only be present in the body
for (qw(h1 h2 h3 h4 h5 h6
	p pre address blockquote
	a img br hr
	ol ul dir menu li
	dl dt dd
	cite code em kbd samp strong var
	b i u tt
	table tr td th caption
	form input select option textarea
       )
    ) {
    $isBodyElement{$_} = 1;
}

# Also parse some Netscape extentions elements
for (qw(wbr nobr center blink font basefont)) {
    $isBodyElement{$_} = 1;
}

# Lists
for (qw(ul ol dir menu)) {
    $isList{$_} = 1;
}

# Table elements
for (qw(tr td th caption)) {
    $isTableElement{$_} = 1;
}

# Form element
for (qw(input select option textarea)) {
    $isFormElement{$_} = 1;
}

%entities = (

 'lt'     => '<',
 'gt'     => '>',
 'amp'    => '&',
 'quot'   => '"',
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
	} elsif (m/^<\s*\w+/) {
	    starttag($html, $_);
	} elsif (m/^<!DOCTYPE\b/) {
	    # just ignore it
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
    
    $elem =~ s/^<\s*(\w+)\s*//;
    my $tag = $1;
    $elem =~ s/>$//;
    unless (defined $tag) {
	warn "Illegal start tag $_[0]";
    } else {
	$tag = lc $tag;
	#print "START: $tag\n";
	my %attr;
	while ($elem =~ s/^([^\s=]+)\s*(=\s*)?//) {
	    $key = $1;
	    if (defined $2) {
		# read value
		if ($elem =~ s/^"([^\"]+)"?\s*//) {       # doble quoted val
		    $val = $1;
		} elsif ($elem =~ s/^'([^\']+)'?\s*//) {  # single quoted val
		    $val = $1;
		} elsif ($elem =~ s/^(\S*)\s*//) {        # unquoted val
		    $val = $1;
                } else {
		    die "This should not happen";
                }
		# expand entities
		expandEntities($val);
	    } else {
		# boolean attribute
		$val = $key;
	    }
	    $attr{$key} = $val;
        }

	my $pos  = $html->pos;
	my $ptag = $pos->tag;
	my $e = new HTML::Element $tag, %attr;

        if (!$IMPLICIT) {
	    # do nothing
	} elsif ($tag eq 'html') {
	    if ($ptag eq 'html' && $pos->isEmpty()) {
		# migrate attributes to origial HTML element
		for (keys %attr) {
		    $html->attr($_, $attr{$_});
		}
		return;
	    } else {
		warn "Skipping nested html element\n";
		return;
	    }
	} elsif ($tag eq 'head') {
	    if ($ptag ne 'html' && $pos->isEmpty()) {
		warn "Skipping nested <head> element\n";
		return;
	    }
	} elsif ($tag eq 'body') {
	    if ($pos->isInside('head')) {
		endtag($html, 'head');
	    } elsif ($ptag ne 'html') {
		warn "Skipping nested <body> element\n";
		return;
	    }
	} elsif ($isHeadElement{$tag}) {
	    if ($pos->isInside('body')) {
		warn "Header element <$tag> in body\n";
	    } elsif (!$pos->isInside('head')) {
		$pos = insertTag($html, 'head', 1);
	    }
        } elsif ($isBodyElement{$tag}) {
	    if ($pos->isInside('head')) {
		endtag($html, 'head');
		$pos = insertTag($html, 'body');
		$ptag = $pos->tag;
	    } elsif (!$pos->isInside('body')) {
		$pos = insertTag($html, 'body');
		$ptag = $pos->tag;
	    }

	    # Handle implicit endings and insert based on <tag> and position
	    if ($tag eq 'p' || $tag =~ /^h[1-6]/) {
		# Can't have <p> or <h#> inside these
		for (qw(p h1 h2 h3 h4 h5 h6 pre textarea)) {
		    endtag($html, $_);
		}
	    } elsif ($tag =~ /^[oud]l$/) {
		# Can't have lists inside <h#>
		if ($ptag =~ /^h[1-6]/) {
		    endtag($html, $ptag);
		    $pos = insertTag($html, 'p');
		    $ptag = 'p';
		}
	    } elsif ($tag eq 'li') {
		# Fix <li> outside list
		endtag($html, 'li');
		$ptag = $html->pos->tag;
		$pos = insertTag($html, 'ul') unless $isList{$ptag};
	    } elsif ($tag eq 'dt' || $tag eq 'dd') {
		endtag($html, 'dt');
		endtag($html, 'dd');
		$ptag = $html->pos->tag;
		# Fix <dt> or <dd> outside <dl>
		$pos = insertTag($html, 'dl') unless $ptag eq 'dl';
	    } elsif ($isFormElement{$tag}) {
		return unless $pos->isInside('form');
		if ($tag eq 'option') {
		    endtag($html, 'option');
		    $ptag = $html->pos->tag;
		    $pos = insertTag($html, 'select') unless $ptag eq 'select';
		}
	    }

	} else {
	    # unknown tag
	    if ($IGNORE_UNKNOWN) {
		warn "Skipping $tag\n";
		return;
	    }
	}
	insertTag($html, $e);
    }
}

sub insertTag
{
    my($html, $tag, $implicit) = @_;
    my $e;
    if (ref $tag) {
	$e = $tag;
	$tag = $e->tag;
    } else {
	$e = new HTML::Element $tag;
    }
    $e->implicit(1) if $implicit;
    my $pos = $html->pos;
    $e->parent($pos);
    $pos->pushContent($e);
    $html->pos($e) unless $HTML::Element::noEndTag{$tag};
    $html->pos;
}

sub endtag
{
    my $html = shift;
    my($tag) = $_[0] =~ m|^(?:</)?(\w+)>?$|;
    unless (defined $tag) {
	warn "Illegal end tag $_[0]";
    } else {
	#print "END: $tag\n";
	$tag = lc $tag;
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
    my $pos = $html->pos;

    my @text = @_;
    expandEntities(@text);

    if ($pos->isInside('pre')) {
	$pos->pushContent(@text);
    } else {
	my $empty = 1;
	for (@text) {
	    $empty = 0 if /\S/;
	}
	return if $empty;

	my $ptag = $pos->tag;
	if ($ptag eq 'head') {
	    endtag($html, 'head');
	    insertTag($html, 'body');
	    $pos = insertTag($html, 'p');
	} elsif ($ptag eq 'html') {
	    insertTag($html, 'body');
	    $pos = insertTag($html, 'p');
	} elsif ($ptag eq 'body' ||
		 $ptag eq 'li'   ||
		 $ptag eq 'dd'   ||
		 $ptag eq 'form') {
	    $pos = insertTag($html, 'p');
	}
	for (@text) {
	    next if /^\s*$/;  # empty text
	    if ($SPLIT_TEXT) {
		$pos->pushContent(split(' ', $_));
	    } else {
		s/\s+/ /g;  # canoncial space
		$pos->pushContent($_);
	    }
	}
    }
}

sub expandEntities
{
    for (@_) {
	s/(&\#(\d+);?)/$2 < 256 ? chr($2) : $1/eg;
	s/(&(\w+);?)/$entities{$2} || $1/eg;
    }
}


sub parsefile
{
    my $file = shift;
    open(F, $file) or return new HTML::Element 'html', 'comment' => $!;
    my $html = undef;
    while(<F>) {
	$html = parse($_, $html);
    }
    close(F);
    $html;
}

1;
