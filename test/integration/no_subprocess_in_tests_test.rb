require "test_helper"

# The confinement guards run in this process. A test that shelled out to the
# executable would get a fresh Ruby with none of them, landing wherever the
# inherited environment pointed, so the suite must contain no such call. Parsed
# rather than grepped, because most test files mention `backticks` in prose.
class NoSubprocessInTestsTest < Minitest::Test
  SPAWNING = %i[system spawn exec fork popen capture2 capture3 pipeline].freeze

  def test_no_test_spawns_a_subprocess
    assert_empty spawning_sites, "these would run outside the store confinement"
  end

  def test_the_check_can_see_a_subprocess_call
    found = sites_in(<<~RUBY)
      `ls`
      system("ls")
      Open3.capture3("ls")
    RUBY

    assert_equal %w[backticks system Open3.capture3], found.pluck(:name)
  end

  private

  def spawning_sites
    Dir[File.expand_path("../**/*.rb", __dir__)].flat_map do |path|
      sites_in(File.read(path)).map { |site| "#{relative(path)}:#{site[:line]} #{site[:name]}" }
    end
  end

  def relative(path)
    path.delete_prefix("#{File.expand_path("../..", __dir__)}/")
  end

  def sites_in(source)
    walk(RubyVM::AbstractSyntaxTree.parse(source))
  end

  def walk(node)
    children = node.children.grep(RubyVM::AbstractSyntaxTree::Node)
    [site_for(node)].compact + children.flat_map { |child| walk(child) }
  end

  def site_for(node)
    name = spawning_name(node)
    { line: node.first_lineno, name: name } if name
  end

  def spawning_name(node)
    return "backticks" if %i[XSTR DXSTR].include?(node.type)
    return nil unless %i[CALL FCALL].include?(node.type)

    called(node)
  end

  # FCALL has no receiver slot, so its first child is already the method name.
  def called(node)
    receiver, method = node.type == :FCALL ? [nil, node.children.first] : node.children
    return nil unless SPAWNING.include?(method)

    receiver ? "#{source_of(receiver)}.#{method}" : method.to_s
  end

  def source_of(node)
    node.type == :CONST ? node.children.first.to_s : node.type.to_s
  end
end
