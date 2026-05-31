# Cmark

[![test](https://github.com/khalidelborai/raku-cmark/actions/workflows/test.yml/badge.svg)](https://github.com/khalidelborai/raku-cmark/actions/workflows/test.yml)

### DESCRIPTION

Raku bindings to [cmark](https://github.com/commonmark/cmark), the CommonMark reference parser/renderer C library. Parse Markdown and render it to HTML, XML, man, LaTeX, or normalized CommonMark; walk the document AST; or stream input through an incremental parser.

This binds **stock cmark**: it follows the [CommonMark spec](https://commonmark.org) exactly, but does *not* include the GitHub-Flavored Markdown extensions (tables, strikethrough, task lists, autolinks, footnotes) — those live in the separate cmark-gfm library.

### INSTALL

**1. Install the cmark C library.** NativeCall loads it under the bare name `cmark`.

* **Linux** — `sudo apt-get install libcmark-dev` (Debian/Ubuntu) or `sudo dnf install cmark-devel` (Fedora). The `-dev`/`-devel` package ships the unversioned `libcmark.so` that NativeCall needs. (Or build from source: `git clone https://github.com/commonmark/cmark && cd cmark && make && make install`.)
* **macOS** — `brew install cmark`. On Apple-Silicon Homebrew this lands in `/opt/homebrew/lib`, which is **not** on NativeCall's default search path, so make it discoverable with a one-time symlink:
  ```sh
  sudo ln -sf "$(brew --prefix cmark)/lib/libcmark.dylib" /usr/local/lib/libcmark.dylib
  ```
* **Windows** — install [`vcpkg`](https://github.com/microsoft/vcpkg), run `vcpkg install cmark`, and add the package `bin` directory (e.g. `…\vcpkg\packages\cmark_x64-windows\bin`) to your `PATH`.

**2. Install the module.**

```sh
zef install Cmark
```

Or from a checkout:

```sh
git clone https://github.com/khalidelborai/raku-cmark.git
cd raku-cmark
zef install .
```
        

# Example

``` perl6
    use Cmark;
    my $options = CMARK_OPT_UNSAFE +| CMARK_OPT_SOURCEPOS  ;
    my $doc = Cmark.parse("# Header [hello](javascript:alert(1))",$options);
    say $doc.to-html();  # <h1 data-sourcepos="1:1-1:37">Header <a href="javascript:alert(1)">hello</a></h1>
```

## More examples

One-shot Markdown → HTML, without keeping a reusable document:

``` raku
use Cmark;
say Cmark.markdown-to-html("# Hello *world*").chomp;   # <h1>Hello <em>world</em></h1>
```

Walk the document tree (visits every node once, on entry):

``` raku
use Cmark;
my $doc = Cmark.parse("# Title\n\n- one\n- two\n");
$doc.walk(-> $node {
    say $node.type;                                    # a typed NodeType, e.g. CMARK_NODE_HEADING
    say "  text: {$node.text}" if $node.type == CMARK_NODE_TEXT;
});
```

Node/list/event kinds are exposed as typed enums (`NodeType`, `ListType`, `DelimType`, `EventType`), and nodes answer `is-block` / `is-inline` / `is-leaf`. Rendering a document before parsing (e.g. `Cmark.new.to-html`) throws a catchable `X::Cmark::NoNode` instead of crashing.

Stream input through an incremental parser (lower-level `Cmark::Native` API):

``` raku
use Cmark::Native;
my $parser = Parser.new(0);
$parser.feed("# Streamed\n\n");
$parser.feed("body text\n");
my $node = $parser.finish;                  # the caller owns the returned tree
say cstr-to-str-free(cmark_render_html($node, 0)).chomp;
cmark_node_free($node);                     # free it when done
```

## Class `Cmark` Methods

* ### multi method parse

    ```perl6
    multi method parse(
        Str $md,
        $options = 0
    ) returns Cmark
    ```
    
    takes the markdown as a Str and the parser options 
* ### multi method parse
    
    ```perl6
      multi method parse(
          IO $md,
          $options = 0
      ) returns Cmark
    ```
    takes the markdown file and passes it's content to the previous one

* ### version
    ```perl6
      method version ()
    ```
    returns the cmark vserion string
    
## OPTIONS

```perl6
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
```
* `CMARK_OPT_DEFAULT`    
    > Default options. 
* `CMARK_OPT_SOURCEPOS`
    > Include a `data-sourcepos` attribute on all block elements. 
* `CMARK_OPT_HARDBREAKS`
    > Render `softbreak` elements as hard line breaks. 
* `CMARK_OPT_SAFE`
    > `CMARK_OPT_SAFE` is defined here for API compatibility, but it no longer has any effect. "Safe" mode is now the default: set `CMARK_OPT_UNSAFE` to disable it. 
* `CMARK_OPT_UNSAFE`
    > Render raw HTML and unsafe links (`javascript:`, `vbscript:`, `file:`, and `data:`, except for `image/png`, `image/gif`, `image/jpeg`, or `image/webp` mime types). By default, raw HTML is replaced by a placeholder HTML comment. Unsafe links are replaced by empty strings. 
* `CMARK_OPT_NOBREAKS`
    > Render `softbreak` elements as spaces. 
* `CMARK_OPT_NORMALIZE`
    > Legacy option (no effect). 
* `CMARK_OPT_VALIDATE_UTF8`
    > Validate UTF-8 in the input before parsing, replacing illegal sequences with the replacement character U+FFFD. 
* `CMARK_OPT_SMART`
    > Convert straight quotes to curly, to em dashes, - to en dashes. 
    
## Doc Methods   

* ### to-html
    ```perl6
      method to-html (
          $options = $!options
      )
    ```
    Converts the parsed Markdown to html given the options (defaults to the options used with parse)

* ### to-xml
    ```perl6
      method to-xml (
          $options = $!options
      )
    ```
    Converts the parsed Markdown to xml given the options (defaults to the options used with parse)

* ### to-man
    ```perl6
      method to-man (
          $options = $!options,
          :$width = 0
      )
    ```
    Converts the parsed Markdown to man given the options (defaults to the options used with parse) and width

* ### to-commonmark
    ```perl6
      method to-commonmark (
          $options = $!options,
          :$width = 0
      )
    ```
    Converts the parsed Markdown to commnmark given the options (defaults to the options used with parse)  and width
* ### to-latex
    ```perl6
      method to-latex (
          $options = $!options,
          :$width = 0
      )
    ```
    Converts the parsed Markdown to latex given the options (defaults to the options used with parse)  and width


## TODO
* Surface the remaining node accessors as methods (`heading-level`, `fence-info`, source position)
* A GitHub-Flavored Markdown sibling binding (`cmark-gfm`)
* More documentation
