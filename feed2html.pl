#!/usr/local/bin/perl
# RSS/atom feed to html converter

# Params 
#
# feed_url: url of the atom or rss feed
# img: allow images
# max: number of items to retrieve

use FindBin;
use lib "$FindBin::Bin/../perl5/lib/perl5";
use CGI qw(:standard);
use XML::Feed;
use HTML::TagFilter;
use HTML::Entities;
use Encode::ZapCP1252;
use Data::Dump qw( dump );
use utf8;

my $max  =5; # max feed items to display
my $img  =0; # show images
my $terse=0; # don't show descriptions
my $refresh=0; # force refresh of cache
my $js_mode=0; # generate javascript for external sites

# if this is called without a parameter, display a form to enter an RSS url
if (!param()) {
  print header(-type=>"text/html",-charset=>"UTF-8");
	print start_html('Feed Parser'),
	h1('Feed Parser');
	print "
	<form action=\"feed2html.pl\"><p>
	<label for=\"feed_url\">Feed URL</label>
	<input type=\"text\" name=\"feed_url\" id=\"feed_url\" size=\"40\" /><br />
	<label for=\"max\">Max items to retrieve</label>
	<input type=\"text\" name=\"max\" id=\"max\" value=\"5\" size=\"3\" /><br /> 
	<label for=\"img\">Retrieve images?</label>
	<input type=\"checkbox\" name=\"img\" id=\"img\" /><br />
	<label for=\"refresh\">Refresh cached file</label>
	<input type=\"checkbox\" name=\"refresh\" id=\"refresh\" /><br />
	<label for=\"terse\">Terse format (no descriptions)?</label>
	<input type=\"checkbox\" name=\"terse\" id=\"terse\" /> 
	<label for=\"js_mode\">Javascript mode ()?</label>
	<input type=\"checkbox\" name=\"js_mode\" id=\"js_mode\" /> 
	<input type=\"submit\" /></p>
	</form>
	";
	print end_html;
	exit (0);

} 
# If called with a parameter, we launch the parser and output HTML
else {
	my $feed_url = param('feed_url');
	$max   = param('max') 	|| $max;
	$img   = param('img') 	|| $img;
	$terse = param('terse') || $terse;
	$refresh = param('refresh') || $refresh;
  $js_mode = param('js_mode') || $js_mode;

  if ($js_mode) {
    print header(-type=>"text/javascript",-charset=>"UTF-8");
  }
  else {
    print header(-type=>"text/html",-charset=>"UTF-8");
  }
	
  # RSS Filename is the URL without http:// in it and replacing "/" with "-" 
	# and within the ./cache/ directory.
	my $feed_filename = $feed_url; 
	$feed_filename =~ s/http:\/\///ig; 
	$feed_filename =~ s/\//-/ig; 
	$feed_filename = "../cache/".$feed_filename; 

	# In case we're dozy and forget the http://
	$feed_url = "http://$feed_url" unless($feed_url =~/^http:\/\//) ;
	
	# Calculate file modified time
	($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($feed_filename);
	my $feed_source; #i.e. the final html, however we find it

	if ($mtime >= time() - 3600 && $refresh ne 'on') {
		$feed_source = get_cached_file($feed_filename);
	} 
	else {
		my $err =0;
		my $feed = XML::Feed->parse(URI->new($feed_url)) or ++$err;

		# drop back to cached file if there's a problem retrieving and exists and can be read
		if($err) {
			if(-e $feed_filename && -r $feed_filename) {
				$feed_source = get_cached_file($feed_filename);
			}
			else {
				die print "Can't parse feed. Haven't got cached version. Error is '" . XML::Feed->errstr ."'";
			}
		}
		# If we are able to retrieve rss feed, parse it and write that to the file
		else {
			my $html='';
			my $counter=0;
			for my $item ($feed->entries) {
				last if ($counter == $max); 
				next unless defined($item->title) && defined($item->link);
				$html .= u("<h4><a href=\"" . $item->link .
					"\" title=\"" . $item->title . "\" >".
					$item->title . "</a></h4>");
				$html .= u("<p>" . $item->content->body . "</p>") unless($terse);
			       	$html .= u("\n");
				$counter++;
			}
			$html = rmimg($html) unless $img;
			open (RSSFILE, "> $feed_filename") or die print "Unable to write file $feed_filename. Error is '$!'";
			print RSSFILE $html;
			close (RSSFILE);
			$feed_source = get_cached_file($feed_filename);
		}
	}
	if($js_mode) {
    print get_js($feed_source);
  }
  else {
    print $feed_source;
  }
	exit (0);
}

# Returns contents of a cached file as a string
sub get_cached_file($) {
	my $feed_filename = shift;
	open (RSSFILE, "$feed_filename") or die print "Can't open file $feed_filename. Error is '$!'";
	undef $/; 
	my $source = <RSSFILE>; 
	close (RSSFILE);
	return $source;
}

# Returns string properly utf8 encoded
sub u($) {
	$x=demoronise(shift);
	utf8::encode($x);
	return $x;
}

# Returns string without images (and javascript et al)
sub rmimg($) {
	my $tf = new HTML::TagFilter(deny=>{img=>{'all'},embed=>{'all'}});
	return $tf->filter(shift);
}


# Deal with (allegedly) "smart" punctuation.
sub demoronise($)
{
	my $x= shift;
	zap_cp1252($x);
	$x =~ s/\xE2\x80\x9A/,/go;	
	$x =~ s/\xE2\x80\x9E/,,/go;	
	$x =~ s/\xE2\x80\xA6/.../go;	
	$x =~ s/\xCB\x86/^/go;		
	$x =~ s/\xE2\x80\x98/`/go;	
	$x =~ s/\xE2\x80\x99/'/go;	
	$x =~ s/\xE2\x80\x9C/"/go;	
	$x =~ s/\xE2\x80\x9D/"/go;	
	$x =~ s/\xE2\x80\xA2/*/go;	
	$x =~ s/\xE2\x80\x93/-/go;	
	$x =~ s/\xE2\x80\x94/-/go;	
	$x =~ s/\xE2\x80\xB9/</go;	
	$x =~ s/\xE2\x80\xBA/>/go;	
	return $x;
}

# Beta: make our html into javascript and return that
sub get_js {
  my $html = shift;
#  $html = encode_entities($html, ''); # encode the odd stuff but not <>&
  $html =~ s/[^&\n\x20-\x25\x27-\x7e]//g;
  $html =~ s/'/&apos;/g;
  $html =~ s/[\r\n]+/\\\r\n/g;
  # trim out para tags
  $html =~ s/<p>//g;
  $html =~ s/<\/p>//g;
  # trim spans
  $html =~ s/<span[^>]+>//g;
  $html =~ s/<\/span>//g;
  #$html = escapeHTML($html);
  #return "document.write('hello?');";
  return "document.write('$html \\\r\n');";# <p>&copy; 2009 <a href=\"http://www.newint.org/\">New Internationalist</a></p>');";
}
