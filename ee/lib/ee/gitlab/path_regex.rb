# frozen_string_literal: true

module EE
  module Gitlab
    module PathRegex
      extend ActiveSupport::Concern

      # OCI (Open Container Initiative) regexes for Container Virtual Registry
      # https://github.com/opencontainers/distribution-spec/blob/main/spec.md
      OCI_TAG_REGEX = /[a-zA-Z0-9_][a-zA-Z0-9._-]{0,127}/
      OCI_DIGEST_REGEX = /sha256:[a-f0-9]{64}/

      # https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests
      OCI_TAG_OR_DIGEST_REGEX = /(?:#{OCI_TAG_REGEX.source}|#{OCI_DIGEST_REGEX.source})/

      # https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-blobs
      # Accepts various digest formats:
      # - sha256 with any length: sha256:[hex chars]
      # - Other algorithms: md5:..., sha512:..., etc.
      OCI_BLOB_DIGEST_REGEX = /(?:sha256:[a-f0-9]+|[a-zA-Z0-9][a-zA-Z0-9+.-]*:[a-zA-Z0-9]+)/

      class_methods do
        def saml_callback_regex
          @saml_callback_regex ||= %r{\A\/groups\/(?<group>#{full_namespace_route_regex})\/\-\/saml\/callback\z}
        end

        def oci_tag_regex
          @oci_tag_regex ||= OCI_TAG_REGEX
        end

        def oci_digest_regex
          @oci_digest_regex ||= OCI_DIGEST_REGEX
        end

        def oci_tag_or_digest_regex
          @oci_tag_or_digest_regex ||= OCI_TAG_OR_DIGEST_REGEX
        end

        def oci_blob_digest_regex
          @oci_blob_digest_regex ||= OCI_BLOB_DIGEST_REGEX
        end
      end
    end
  end
end
