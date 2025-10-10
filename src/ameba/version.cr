module Ameba
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
  {% if flag?(:windows) %}
    GIT_SHA = {{ `git rev-parse --short HEAD`.chomp.stringify }}.presence
  {% else %}
    GIT_SHA = {{ `(git rev-parse --short HEAD || true) 2>/dev/null`.chomp.stringify }}.presence
  {% end %}
end
