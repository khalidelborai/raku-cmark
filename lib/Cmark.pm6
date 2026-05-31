use Cmark::Native;

# Re-export Cmark::Native's exports (node/list/delim/event enums, the Node/Parser/
# CIterator classes, X::Cmark::NoNode, and the raw cmark_* subs) so that a plain
# `use Cmark` gives consumers the typed enums and helpers, not just the OO class.
sub EXPORT { Map.new( Cmark::Native::EXPORT::DEFAULT::.pairs ) }

#| Main Class
unit class Cmark;

has $.node;
has $.options is rw;

enum OPTIONS is export (
    CMARK_OPT_DEFAULT => 0,
    CMARK_OPT_SOURCEPOS =>  1 +< 1,
    CMARK_OPT_HARDBREAKS  => 1 +< 2,
    CMARK_OPT_SAFE => 1 +< 3,
    CMARK_OPT_UNSAFE => 1 +< 17,
    CMARK_OPT_NOBREAKS => 1 +< 4,
    CMARK_OPT_NORMALIZE => 1 +< 8,
    CMARK_OPT_VALIDATE_UTF8 => 1 +< 9 ,
    CMARK_OPT_SMART => 1 +< 10
);


multi method parse(Cmark:U: Str $md, $options = CMARK_OPT_DEFAULT) returns Cmark {
    my $node = cmark_parse_document($md, $md.encode('utf-8').bytes, $options);
    return self.bless(:$node,:$options);
}

multi method parse(Cmark:U: IO $md, $options = CMARK_OPT_DEFAULT) returns Cmark {
    samewith($md.slurp, $options);
}

multi method parse(Cmark:D: $md, $options = CMARK_OPT_DEFAULT) {
    cmark_node_free($!node) if $!node.defined;
    $!node = cmark_parse_document($md, $md.encode('utf-8').bytes, $options);
    $!options = $options;
    self;
}

#| One-shot Markdown → HTML without building a reusable document. Equivalent to
#| Cmark.parse($md, $options).to-html but cheaper when you only need the HTML once.
method markdown-to-html(Cmark:U: Str $md, $options = CMARK_OPT_DEFAULT --> Str) {
    cstr-to-str-free(cmark_markdown_to_html($md, $md.encode('utf-8').bytes, $options));
}

method to-html($options = $!options) {
    die X::Cmark::NoNode.new without $!node;
    cstr-to-str-free(cmark_render_html($!node,$options));
}

method to-xml($options = $!options) {
    die X::Cmark::NoNode.new without $!node;
    cstr-to-str-free(cmark_render_xml($!node,$options));
}

method to-man($options = $!options , :$width = 0) {
    die X::Cmark::NoNode.new without $!node;
    cstr-to-str-free(cmark_render_man($!node,$options,$width));
}

method to-commonmark($options = $!options,:$width = 0) {
    die X::Cmark::NoNode.new without $!node;
    cstr-to-str-free(cmark_render_commonmark($!node,$options,$width));
}

method to-latex($options = $!options,:$width =  0) {
    die X::Cmark::NoNode.new without $!node;
    cstr-to-str-free(cmark_render_latex($!node,$options,$width));
}

method version {
    cmark_version_string;
}

#| Walk the document tree depth-first, calling &block with each node once (on its
#| ENTER event, so every node is visited exactly once). Yielded nodes are borrowed
#| — do not free them; they belong to this Cmark's tree. The iterator is released
#| when it goes out of scope.
method walk(&block) {
    die X::Cmark::NoNode.new without $!node;
    my $iter = cmark_iter_new($!node);
    loop {
        my $ev = $iter.next;
        last if $ev == CMARK_EVENT_DONE;
        block($iter.node) if $ev == CMARK_EVENT_ENTER;
    }
}

#| Release the document tree this object owns. cmark_node_free frees the root
#| node and all of its children, so borrowed child Node objects obtained via
#| traversal must not outlive their owning Cmark.
submethod DESTROY {
    cmark_node_free($!node) if $!node.defined;
}
