use Test;
use Cmark;

# Regression: parse passes a *byte* length to cmark_parse_document. Passing the
# codepoint count (the old bug) truncated multibyte input and cmark rejected it
# as "Malformed UTF-8". These lock the byte-correct behaviour.

is Cmark.parse("# café").to-html, "<h1>café</h1>\n", "multibyte heading parses and round-trips";
is Cmark.parse("# naïve — résumé ☕").to-html.chomp, "<h1>naïve — résumé ☕</h1>",
    "mixed 2/3/4-byte codepoints";
lives-ok { Cmark.parse("é").to-html }, "a lone multibyte codepoint does not throw";
ok Cmark.parse("☕" x 100).to-html.contains("☕"), "many multibyte codepoints survive";

# IO path (slurps the file, then the same byte-length path)
my $f = $*TMPDIR.add("cmark-utf8-{$*PID}.md");
$f.spurt("# from file ☕\n");
LEAVE $f.unlink;
is Cmark.parse($f).to-html.chomp, "<h1>from file ☕</h1>", "IO path is byte-correct";

# one-shot convenience
is Cmark.markdown-to-html("# café").chomp, "<h1>café</h1>", "markdown-to-html is byte-correct";

done-testing;
