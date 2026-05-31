use Test;
use Cmark;

# In-place re-parse used to be a silent no-op (it hit the constructor candidate
# and assigned through a read-only accessor). It must now mutate the receiver.

my $doc = Cmark.parse("# One");
is $doc.to-html.chomp, "<h1>One</h1>", "initial parse";

my $ret = $doc.parse("# Two");
ok $ret === $doc, "in-place parse returns the same object";
is $doc.to-html.chomp, "<h1>Two</h1>", "in-place parse replaces the document";

$doc.parse("# Three", CMARK_OPT_SOURCEPOS);
ok $doc.to-html.contains("data-sourcepos"), "re-parse carries the new options";

# the `.= parse` idiom keeps a Cmark and updates it
my $d2 = Cmark.parse("# A");
$d2 .= parse("# B");
isa-ok $d2, Cmark, ".= parse keeps a Cmark";
is $d2.to-html.chomp, "<h1>B</h1>", ".= parse updates the document";

# the constructor builds distinct objects
my $a = Cmark.parse("# X");
my $b = Cmark.parse("# Y");
nok $a === $b, "Cmark.parse builds distinct objects";
is $a.to-html.chomp, "<h1>X</h1>", "first object unaffected by second";

done-testing;
