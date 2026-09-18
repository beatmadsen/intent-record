require "fileutils"
require "tmpdir"

# A test that makes a directory has to remove it again, and writing that removal
# by hand at every site is how one of them came to remove the author's real
# store. Ask for a directory here and it is cleaned up for you, so no test needs
# to name a path it is about to delete.
module TempDirs
  def temp_dir(purpose)
    @temp_dirs ||= []
    Dir.mktmpdir("intent-record-#{purpose}-").tap { |dir| @temp_dirs << dir }
  end

  def after_teardown
    super
    Array(@temp_dirs).each { |dir| FileUtils.rm_rf(dir) }
  end
end

Minitest::Test.include(TempDirs)
