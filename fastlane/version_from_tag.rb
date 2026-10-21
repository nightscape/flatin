# Derives the Flutter build flags of a release from its tag vX.Y.Z.
module VersionFromTag
  TAG_PATTERN = /\Av(\d+)\.(\d+)\.(\d+)\z/

  def self.tag_name
    ENV["GITHUB_REF_NAME"] || ENV["TAG_NAME"]
  end

  def self.parse(tag)
    match = TAG_PATTERN.match(tag.to_s)
    raise ArgumentError, "release tag must look like vX.Y.Z, got #{tag.inspect}" unless match
    major, minor, patch = match.captures.map(&:to_i)
    raise ArgumentError, "minor and patch of #{tag} must be below 100" if minor >= 100 || patch >= 100
    ["#{major}.#{minor}.#{patch}", major * 10_000 + minor * 100 + patch]
  end

  def self.build_flags(tag = tag_name)
    name, number = parse(tag)
    "--build-name=#{name} --build-number=#{number}"
  end
end

puts VersionFromTag.parse(VersionFromTag.tag_name) if $PROGRAM_NAME == __FILE__
