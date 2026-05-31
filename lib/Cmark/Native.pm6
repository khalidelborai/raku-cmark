use NativeCall;
unit module Cmark::Native;

#| libc free(3). cmark's default memory allocator hands back malloc'd buffers
#| (the rendered strings) that the caller is responsible for releasing.
sub free(Pointer) is native { * }

#| Decode a NUL-terminated UTF-8 C string produced by a cmark renderer into a
#| Raku Str, then free the underlying buffer. The nativecast copies the bytes,
#| so the Str fully owns its data before the buffer is released. Returns '' for
#| a NULL pointer (cmark yields NULL on render failure).
sub cstr-to-str-free(Pointer[uint8] $p --> Str) is export {
    return '' unless $p.defined;
    my $str = nativecast(Str, $p);
    free($p);
    $str;
}

#________________________________________________Classes__________________________________________________________#

#| Thrown when an operation is attempted on an undefined node — e.g. rendering a
#| Cmark before calling .parse, or following a traversal link past the end of the
#| tree. Catchable, unlike the SIGSEGV an unchecked NULL node would cause in C.
class X::Cmark::NoNode is Exception is export {
    method message(--> Str) {
        "Cmark: operation attempted on an undefined node — parse a document first"
    }
}

#| Node, list, list-delimiter, and traversal-event type enums. Values match the C
#| `cmark_node_type` / `cmark_list_type` / `cmark_delim_type` / `cmark_event_type`
#| enums in cmark.h (verified against 0.31.2).
enum NodeType is export (
    CMARK_NODE_NONE           => 0,
    CMARK_NODE_DOCUMENT       => 1,
    CMARK_NODE_BLOCK_QUOTE    => 2,
    CMARK_NODE_LIST           => 3,
    CMARK_NODE_ITEM           => 4,
    CMARK_NODE_CODE_BLOCK     => 5,
    CMARK_NODE_HTML_BLOCK     => 6,
    CMARK_NODE_CUSTOM_BLOCK   => 7,
    CMARK_NODE_PARAGRAPH      => 8,
    CMARK_NODE_HEADING        => 9,
    CMARK_NODE_THEMATIC_BREAK => 10,
    CMARK_NODE_TEXT           => 11,
    CMARK_NODE_SOFTBREAK      => 12,
    CMARK_NODE_LINEBREAK      => 13,
    CMARK_NODE_CODE           => 14,
    CMARK_NODE_HTML_INLINE    => 15,
    CMARK_NODE_CUSTOM_INLINE  => 16,
    CMARK_NODE_EMPH           => 17,
    CMARK_NODE_STRONG         => 18,
    CMARK_NODE_LINK           => 19,
    CMARK_NODE_IMAGE          => 20,
);

enum ListType is export (
    CMARK_NO_LIST      => 0,
    CMARK_BULLET_LIST  => 1,
    CMARK_ORDERED_LIST => 2,
);

enum DelimType is export (
    CMARK_NO_DELIM     => 0,
    CMARK_PERIOD_DELIM => 1,
    CMARK_PAREN_DELIM  => 2,
);

enum EventType is export (
    CMARK_EVENT_NONE  => 0,
    CMARK_EVENT_DONE  => 1,
    CMARK_EVENT_ENTER => 2,
    CMARK_EVENT_EXIT  => 3,
);

class Node is repr('CPointer') is export {

    multi method text {
        cmark_node_get_literal(self) // '';
    }

    multi method text($text) {
        cmark_node_set_literal(self,$text);
    }
    multi method type(:$str!){
        die X::Cmark::NoNode.new without self;
        cmark_node_get_type_string(self);
    }
    multi method type {
        die X::Cmark::NoNode.new without self;
        NodeType(cmark_node_get_type(self));
    }
    method list-type {
        die X::Cmark::NoNode.new without self;
        ListType(cmark_node_get_list_type(self));
    }
    method list-delim {
        die X::Cmark::NoNode.new without self;
        DelimType(cmark_node_get_list_delim(self));
    }
    method is-block {
        die X::Cmark::NoNode.new without self;
        cmark_node_is_block(self);
    }
    method is-inline {
        die X::Cmark::NoNode.new without self;
        cmark_node_is_inline(self);
    }
    method is-leaf {
        die X::Cmark::NoNode.new without self;
        cmark_node_is_leaf(self);
    }

    method next {
        return cmark_node_next( self );
    }
    method previous {
        return cmark_node_previous( self );
    }
    method parent {
        return cmark_node_parent( self );
    }
    method first-child {
        return cmark_node_first_child( self );
    }
    method last-child {
        return cmark_node_last_child( self );
    }
    multi method render($options = 0,:$html!) {
        die X::Cmark::NoNode.new without self;
        cstr-to-str-free(cmark_render_html(self,$options));
    }
    multi method render($options = 0,:$xml!) {
        die X::Cmark::NoNode.new without self;
        cstr-to-str-free(cmark_render_xml(self,$options));
    }
    multi method render($options = 0 ,$width = 0,:$latex!) {
        die X::Cmark::NoNode.new without self;
        cstr-to-str-free(cmark_render_latex(self,$options,$width));
    }
    multi method render($options = 0 ,$width = 0,:$commonmark!) {
        die X::Cmark::NoNode.new without self;
        cstr-to-str-free(cmark_render_commonmark(self,$options,$width));
    }
    multi method render($options = 0 ,$width = 0,:$man!) {
        die X::Cmark::NoNode.new without self;
        cstr-to-str-free(cmark_render_man(self,$options,$width));
    }
}
#| Wraps a `cmark_parser` for streaming/incremental parsing. A CPointer instance
#| cannot be produced by the default `new` (which blesses an empty pointer), so
#| `new` is overridden to return the pointer from cmark_parser_new directly.
class Parser is repr('CPointer') is export {
    #| Create a parser with the given option bitflags.
    method new(Parser:U: Int $options = 0 --> Parser) {
        cmark_parser_new($options);
    }

    #| Feed a chunk of (UTF-8) Markdown to the parser.
    method feed(Str $buff) {
        cmark_parser_feed(self, $buff, $buff.encode('utf-8').bytes);
    }

    #| Finish parsing and return the document tree. Ownership of the returned
    #| node transfers to the caller — free it with cmark_node_free. The parser
    #| no longer owns it, so this Parser's DESTROY (cmark_parser_free) is safe.
    method finish(--> Node) {
        cmark_parser_finish(self);
    }

    #| Feed a whole string and finish, returning the document tree.
    method parse(Str $md --> Node) {
        self.feed($md);
        self.finish;
    }

    submethod DESTROY {
        cmark_parser_free(self);
    }
}


#| Wraps a `cmark_iter`. Construct it from cmark_iter_new(root) — a CPointer
#| cannot be built with .new/bless, the pointer must come from the native call.
#| The iterator borrows the tree (owns nothing in it), so DESTROY frees only the
#| iterator itself, never the nodes it yields.
class CIterator is repr('CPointer') is export {
    #| Advance to the next node; returns an EventType (ENTER / EXIT / DONE).
    method next       { EventType(cmark_iter_next(self)) }
    #| The node at the current position.
    method node       { cmark_iter_get_node(self) }
    #| The event type at the current position.
    method event-type { EventType(cmark_iter_get_event_type(self)) }
    #| The root node the iterator was created from.
    method root       { cmark_iter_get_root(self) }
    #| Reset the iterator to resume at a given node and event.
    method reset(Node $current, EventType $event-type) {
        cmark_iter_reset(self, $current, $event-type.Int);
    }
    submethod DESTROY { cmark_iter_free(self) }
}
#________________________________________________Iterator__________________________________________________________#
#| Creates a new iterator starting at 'root'. The current node and event type are undefined until 'cmark_iter_next' is called for the first time. The memory allocated for the iterator should be released using 'cmark_iter_free' when it is no longer needed.
#| | `cmark_iter * cmark_iter_new(cmark_node *root)`
sub cmark_iter_new( Node ) returns CIterator is native('cmark') is export { * }

#| Frees the memory allocated for an iterator.
#| | `void cmark_iter_free(cmark_iter *iter)`
sub cmark_iter_free( CIterator ) is native('cmark') is export { * }

#| Advances to the next node and returns the event type (`CMARK_EVENT_ENTER`, `CMARK_EVENT_EXIT` or `CMARK_EVENT_DONE`).
#| | `cmark_event_type cmark_iter_next(cmark_iter *iter)`
sub cmark_iter_next( CIterator ) returns int32 is native('cmark') is export { * }

#| Returns the current node.
#| | `cmark_node * cmark_iter_get_node(cmark_iter *iter)`
sub cmark_iter_get_node( CIterator ) returns Node is native('cmark') is export { * }

#| Returns the current event type.
#| | `cmark_event_type cmark_iter_get_event_type(cmark_iter *iter)`
sub cmark_iter_get_event_type( CIterator ) returns int32 is native('cmark') is export { * }

#| Returns the root node.
#| | `cmark_node * cmark_iter_get_root(cmark_iter *iter)`
sub cmark_iter_get_root( CIterator ) returns Node is native('cmark') is export { * }

#| Resets the iterator so the next cmark_iter_next reports 'current' with 'event_type'.
#| | `void cmark_iter_reset(cmark_iter *iter, cmark_node *current, cmark_event_type event_type)`
sub cmark_iter_reset( CIterator, Node, int32 ) is native('cmark') is export { * }
#________________________________________________Creating-and-Destroying-Nodes__________________________________________________________#

#| Creates a new node of type 'type'. Note that the node may have other required properties, which it is the caller's responsibility to assign.
#| | `cmark_node *cmark_node_new(cmark_node_type type);`
sub cmark_node_new( int32 ) returns Node is native('cmark') is export { * }

#| Frees the memory allocated for a node and any children.
#| | `void cmark_node_free(cmark_node *node)`
sub cmark_node_free( Node ) is native('cmark') is export { * }


#________________________________________________Tree-Traversal__________________________________________________________
#| Returns the next node in the sequence after 'node', or NULL if there is none.
#| | `cmark_node * cmark_node_next(cmark_node *node)`
sub cmark_node_next( Node ) returns Node is native('cmark') is export { * }

#| Returns the previous node in the sequence after 'node', or NULL if there is none.
#| | `cmark_node * cmark_node_previous(cmark_node *node)`
sub cmark_node_previous( Node ) returns Node is native('cmark') is export { * }

#| Returns the parent of 'node', or NULL if there is none.
#| | `cmark_node * cmark_node_parent(cmark_node *node)`
sub cmark_node_parent( Node ) returns Node is native('cmark') is export { * }

#| Returns the first child of 'node', or NULL if 'node' has no children.
#| | `cmark_node * cmark_node_first_child(cmark_node *node)`
sub cmark_node_first_child( Node ) returns Node is native('cmark') is export { * }

#| Returns the last child of 'node', or NULL if 'node' has no children.
#| | `cmark_node * cmark_node_last_child(cmark_node *node)`
sub cmark_node_last_child( Node ) returns Node is native('cmark') is export { * }


#________________________________________________Accessors__________________________________________________________#
#| Returns the user data of 'node'.
#| | `void * cmark_node_get_user_data(cmark_node *node)`
sub cmark_node_get_user_data(  Node ) returns Pointer is native('cmark') is export { * }

#| Sets arbitrary user data for 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_set_user_data(cmark_node *node, void *user_data)`
sub cmark_node_set_user_data(  Node, Pointer ) returns int32 is native('cmark') is export { * }

#| Returns the type of 'node', or `CMARK_NODE_NONE` on error.
#| | `cmark_node_type cmark_node_get_type(cmark_node *node)`
sub cmark_node_get_type(  Node ) returns int32 is native('cmark') is export { * }

#| Like `cmark_node_get_type`, but returns a string representation of the type, or "<unknown>".
#| | `const char * cmark_node_get_type_string(cmark_node *node)`
sub cmark_node_get_type_string(  Node ) returns Str is encoded('utf8') is native('cmark') is export { * }

#| Returns 1 if the node is a block-level element, 0 otherwise.
#| | `bool cmark_node_is_block(cmark_node *node)`
sub cmark_node_is_block( Node ) returns bool is native('cmark') is export { * }

#| Returns 1 if the node is an inline element, 0 otherwise.
#| | `bool cmark_node_is_inline(cmark_node *node)`
sub cmark_node_is_inline( Node ) returns bool is native('cmark') is export { * }

#| Returns 1 if the node is a leaf (cannot contain children), 0 otherwise.
#| | `bool cmark_node_is_leaf(cmark_node *node)`
sub cmark_node_is_leaf( Node ) returns bool is native('cmark') is export { * }

#| Returns the string contents of 'node', or an empty string if none is set. Returns NULL if called on a node that does not have string content.
#| | `const char * cmark_node_get_literal(cmark_node *node)`
sub cmark_node_get_literal(  Node ) returns Str is encoded('utf8') is native('cmark') is export { * }

#| Sets the string contents of 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_set_literal(cmark_node *node, const char *content)`
sub cmark_node_set_literal(  Node, Str is encoded('utf8') ) returns int32 is native('cmark') is export { * }

#| Returns the heading level of 'node', or 0 if 'node' is not a heading.
#| | `int cmark_node_get_heading_level(cmark_node *node)`
sub cmark_node_get_heading_level(  Node ) returns int32 is native('cmark') is export { * }

#| Sets the heading level of 'node', returning 1 on success and 0 on error.
#| | `int cmark_node_set_heading_level(cmark_node *node, int level)`
sub cmark_node_set_heading_level(  Node, int32 ) returns int32 is native('cmark') is export { * }

#| Returns the list type of 'node', or `CMARK_NO_LIST` if 'node' is not a list.
#| | `cmark_list_type cmark_node_get_list_type(cmark_node *node)`
sub cmark_node_get_list_type(  Node ) returns int32 is native('cmark') is export { * }

#| Sets the list type of 'node', returning 1 on success and 0 on error.
#| | `int cmark_node_set_list_type(cmark_node *node, cmark_list_type type)`
sub cmark_node_set_list_type(  Node, int32 ) returns int32 is native('cmark') is export { * }

#| Returns the list delimiter type of 'node', or `CMARK_NO_DELIM` if 'node' is not a list.
#| | `cmark_delim_type cmark_node_get_list_delim(cmark_node *node)`
sub cmark_node_get_list_delim(  Node ) returns int32 is native('cmark') is export { * }

#| Sets the list delimiter type of 'node', returning 1 on success and 0 on error.
#| | `int cmark_node_set_list_delim(cmark_node *node, cmark_delim_type delim)`
sub cmark_node_set_list_delim(  Node, int32 ) returns int32 is native('cmark') is export { * }

#| Returns starting number of 'node', if it is an ordered list, otherwise 0.
#| | `int cmark_node_get_list_start(cmark_node *node)`
sub cmark_node_get_list_start(  Node ) returns int32 is native('cmark') is export { * }

#| Sets starting number of 'node', if it is an ordered list. Returns 1 on success, 0 on failure.
#| | `int cmark_node_set_list_start(cmark_node *node, int start)`
sub cmark_node_set_list_start(  Node, int32 ) returns int32 is native('cmark') is export { * }

#| Returns 1 if 'node' is a tight list, 0 otherwise.
#| | `int cmark_node_get_list_tight(cmark_node *node)`
sub cmark_node_get_list_tight(  Node ) returns int32 is native('cmark') is export { * }

#| Sets the "tightness" of a list. Returns 1 on success, 0 on failure.
#| | `int cmark_node_set_list_tight(cmark_node *node, int tight)`
sub cmark_node_set_list_tight(  Node, int32 ) returns int32 is native('cmark') is export { * }

#| Returns the info string from a fenced code block.
#| | `const char * cmark_node_get_fence_info(cmark_node *node)`
sub cmark_node_get_fence_info(  Node ) returns Str is encoded('utf8') is native('cmark') is export { * }

#| Sets the info string in a fenced code block, returning 1 on success and 0 on failure.
#| | `int cmark_node_set_fence_info(cmark_node *node, const char *info)`
sub cmark_node_set_fence_info(  Node, Str is encoded('utf8') ) returns int32 is native('cmark') is export { * }

#| Returns the URL of a link or image 'node', or an empty string if no URL is set. Returns NULL if called on a node that is not a link or image.
#| | `const char * cmark_node_get_url(cmark_node *node)`
sub cmark_node_get_url(  Node ) returns Str is encoded('utf8') is native('cmark') is export { * }

#| Sets the URL of a link or image 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_set_url(cmark_node *node, const char *url)`
sub cmark_node_set_url(  Node, Str is encoded('utf8') ) returns int32 is native('cmark') is export { * }

#| Returns the title of a link or image 'node', or an empty string if no title is set. Returns NULL if called on a node that is not a link or image.
#| | `const char * cmark_node_get_title(cmark_node *node)`
sub cmark_node_get_title(  Node ) returns Str is encoded('utf8') is native('cmark') is export { * }

#| Sets the title of a link or image 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_set_title(cmark_node *node, const char *title)`
sub cmark_node_set_title(  Node, Str is encoded('utf8') ) returns int32 is native('cmark') is export { * }

#| Returns the literal "on enter" text for a custom 'node', or an empty string if no on_enter is set. Returns NULL if called on a non-custom node.
#| | `const char * cmark_node_get_on_enter(cmark_node *node)`
sub cmark_node_get_on_enter(  Node ) returns Str is encoded('utf8') is native('cmark') is export { * }

#| Sets the literal text to render "on enter" for a custom 'node'. Any children of the node will be rendered after this text. Returns 1 on success 0 on failure.
#| | `int cmark_node_set_on_enter(cmark_node *node, const char *on_enter)`
sub cmark_node_set_on_enter(  Node, Str is encoded('utf8') ) returns int32 is native('cmark') is export { * }

#| Returns the literal "on exit" text for a custom 'node', or an empty string if no on_exit is set. Returns NULL if called on a non-custom node.
#| | `const char * cmark_node_get_on_exit(cmark_node *node)`
sub cmark_node_get_on_exit(  Node ) returns Str is encoded('utf8') is native('cmark') is export { * }

#| Sets the literal text to render "on exit" for a custom 'node'. Any children of the node will be rendered before this text. Returns 1 on success 0 on failure.
#| `int cmark_node_set_on_exit(cmark_node *node, const char *on_exit)`
sub cmark_node_set_on_exit(  Node, Str is encoded('utf8') ) returns int32 is native('cmark') is export { * }

#| Returns the line on which 'node' begins.
#| | `int cmark_node_get_start_line(cmark_node *node)`
sub cmark_node_get_start_line(  Node ) returns int32 is native('cmark') is export { * }

#| Returns the column at which 'node' begins.
#| | `int cmark_node_get_start_column(cmark_node *node)`
sub cmark_node_get_start_column(  Node ) returns int32 is native('cmark') is export { * }

#| Returns the line on which 'node' ends.
#| | `int cmark_node_get_end_line(cmark_node *node)`
sub cmark_node_get_end_line(  Node ) returns int32 is native('cmark') is export { * }

#| Returns the column at which 'node' ends.
#| | `int cmark_node_get_end_column(cmark_node *node)`
sub cmark_node_get_end_column(  Node ) returns int32 is native('cmark') is export { * }



#________________________________________________Rendering__________________________________________________________#
#| Render the Node to XML
#| | `char *cmark_render_xml(cmark_node *root, int options);`
sub cmark_render_xml( Node, int32 ) returns Pointer[uint8] is native('cmark') is export { * }

#| Render the Node to HTML
#| | `char *cmark_render_html(cmark_node *root, int options);`
sub cmark_render_html( Node, int32 ) returns Pointer[uint8] is native('cmark') is export { * }

#| Render the Node to man
#| | `char *cmark_render_man(cmark_node *root, int options, int width);`
sub cmark_render_man( Node, int32, int32 ) returns Pointer[uint8] is native('cmark') is export { * }

#| Render the Node to CommonMark
#| | `char *cmark_render_commonmark(cmark_node *root, int options, int width);`
sub cmark_render_commonmark( Node, int32, int32 ) returns Pointer[uint8] is native('cmark') is export { * }

#| Render the Node to latex
#| | `char *cmark_render_latex(cmark_node *root, int options, int width);`
sub cmark_render_latex( Node, int32, int32 ) returns Pointer[uint8] is native('cmark') is export { * }

#________________________________________________Version-information__________________________________________________________#
#| The library version as integer for runtime checks
#| | `int cmark_version(void)`
sub cmark_version(--> int32) is native('cmark') is export { * }

#| The library version string for runtime checks.
#| | `const char * cmark_version_string(void)`
sub cmark_version_string(--> Str) is native('cmark') is export { * }

#________________________________________________Parsing__________________________________________________________#

#| Creates a new parser object.
#| | `cmark_parser * cmark_parser_new(int options)`
sub cmark_parser_new( int32 ) returns Parser is native('cmark') is export { * }

#| Frees memory allocated for a parser object.
#| | `void cmark_parser_free(cmark_parser *parser)`
sub cmark_parser_free( Parser ) is native('cmark') is export { * }

#| Feeds a string of length 'len' to 'parser'.
#| | `void cmark_parser_feed(cmark_parser *parser, const char *buffer, size_t len)`
sub cmark_parser_feed( Parser, Str is encoded('utf8'), size_t ) is native('cmark') is export { * }

#| Finish parsing and return a pointer to a tree of nodes.
#| | `cmark_node * cmark_parser_finish(cmark_parser *parser)`
sub cmark_parser_finish( Parser ) returns Node is native('cmark') is export { * }


sub cmark_parse_document(Str is encoded('utf8'), size_t, int32) returns Node is native('cmark') is export { * }

#| Convert 'text' (assumed UTF-8) directly to an HTML string. Returns a caller-
#| owned malloc'd char* — route it through cstr-to-str-free, as the render subs do.
#| | `char *cmark_markdown_to_html(const char *text, size_t len, int options)`
sub cmark_markdown_to_html(Str is encoded('utf8'), size_t, int32) returns Pointer[uint8] is native('cmark') is export { * }
#________________________________________________Tree-Manipulation__________________________________________________________#

#| Unlinks a 'node', removing it from the tree, but not freeing its memory. (Use 'cmark_node_free' for that.)
#| | `void cmark_node_unlink(cmark_node *node)`
sub cmark_node_unlink( Node ) is native('cmark') is export { * }

#| Inserts 'sibling' before 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_insert_before(cmark_node *node, cmark_node *sibling)`
sub cmark_node_insert_before( Node, Node ) returns int32 is native('cmark') is export { * }

#| Inserts 'sibling' after 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_insert_after(cmark_node *node, cmark_node *sibling)`
sub cmark_node_insert_after( Node, Node ) returns int32 is native('cmark') is export { * }

#| Replaces 'oldnode' with 'newnode' and unlinks 'oldnode' (but does not free its memory). Returns 1 on success, 0 on failure.
#| | `int cmark_node_replace(cmark_node *oldnode, cmark_node *newnode)`
sub cmark_node_replace( Node, Node ) returns int32 is native('cmark') is export { * }

#| Adds 'child' to the beginning of the children of 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_prepend_child(cmark_node *node, cmark_node *child)`
sub cmark_node_prepend_child( Node, Node ) returns int32 is native('cmark') is export { * }

#| Adds 'child' to the end of the children of 'node'. Returns 1 on success, 0 on failure.
#| | `int cmark_node_append_child(cmark_node *node, cmark_node *child)`
sub cmark_node_append_child( Node, Node ) returns int32 is native('cmark') is export { * }

#| Consolidates adjacent text nodes.
#| | `void cmark_consolidate_text_nodes(cmark_node *root)`
sub cmark_consolidate_text_nodes( Node ) is native('cmark') is export { * }
