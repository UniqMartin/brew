raise "#{__FILE__} cannot be loaded directly." unless defined? Hardware::CPU

if OS.mac?
  require "extend/os/mac/hardware/cpu"
elsif OS.linux?
  require "extend/os/linux/hardware/cpu"
end
