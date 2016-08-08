class Keg
  if ENV["HOMEBREW_CHECKED_RUBY_MACHO"]
    require "os/mac/checked_ruby_keg"
    include CheckedRubyKeg
  elsif ENV["HOMEBREW_RUBY_MACHO"]
    require "os/mac/ruby_keg"
    include RubyKeg
  else
    require "os/mac/cctools_keg"
    include CctoolsKeg
  end
end
