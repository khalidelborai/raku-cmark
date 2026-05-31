use Cmark::Native;
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

#| Release the document tree this object owns. cmark_node_free frees the root
#| node and all of its children, so borrowed child Node objects obtained via
#| traversal must not outlive their owning Cmark.
submethod DESTROY {
    cmark_node_free($!node) if $!node.defined;
}
