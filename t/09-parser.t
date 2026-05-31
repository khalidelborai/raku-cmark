use Test;
use Cmark::Native;

# The streaming Parser used to be dead (NULL CPointer from BUILD, never exported).
# It must now construct and parse incrementally.

my $p = Parser.new(0);
isa-ok $p, Parser, "Parser.new returns a Parser";
ok $p.defined, "the parser pointer is non-null";

$p.feed("# Stream ☕\n\n");
$p.feed("para *x*\n");
my $doc = $p.finish;
is $doc.type, CMARK_NODE_DOCUMENT, "finish returns a document node";

my $html = cstr-to-str-free(cmark_render_html($doc, 0));
ok $html.contains("<h1>Stream ☕</h1>"), "streamed heading rendered (UTF-8 intact)";
ok $html.contains("<em>x</em>"), "streamed emphasis rendered";
cmark_node_free($doc);   # the finished tree belongs to the caller

# one-shot helper
my $d2 = Parser.new(0).parse("# Hi\n\n- a");
ok cstr-to-str-free(cmark_render_html($d2, 0)).contains("<h1>Hi</h1>"), "Parser.parse one-shot works";
cmark_node_free($d2);

done-testing;
