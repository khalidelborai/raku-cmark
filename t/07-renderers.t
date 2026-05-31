use Test;
use Cmark;

my $doc = Cmark.parse("# Title\n\nA paragraph with *emphasis*.\n");

# HTML output is stable enough to pin exactly
is $doc.to-html, "<h1>Title</h1>\n<p>A paragraph with <em>emphasis</em>.</p>\n", "to-html";

# the other renderers vary in detail across cmark versions, so assert structure
ok $doc.to-xml.contains("<?xml") && $doc.to-xml.contains("document"), "to-xml looks like cmark XML";
ok $doc.to-man.contains("Title"), "to-man contains the content";
ok $doc.to-latex.contains("Title"), "to-latex contains the content";
ok $doc.to-commonmark.contains("# Title"), "to-commonmark round-trips the heading";

# width is accepted by the wrapping renderers
lives-ok { $doc.to-commonmark(:width(20)) }, "to-commonmark accepts :width";
lives-ok { $doc.to-latex(:width(20)) }, "to-latex accepts :width";
lives-ok { $doc.to-man(:width(20)) }, "to-man accepts :width";

# the SAFE/UNSAFE options reach the renderer
my $link = Cmark.parse("[x](javascript:alert(1))");
is $link.to-html(CMARK_OPT_SAFE), "<p><a href=\"\">x</a></p>\n", "SAFE strips unsafe link";
ok $link.to-html(CMARK_OPT_UNSAFE).contains("javascript:"), "UNSAFE keeps it";

done-testing;
