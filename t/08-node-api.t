use Test;
use Cmark;

my $doc = Cmark.parse("# Heading\n\n- a\n- b\n");

# type coercion to the typed enums
is $doc.node.type, CMARK_NODE_DOCUMENT, "document node type is a NodeType";
is $doc.node.type(:str), "document", "type(:str) gives the string form";
ok $doc.node.is-block, "document is a block";
nok $doc.node.is-inline, "document is not inline";

# traversal accessors
my $h = $doc.node.first-child;
is $h.type, CMARK_NODE_HEADING, "first child is the heading";
ok $h.is-block, "heading is a block";
my $list = $h.next;
is $list.type, CMARK_NODE_LIST, "the heading's next sibling is the list";
is $list.list-type, CMARK_BULLET_LIST, "it is a bullet list";

# walk visits every node exactly once (on ENTER)
my %count;
$doc.walk(-> $n { %count{$n.type}++ });
is %count{CMARK_NODE_HEADING}, 1, "walk saw one heading";
is %count{CMARK_NODE_ITEM},    2, "walk saw two list items";
is %count{CMARK_NODE_LIST},    1, "walk saw one list";

# enum numeric values (verified against cmark 0.31.2)
is CMARK_NODE_IMAGE.Int,    20, "NodeType numeric value";
is CMARK_ORDERED_LIST.Int,   2, "ListType numeric value";
is CMARK_PAREN_DELIM.Int,    2, "DelimType numeric value";
is CMARK_EVENT_EXIT.Int,     3, "EventType numeric value";

done-testing;
