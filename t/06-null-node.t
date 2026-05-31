use Test;
use Cmark;

# Rendering before parsing handed cmark a NULL node, which it dereferenced and
# crashed the process (SIGSEGV) — uncatchable. It must now throw a catchable
# X::Cmark::NoNode instead.

for <to-html to-xml to-man to-commonmark to-latex> -> $m {
    throws-like { Cmark.new."$m"() }, X::Cmark::NoNode, "$m on an unparsed doc throws (no segfault)";
}

throws-like { Cmark.new.walk(-> $n {}) }, X::Cmark::NoNode, "walk on an unparsed doc throws";

my $caught = (try { Cmark.new.to-html; Nil }) // $!;
isa-ok $caught, X::Cmark::NoNode, "the thrown exception is the typed one";
ok $caught.message.contains("undefined node"), "the message is informative";

# a normal parsed document still renders
lives-ok { Cmark.parse("# ok").to-html }, "a parsed document renders fine";

done-testing;
