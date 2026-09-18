require "test_helper"

class StakeholderNormalizerSystemNameTest < Minitest::Test
  Normalizer = IntentRecord::StakeholderNormalizer

  def test_trims_and_lowercases_the_name
    assert_equal "jira", Normalizer.system_name("  JIRA ")
  end

  def test_joins_inner_whitespace_and_underscores_with_a_single_hyphen
    assert_equal "azure-devops", Normalizer.system_name("Azure _ DevOps")
  end
end

class StakeholderNormalizerUriTest < Minitest::Test
  Normalizer = IntentRecord::StakeholderNormalizer

  def test_downcases_scheme_and_host_but_keeps_path_case
    assert_equal "https://acme.atlassian.net/browse/ACME-42",
                 Normalizer.uri("HTTPS://ACME.Atlassian.NET/browse/ACME-42")
  end

  def test_drops_a_trailing_slash
    assert_equal "https://acme.example/wiki", Normalizer.uri("https://acme.example/wiki/")
  end

  def test_downcases_the_host_of_a_scheme_relative_uri
    assert_equal "//acme.example/browse/ACME-42", Normalizer.uri("//ACME.Example/browse/ACME-42")
  end

  def test_keeps_an_opaque_identifier_as_written
    assert_equal "ACME-42", Normalizer.uri("  ACME-42  ")
  end

  def test_keeps_an_unparseable_value_as_written
    assert_equal "http://acme example/x", Normalizer.uri("http://acme example/x")
  end
end
