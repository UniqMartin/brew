require "os/mac/checked_helper"
require "os/mac/cctools_mach"
require "os/mac/ruby_mach"

module CheckedRubyMachO
  include CheckedHelper

  def mach_data
    @mach_data ||= begin
      rb = self_rb.mach_data
      cc = self_cc.mach_data
      macho_fail("Pathname#mach_data", cc, rb) if rb != cc
      cc
    end
  end

  def dynamically_linked_libraries
    @dynamically_linked_libraries ||= begin
      rb = self_rb.dynamically_linked_libraries
      cc = self_cc.dynamically_linked_libraries
      macho_fail("Pathname#dynamically_linked_libraries", cc, rb) if rb != cc
      cc
    end
  end

  def dylib_id
    @dylib_id ||= begin
      rb = self_rb.dylib_id
      cc = self_cc.dylib_id
      macho_fail("Pathname#dylib_id", cc, rb) if rb != cc
      cc
    end
  end

  private

  def self_cc
    @self_cc ||= dup.extend(CctoolsMachO)
  end

  def self_rb
    @self_rb ||= dup.extend(RubyMachO)
  end
end
