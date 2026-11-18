require "../../../spec_helper"

module Ameba::AST
  describe MacroReferenceFinder do
    describe "#references?" do
      {
        %({{ "foo".id }}),
        "{{ :foo.id }}",
        %({{ ["foo"].first.id }}),
        %({{ "bar(foo)".id }}),
        %({{ "foo.bar".id }}),
        %({{ ("a" + "foo").id }}),
        %({{ x.gsub(/x/, "foo").id }}),
        "{% for x in %w[foo] %}{% end %}",
        %({% if true %}{% else %}{{ "foo".id }}{% end %}),
        "{% begin %}\n  foo != 1\n{% end %}",
        "{% begin %}\n  foo!=1\n{% end %}",
        "{% begin %}\n  foo!~1\n{% end %}",
        "{% begin %}\n  # comment\n  foo\n{% end %}",
        "{% begin %}\n  bar # comment\n  foo\n{% end %}",
        %({% begin %}\n  # {{ "foo".id }}\n{% end %}),
        %({% begin %}\n  "\#{foo}"\n{% end %}),
        %({% begin %}\n  "{{ 1 }}\#{foo}"\n{% end %}),
        %({% begin %}\n  "\#{ {a: foo}[:a] }"\n{% end %}),
        %({% begin %}\n  "{{ :foo.id }}"\n{% end %}),
        %({% begin %}\n  "bar" + foo\n{% end %}),
        %({% begin %}\n  '"'; foo\n{% end %}),
        %({% begin %}\n  {foo: foo}\n{% end %}),
        %({% begin %}\n  bar ? foo : baz\n{% end %}),
        %({% begin %}\n  bar ? baz : foo\n{% end %}),
        %({% begin %}\n  Bar::Baz.bar(foo)\n{% end %}),
        %({{ "bar(baz: foo)".id }}),
        "{% begin %}\n  1..foo\n{% end %}",
        "{% begin %}\n  1...foo\n{% end %}",
        "{% begin %}\n  foo.bar\n{% end %}",
        "{% begin %}\n  foo\n    .bar\n{% end %}",
        "{% begin %}\n  bar.baz(foo)\n{% end %}",
        "{% begin %}\n  bar[foo]\n{% end %}",
        "{% begin %}\n  bar(baz: foo)\n{% end %}",
        "{% begin %}\n  bar baz: foo\n{% end %}",
        "{% begin %}\n  {foo => 1}\n{% end %}",
        "{% begin %}\n  foo::Bar\n{% end %}",
        "{% begin %}\n  {{ bar }}.baz(foo)\n{% end %}",
        "{% begin %}\n  define foo\n{% end %}",
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
        "{% begin %}\n  def /(other)\n    foo / other\n  end\n{% end %}",
        "{% begin %}\n  def `(command)\n    foo\n  end\n{% end %}",
        "{% begin %}\n  bar.reduce(:/)\n  foo / 2\n{% end %}",
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
        "{{ foo }}",
        "{{ foo.id }}",
        "{{ [foo] }}",
        "{{ bar(foo) }}",
        "{{ foo.bar }}",
        "{% if foo != 1 %}{% end %}",
        "{% for x in foo %}{% end %}",
        "{% if true %}{% else %}{{ foo }}{% end %}",
        "{% begin %}\n  # {{ foo }}\n{% end %}",
        %({{ "bar.foo".id }}),
        %({{ "bar(foo: 1)".id }}),
        "{{ :bar.id }}",
        "{% if flag?(:foo) %}{% end %}",
        "{% if @type.has_method?(:foo) %}{% end %}",
        %({% if x == "foo" %}{% end %}),
        %({% if "foo".id == x %}{% end %}),
        %({% if "foo" != x || x =~ /foo/ %}{% end %}),
        "{% begin %}\n  bar.foo\n{% end %}",
        "{% begin %}\n  bar&.foo\n{% end %}",
        "{% begin %}\n  Bar.foo\n{% end %}",
        "{% begin %}\n  bar.foo?\n{% end %}",
        "{% begin %}\n  bar.foo = 1\n{% end %}",
        "{% begin %}\n  bar\n    .foo\n{% end %}",
        "{% begin %}\n  bar.map(&.foo)\n{% end %}",
        "{% begin %}\n  {{ bar }}.foo\n{% end %}",
        "{% begin %}\n  def foo; end\n{% end %}",
        "{% begin %}\n  def self.foo; end\n{% end %}",
        "{% begin %}\n  macro foo; end\n{% end %}",
        "{% begin %}\n  bar(foo: 1)\n{% end %}",
        "{% begin %}\n  bar foo: 1\n{% end %}",
        "{% begin %}\n  {foo: 1}\n{% end %}",
        "{% begin %}\n  {bar: 1, foo: 2}\n{% end %}",
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

    context "within macro definitions" do
      {
        "macro bar\n  puts foo\nend",
        "macro bar(foo)\n  puts foo\nend",
        "macro bar\n  {{ \"foo\".id }}\nend",
        "macro bar\n  {% for x in %w[foo] %}{{ x.id }}{% end %}\nend",
      }.each do |code|
        it "returns true for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroReferenceFinder.new(node, "foo").references?.should be_true
        end
      end

      {
        "macro bar(foo)\n  {{ foo }}\nend",
        "macro bar(*foo, **baz, &qux)\n  {{ foo }} {{ baz }} {{ qux.body }}\nend",
        "macro bar\n  {% for foo in [1] %}{{ foo }}{% end %}\nend",
        "macro bar\n  {% foo = 1 %}{{ foo }}\nend",
      }.each do |code|
        it "returns false for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroReferenceFinder.new(node, "foo").references?.should be_false
        end
      end
    end
  end
end
