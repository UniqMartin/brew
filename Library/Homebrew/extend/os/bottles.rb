raise "#{__FILE__} cannot be loaded directly." unless defined? Utils::Bottles

if OS.mac?
  require "extend/os/mac/utils/bottles"
end
