require "../../../spec_helper"

module Ameba::AST
  describe MacroReferenceFinder do
    describe "#references?" do
      {
        "{{ foo }}",
        "{{ foo.id }}",
        "{{ [foo] }}",
        %({{ "foo".id }}),
        "{% if foo != 1 %}{% end %}",
        "{% if foo!=1 %}{% end %}",
        "{% for x in foo %}{% end %}",
        "{% if true %}{% else %}{{ foo }}{% end %}",
        "{% begin %}\n  # comment\n  foo\n{% end %}",
        "{% begin %}\n  bar # comment\n  foo\n{% end %}",
        "{% begin %}\n  # {{ foo }}\n{% end %}",
        %({% begin %}\n  "\#{foo}"\n{% end %}),
        %({% begin %}\n  "{{ 1 }}\#{foo}"\n{% end %}),
        %({% begin %}\n  "\#{ {a: foo}[:a] }"\n{% end %}),
        %({% begin %}\n  "{{ foo }}"\n{% end %}),
        %({% begin %}\n  "bar" + foo\n{% end %}),
        %({% begin %}\n  '"'; foo\n{% end %}),
        %({% begin %}\n  {foo: foo}\n{% end %}),
        %({% begin %}\n  bar ? foo : baz\n{% end %}),
        %({% begin %}\n  bar ? baz : foo\n{% end %}),
        %({% begin %}\n  Bar::Baz.foo\n{% end %}),
        "{% begin %}\n  a = b.c? / 2\n  d = foo / 3\n{% end %}",
        "{% begin %}\n  a = b.c! / 2\n  d = foo / 3\n{% end %}",
        "{% begin %}\n  a = b ? /c/ : foo\n{% end %}",
        "{% if bar %}# baz{% else %}foo{% end %}",
        "{% if bar %}\"baz{% else %}foo{% end %}",
        "{% if bar %}<<-EOS\n{% else %}foo{% end %}",
        "{% begin %}\n  bar '\n  foo\n{% end %}",
        "{% begin %}\n  `echo \#{foo}`\n{% end %}",
        "{% begin %}\n  `echo` + foo\n{% end %}",
        "{% begin %}\n  bar % foo\n{% end %}",
        "{% begin %}\n  bar / foo\n{% end %}",
        "{% begin %}\n  bar/foo\n{% end %}",
        "{% begin %}\n  bar /= foo\n{% end %}",
        "{% begin %}\n  bar // foo\n{% end %}",
        "{% begin %}\n  (bar) / foo / 2\n{% end %}",
        "{% begin %}\n  {{ bar }} / foo / 2\n{% end %}",
        "{% begin %}\n  \"bar\" % foo\n{% end %}",
        "{% begin %}\n  %(\#{foo})\n{% end %}",
        "{% begin %}\n  %Q[\#{foo}]\n{% end %}",
        "{% begin %}\n  %(a(b)c) + foo\n{% end %}",
        "{% begin %}\n  %w(a b) + foo\n{% end %}",
        "{% begin %}\n  /\#{foo}/\n{% end %}",
        "{% begin %}\n  %r{\#{foo}}\n{% end %}",
        "{% begin %}\n  /bar/i + foo\n{% end %}",
        "{% begin %}\n  bar(<<-EOS, foo)\n    baz\n    EOS\n{% end %}",
        "{% begin %}\n  <<-EOS\n    \#{foo}\n    EOS\n{% end %}",
        "{% begin %}\n  <<-EOS\n    bar\n    EOS\n  foo\n{% end %}",
        "{% begin %}\n  <<-EOS # bar\n    baz\n    EOS\n  foo\n{% end %}",
        "{% begin %}\n  <<-EOS\n    EOSX\n    EOS\n  foo\n{% end %}",
        "{% begin %}\n  bar << foo\n{% end %}",
        "{% begin %}\n  bar <<-1 + foo\n{% end %}",
      }.each do |code|
        it "returns true for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroReferenceFinder.new(node, "foo").references?.should be_true
        end
      end

      {
        "{{ bar }}",
        "{{ foo_bar }}",
        "{{ bar_foo }}",
        "{{ food }}",
        "{{ @foo }}",
        "{{ foo? }}",
        "{{ foo! }}",
        "{{ fooé }}",
        "{% begin %}\n  # foo\n{% end %}",
        "{% begin %}\n  bar # foo\n{% end %}",
        "{% begin %}\n  # bar {baz} foo\n{% end %}",
        "{% begin %}\n  # bar {{ baz }} foo\n{% end %}",
        "{% for x in [1] %}\n  # foo\n{% end %}",
        "{% if true %}\n  # foo\n{% else %}\n  # foo\n{% end %}",
        "{% begin %}\n  \#{foo}\n{% end %}",
        %({% begin %}\n  "foo"\n{% end %}),
        %({% begin %}\n  "bar foo baz"\n{% end %}),
        %({% begin %}\n  "bar \\" foo"\n{% end %}),
        %({% begin %}\n  "{{ bar }} foo"\n{% end %}),
        %({% begin %}\n  "\#{"foo"}"\n{% end %}),
        %({% begin %}\n  :foo\n{% end %}),
        %({% begin %}\n  :foo?\n{% end %}),
        %({% begin %}\n  :"foo"\n{% end %}),
        %({% begin %}\n  {:foo => 1}\n{% end %}),
        %({% begin %}\n  bar(:foo)\n{% end %}),
        %({% begin %}\n  'f'\n{% end %}),
        "{% begin %}\n  `echo foo`\n{% end %}",
        "{% begin %}\n  %x(echo foo)\n{% end %}",
        "{% begin %}{% if bar %}\"{% else %}\"{% end %}foo\"{% end %}",
        "{% begin %}\n  %(foo)\n{% end %}",
        "{% begin %}\n  %[foo]\n{% end %}",
        "{% begin %}\n  %{foo}\n{% end %}",
        "{% begin %}\n  %<foo>\n{% end %}",
        "{% begin %}\n  %|foo|\n{% end %}",
        "{% begin %}\n  %(a(b)foo)\n{% end %}",
        "{% begin %}\n  %(a\\)foo)\n{% end %}",
        "{% begin %}\n  %q(foo)\n{% end %}",
        "{% begin %}\n  %q(\#{foo})\n{% end %}",
        "{% begin %}\n  %Q(foo)\n{% end %}",
        "{% begin %}\n  %w(bar foo)\n{% end %}",
        "{% begin %}\n  %i(bar foo)\n{% end %}",
        "{% begin %}\n  %r(foo)\n{% end %}",
        "{% begin %}\n  %x(foo)\n{% end %}",
        "{% begin %}\n  bar %(foo)\n{% end %}",
        "{% begin %}\n  bar = %(foo)\n{% end %}",
        "{% begin %}\n  /foo/\n{% end %}",
        "{% begin %}\n  /bar\\/foo/\n{% end %}",
        "{% begin %}\n  bar(/foo/)\n{% end %}",
        "{% begin %}\n  bar =~ /foo/\n{% end %}",
        "{% begin %}\n  bar /foo/\n{% end %}",
        "{% begin %}\n  bar = /foo/i\n{% end %}",
        "{% begin %}\n  <<-EOS\n    foo\n    EOS\n{% end %}",
        "{% begin %}\n  <<-'EOS'\n    \#{foo}\n    EOS\n{% end %}",
        "{% begin %}\n  bar(<<-A, <<-B)\n    foo\n    A\n    foo\n    B\n{% end %}",
        "{% begin %}\n  <<-EOS\n    {{ bar }} foo\n    EOS\n{% end %}",
        "{% begin %}\n  <<-EOS\n    \#{\"foo\"}\n    EOS\n{% end %}",
      }.each do |code|
        it "returns false for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroReferenceFinder.new(node, "foo").references?.should be_false
        end
      end

      it "skips regex options" do
        node = Crystal::Parser.new("{% begin %}\n  /foo/imx\n{% end %}").parse
        MacroReferenceFinder.new(node, "imx").references?.should be_false
      end

      {
        "{% begin %}\n  '{{ bar }}' + foo\n{% end %}",
        "{% begin %}\n  \"\\{{ bar }}\" + foo\n{% end %}",
        "{% begin %}\n  %{{ bar }} + foo\n{% end %}",
      }.each do |code|
        it "handles literals split by macro nodes in #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroReferenceFinder.new(node, "foo").references?.should be_true
        end
      end
    end
  end
end
