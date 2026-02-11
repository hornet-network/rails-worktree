require "test_helper"

class CloseTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @main_worktree = File.join(@tmpdir, "main")
    FileUtils.mkdir_p(@main_worktree)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- drop_databases ---

  def test_drop_databases_uses_dropdb_with_correct_names
    close = build_close("my-feature", db_prefix: "myapp")

    system_calls = []
    close.define_singleton_method(:system) do |*args|
      system_calls << args
      true
    end

    close.send(:drop_databases)

    assert_equal 2, system_calls.length

    assert_equal ["dropdb", "--if-exists", "myapp_my-feature_development"], system_calls[0]
    assert_equal ["dropdb", "--if-exists", "myapp_my-feature_test"], system_calls[1]
  end

  def test_drop_databases_does_not_use_rails
    close = build_close("my-feature", db_prefix: "myapp")

    system_calls = []
    close.define_singleton_method(:system) do |*args|
      system_calls << args
      true
    end

    close.send(:drop_databases)

    system_calls.each do |call|
      args_str = call.map(&:to_s).join(" ")
      refute_includes args_str, "rails", "drop_databases should not invoke Rails"
    end
  end

  def test_drop_databases_warns_on_failure
    close = build_close("my-feature")

    close.define_singleton_method(:system) do |*args|
      false
    end

    output = capture_io { close.send(:drop_databases) }.first

    assert_includes output, "Warning: Could not drop development database"
    assert_includes output, "Warning: Could not drop test database"
  end

  # --- database name computation ---

  def test_database_names_use_prefix_and_worktree_name
    close = build_close("logging", db_prefix: "myapp")

    assert_equal "myapp_logging_development", close.instance_variable_get(:@dev_database_name)
    assert_equal "myapp_logging_test", close.instance_variable_get(:@test_database_name)
  end

  def test_database_names_with_hyphenated_worktree
    close = build_close("my-cool-feature", db_prefix: "myapp")

    assert_equal "myapp_my-cool-feature_development", close.instance_variable_get(:@dev_database_name)
    assert_equal "myapp_my-cool-feature_test", close.instance_variable_get(:@test_database_name)
  end

  # --- get_db_prefix ---

  def test_get_db_prefix_from_database_yml
    FileUtils.mkdir_p(File.join(@main_worktree, "config"))
    File.write(File.join(@main_worktree, "config/database.yml"), <<~YAML)
      development:
        database: valinor_development
    YAML

    close = build_close("logging")

    assert_equal "valinor", close.instance_variable_get(:@db_prefix)
    assert_equal "valinor_logging_development", close.instance_variable_get(:@dev_database_name)
    assert_equal "valinor_logging_test", close.instance_variable_get(:@test_database_name)
  end

  def test_get_db_prefix_falls_back_to_directory_name
    close = build_close("logging")

    assert_equal "main", close.instance_variable_get(:@db_prefix)
  end

  private

  def build_close(worktree_name, db_prefix: nil)
    close = RailsWorktree::Commands::Close.allocate

    # Stub git/filesystem dependencies
    close.instance_variable_set(:@worktree_name, worktree_name)
    close.instance_variable_set(:@main_worktree, @main_worktree)
    close.instance_variable_set(:@current_dir, @main_worktree)

    # Compute db prefix: use provided value or detect from main worktree
    db_prefix ||= close.send(:get_db_prefix)
    close.instance_variable_set(:@db_prefix, db_prefix)
    close.instance_variable_set(:@dev_database_name, "#{db_prefix}_#{worktree_name}_development")
    close.instance_variable_set(:@test_database_name, "#{db_prefix}_#{worktree_name}_test")

    close.send(:detect_paths)

    close
  end
end
