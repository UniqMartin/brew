require "os/mac/checked_helper"
require "os/mac/cctools_keg"
require "os/mac/ruby_keg"

module CheckedRubyKeg
  include CheckedHelper

  def change_dylib_id(id, file)
    log_relocate(:checked, file, :id_dylib, :old => file.dylib_id, :new => id)
    puts "Changing dylib ID of #{file}\n  from #{file.dylib_id}\n    to #{id}" if ARGV.debug?

    rb_backup = file.read
    self_rb.change_dylib_id(id, file)
    rb = file.sha256
    file.open("wb") { |io| io.write(rb_backup) }

    self_cc.change_dylib_id(id, file)
    cc = file.sha256

    macho_fail("Keg#change_dylib_id", cc, rb) if rb != cc
  end

  def change_install_name(old, new, file)
    log_relocate(:checked, file, :load_dylib, :old => old, :new => new)
    puts "Changing install name in #{file}\n  from #{old}\n    to #{new}" if ARGV.debug?

    rb_backup = file.read
    self_rb.change_install_name(old, new, file)
    rb = file.sha256
    file.open("wb") { |io| io.write(rb_backup) }

    self_cc.change_install_name(old, new, file)
    cc = file.sha256

    macho_fail("Keg#change_install_name", cc, rb) if rb != cc
  end

  def require_install_name_tool?
    self_cc.require_install_name_tool?
  end

  private

  class KegRedirector
    def initialize(keg)
      @keg = keg
    end

    def log_relocate(*args)
      # Logging requires the 'um/log-relocate' patch.
      @keg.log_relocate(*args) if @keg.respond_to?(:log_relocate)
    end
  end

  def self_cc
    @self_cc ||= KegRedirector.new(self).extend(CctoolsKeg)
  end

  def self_rb
    @self_rb ||= KegRedirector.new(self).extend(RubyKeg)
  end
end
