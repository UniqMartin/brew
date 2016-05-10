raise "#{__FILE__} cannot be loaded directly." unless defined? DevelopmentTools

if OS.mac?
  require "extend/os/mac/development_tools"
end
