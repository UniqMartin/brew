require "os/mac/shared_mach"

class Pathname
  if ENV["HOMEBREW_CHECKED_RUBY_MACHO"]
    require "os/mac/checked_ruby_mach"
    include CheckedRubyMachO
  elsif ENV["HOMEBREW_RUBY_MACHO"]
    require "os/mac/ruby_mach"
    include RubyMachO
  else
    require "os/mac/cctools_mach"
    include CctoolsMachO
  end

  include SharedMachO
end
