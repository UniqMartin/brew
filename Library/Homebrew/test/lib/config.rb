require "tmpdir"
require "pathname"

HOMEBREW_BREW_FILE = Pathname.new(ENV["HOMEBREW_BREW_FILE"])

TEST_TMPDIR = ENV.fetch("HOMEBREW_TEST_TMPDIR") do |k|
  dir = Dir.mktmpdir("homebrew-tests-", ENV["HOMEBREW_TEMP"] || "/tmp")
  at_exit { FileUtils.remove_entry(dir) }
  ENV[k] = dir
end

# Paths pointing into the Homebrew code base that persist across test runs
HOMEBREW_LIBRARY_PATH  = Pathname.new(File.expand_path("../../..", __FILE__))
HOMEBREW_SHIMS_PATH    = HOMEBREW_LIBRARY_PATH.parent+"Homebrew/shims"
HOMEBREW_LOAD_PATH     = [File.expand_path("..", __FILE__), HOMEBREW_LIBRARY_PATH].join(":")

# Paths redirected to a temporary directory and wiped at the end of the test run
HOMEBREW_PREFIX        = Pathname.new(TEST_TMPDIR).join("prefix")
HOMEBREW_REPOSITORY    = HOMEBREW_PREFIX
HOMEBREW_LIBRARY       = HOMEBREW_REPOSITORY+"Library"
HOMEBREW_CACHE         = HOMEBREW_PREFIX.parent+"cache"
HOMEBREW_CACHE_FORMULA = HOMEBREW_PREFIX.parent+"formula_cache"
HOMEBREW_LOCK_DIR      = HOMEBREW_PREFIX.parent+"locks"
HOMEBREW_CELLAR        = HOMEBREW_PREFIX.parent+"cellar"
HOMEBREW_LOGS          = HOMEBREW_PREFIX.parent+"logs"
HOMEBREW_TEMP          = HOMEBREW_PREFIX.parent+"temp"

# Checksum used in `testball` formula (needs to be here for global visibility)
TESTBALL_SHA256 = "91e3f7930c98d7ccfb288e115ed52d06b0e5bc16fec7dce8bdda86530027067b".freeze
