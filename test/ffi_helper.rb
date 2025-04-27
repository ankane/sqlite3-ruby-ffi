class SQLite3::TestCase
  def before_setup
    mac = RbConfig::CONFIG["host_os"] =~ /darwin/i

    skip_tests = []
    # version provided by macOS does not have extension support
    skip_tests << "SQLite3::TestDatabase#test_load_extension_is_defined_on_expected_platforms" if mac
    # only fails locally
    skip_tests << "SQLite3::TestDiscardDatabase#test_fork_does_not_discard_readonly_connections" if mac && !ENV["CI"]
    # not needed when stress testing
    skip_tests << "SQLite3::TestDatabase#test_function_gc_segfault" if stress?
    skip if skip_tests.include?("#{self.class.name}##{name}")

    GC.stress = true if stress?
    super
  end

  def after_teardown
    GC.stress = false if stress?
    super
  end

  def stress?
    ENV["STRESS"]
  end
end
