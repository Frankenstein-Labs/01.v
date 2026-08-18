# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::PathRegex, feature_category: :virtual_registry do
  describe '.oci_tag_regex' do
    subject { %r{\A#{described_class.oci_tag_regex}\z} }

    it { is_expected.to match('latest') }
    it { is_expected.to match('v1.2.3') }
    it { is_expected.to match('feature-branch') }
    it { is_expected.to match('feature_branch') }
    it { is_expected.to match('_internal') }
    it { is_expected.to match('v1.2.3-rc.1_build.123') }
    it { is_expected.to match('1.0') }
    it { is_expected.to match('_') }

    # Maximum length is 128 characters
    it { is_expected.to match('a' * 128) }
    it { is_expected.not_to match('a' * 129) }

    # Invalid tags
    it { is_expected.not_to match('-invalid') } # cannot start with hyphen
    it { is_expected.not_to match('.invalid') } # cannot start with period
    it { is_expected.not_to match('') } # cannot be empty
    it { is_expected.not_to match('tag with spaces') }
    it { is_expected.not_to match('tag/with/slash') }
  end

  describe '.oci_digest_regex' do
    subject { %r{\A#{described_class.oci_digest_regex}\z} }

    # Valid sha256 digests
    it { is_expected.to match("sha256:#{'a' * 64}") }
    it { is_expected.to match("sha256:#{'0' * 64}") }
    it { is_expected.to match('sha256:14119a10abf4669e8cdbdff324a9f9605d99697215a0d21c360fe8dfa8471bab') }

    # Invalid digests
    it { is_expected.not_to match("sha256:#{'a' * 63}") } # too short
    it { is_expected.not_to match("sha256:#{'a' * 65}") } # too long
    it { is_expected.not_to match("sha256:#{'A' * 64}") } # uppercase not allowed
    it { is_expected.not_to match("sha256:#{'g' * 64}") } # invalid hex character
    it { is_expected.not_to match("md5:#{'a' * 32}") } # wrong algorithm
    it { is_expected.not_to match('sha256:') } # missing hash
  end

  describe '.oci_tag_or_digest_regex' do
    subject { %r{\A#{described_class.oci_tag_or_digest_regex}\z} }

    # Valid tags
    it { is_expected.to match('latest') }
    it { is_expected.to match('v1.2.3') }
    it { is_expected.to match('feature-branch') }

    # Valid digests
    it { is_expected.to match("sha256:#{'a' * 64}") }
    it { is_expected.to match('sha256:14119a10abf4669e8cdbdff324a9f9605d99697215a0d21c360fe8dfa8471bab') }

    # Invalid
    it { is_expected.not_to match('-invalid') }
    it { is_expected.not_to match("sha256:#{'a' * 63}") }
    it { is_expected.not_to match("md5:#{'a' * 32}") }
  end

  describe '.oci_blob_digest_regex' do
    subject { %r{\A#{described_class.oci_blob_digest_regex}\z} }

    # Valid sha256 digests (any length for blobs)
    it { is_expected.to match("sha256:#{'a' * 64}") }
    it { is_expected.to match('sha256:14119a10abf4669e8cdbdff324a9f9605d99697215a0d21c360fe8dfa8471bab') }
    it { is_expected.to match('sha256:abc123def456') } # short form also valid for blobs
    it { is_expected.to match('sha256:abc') } # even shorter

    # md5 is not a registered algorithm but the spec says the regexp should accept it:
    # https://github.com/opencontainers/image-spec/blob/main/descriptor.md#digests
    # Implementations SHOULD allow digests with unrecognized algorithms to pass validation
    # if they comply with the above grammar.
    it { is_expected.to match('md5:abc123') }

    # Valid alternative digest formats (for blobs)
    it { is_expected.to match('sha512:abc123') }
    it { is_expected.to match('sha1:abc123') }
    it { is_expected.to match('algorithm+variant:hash') }

    # Invalid - must have algorithm and hash separated by colon
    it { is_expected.not_to match('sha256:') } # missing hash
    it { is_expected.not_to match(':nocolon') } # missing algorithm
    it { is_expected.not_to match('nohash:') } # missing hash
    it { is_expected.not_to match('') } # empty
  end
end
