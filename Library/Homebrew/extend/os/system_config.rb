raise "#{__FILE__} cannot be loaded directly." unless defined? SystemConfig

if OS.mac?
  require "extend/os/mac/system_config"
end
