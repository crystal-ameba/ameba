module Ameba
  VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
  GIT_SHA = {{ `(git rev-parse --short HEAD || true) 2>/dev/null`.chomp.stringify }}.presence
end
