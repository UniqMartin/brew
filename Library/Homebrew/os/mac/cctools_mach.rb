module CctoolsMachO
  # @private
  OTOOL_RX = /\t(.*) \(compatibility version (?:\d+\.)*\d+, current version (?:\d+\.)*\d+\)/

  # Mach-O binary methods, see:
  # /usr/include/mach-o/loader.h
  # /usr/include/mach-o/fat.h
  # @private
  def mach_data
    @mach_data ||= begin
      offsets = []
      mach_data = []

      header = read(8).unpack("N2")
      case header[0]
      when 0xcafebabe # universal
        header[1].times do |i|
          # header[1] is the number of struct fat_arch in the file.
          # Each struct fat_arch is 20 bytes, and the 'offset' member
          # begins 8 bytes into the struct, with an additional 8 byte
          # offset due to the struct fat_header at the beginning of
          # the file.
          offsets << read(4, 20*i + 16).unpack("N")[0]
        end
      when 0xcefaedfe, 0xcffaedfe, 0xfeedface, 0xfeedfacf # Single arch
        offsets << 0
      else
        raise "Not a Mach-O binary."
      end

      offsets.each do |offset|
        mach_header = read(16, offset).unpack("N4")

        arch = case mach_header[0..1]
        when [0xcefaedfe, 0x07000000] then :i386
        when [0xcffaedfe, 0x07000001] then :x86_64
        when [0xfeedface, 0x00000012] then :ppc7400
        when [0xfeedfacf, 0x01000012] then :ppc64
        else
          case mach_header[0]
          when 0xcefaedfe, 0xcffaedfe, 0xfeedface, 0xfeedfacf
            # Mach-O magic, but unrecognized architecture (e.g. ARM/ARM64).
            :dunno
          else
            # Multi-architecture static archive (fat header, but not Mach-O).
            raise "Not a Mach-O binary."
          end
        end

        type = case mach_header[3]
        when 0x00000002, 0x02000000 then :executable
        when 0x00000006, 0x06000000 then :dylib
        when 0x00000008, 0x08000000 then :bundle
        else :dunno
        end

        mach_data << { :arch => arch, :type => type }
      end
      mach_data
    rescue
      []
    end
  end

  # @private
  class Metadata
    attr_reader :path, :dylib_id, :dylibs

    def initialize(path)
      @path = path
      @dylib_id, @dylibs = parse_otool_L_output
    end

    def parse_otool_L_output
      args = ["-L", path.expand_path.to_s]
      libs = Utils.popen_read(OS::Mac.otool, *args).split("\n")
      unless $?.success?
        raise ErrorDuringExecution.new(OS::Mac.otool, args)
      end

      libs.shift # first line is the filename

      id = libs.shift[OTOOL_RX, 1] if path.dylib?
      libs.map! { |lib| lib[OTOOL_RX, 1] }.compact!

      return id, libs
    end
  end

  # @private
  def mach_metadata
    @mach_metadata ||= Metadata.new(self)
  end

  # Returns an array containing all dynamically-linked libraries, based on the
  # output of otool. This returns the install names, so these are not guaranteed
  # to be absolute paths.
  # Returns an empty array both for software that links against no libraries,
  # and for non-mach objects.
  # @private
  def dynamically_linked_libraries
    mach_metadata.dylibs
  end

  # @private
  def dylib_id
    mach_metadata.dylib_id
  end
end
