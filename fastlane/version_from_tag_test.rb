require "minitest/autorun"
require_relative "version_from_tag"

class VersionFromTagTest < Minitest::Test
  def test_parses_tags
    assert_equal ["1.5.0", 10_500], VersionFromTag.parse("v1.5.0")
    assert_equal ["1.10.3", 11_003], VersionFromTag.parse("v1.10.3")
  end

  def test_build_flags
    assert_equal "--build-name=1.5.0 --build-number=10500", VersionFromTag.build_flags("v1.5.0")
  end

  def test_rejects_other_forms
    ["v1.100.0", "v1.0.100", "1.5.0", "v1.5", "v1.5.0-rc1", "v01.5.0", "v1.05.007", "v0.0.0", "", nil].each do |tag|
      assert_raises(ArgumentError, tag.inspect) { VersionFromTag.parse(tag) }
    end
  end
end
