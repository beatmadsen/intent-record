require "test_helper"

# Reading `git blame --porcelain` into the lines the command takes.
#
# The JSON shape is the contract and this is a convenience, so that blaming a
# file from a git repository is one command rather than one command and a
# converter. Keeping it a separate reader is what stops the store learning
# anything about git: it produces the same payload a person could have written.
class BlamePorcelainTest < Minitest::Test
  Subject = IntentRecord::Blame::Porcelain
  SHA = "d88d771a9870e616fb425c6c50b3e9de9e732d31".freeze
  OTHER = "cf319aaeec43d29ed985044747e7314a87063036".freeze

  def lines(text)
    Subject.lines(text)
  end

  # The header is "<sha> <line in the original file> <line in this file> [<how
  # many follow>]". It is the second number that a reader is asking about.
  def test_a_header_gives_the_line_number_in_the_file_being_read
    assert_equal [{ "line" => 7, "external_id" => SHA }], lines("#{SHA} 3 7 1\n\tsome code\n")
  end

  def test_the_metadata_after_a_header_is_not_mistaken_for_lines
    text = "#{SHA} 3 7 1\nauthor Erik\nsummary Add the thing\nfilename README.md\n\tsome code\n"

    assert_equal([7], lines(text).map { |l| l["line"] })
  end

  # Only the first mention of a commit carries metadata, so later ones are a
  # header and its content line alone.
  def test_a_commit_mentioned_again_is_read_from_its_bare_header
    text = "#{SHA} 3 7 1\nauthor Erik\n\tfirst\n#{SHA} 4 8\n\tsecond\n"

    assert_equal([7, 8], lines(text).map { |l| l["line"] })
  end

  def test_a_boundary_commit_is_read_like_any_other
    assert_equal [{ "line" => 1, "external_id" => SHA }], lines("#{SHA} 1 1 2\nboundary\n\tcode\n")
  end

  # A repository created with the sha256 object format prints 64-character ids.
  def test_a_sixty_four_character_id_is_read
    id = "f" * 64

    assert_equal [{ "line" => 2, "external_id" => id }], lines("#{id} 2 2 1\n\tcode\n")
  end

  def test_each_commit_keeps_its_own_lines
    text = "#{SHA} 1 1 1\n\ta\n#{OTHER} 1 2 1\n\tb\n"

    assert_equal([SHA, OTHER], lines(text).map { |l| l["external_id"] })
  end

  # A content line is prefixed with a tab, so a file whose own content looks like
  # a blame header is still read as content.
  def test_content_that_looks_like_a_header_is_still_content
    text = "#{SHA} 1 1 1\n\t#{OTHER} 9 9 9\n"

    assert_equal [{ "line" => 1, "external_id" => SHA }], lines(text)
  end

  def test_output_with_no_header_at_all_is_refused
    assert_raises(IntentRecord::ValidationError) { lines("not blame output\n") }
  end
end
