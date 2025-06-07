class SQLite3::TestCase
  def before_setup
    skip_tests = []
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
