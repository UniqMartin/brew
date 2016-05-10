raise "#{__FILE__} cannot be loaded directly." unless defined? Homebrew::Diagnostic

if OS.mac?
  require "extend/os/mac/diagnostic"
end
