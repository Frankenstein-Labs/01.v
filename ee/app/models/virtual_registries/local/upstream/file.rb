# frozen_string_literal: true

module VirtualRegistries
  module Local
    module Upstream
      class File
        include ActiveModel::API

        INVALID_RAW_FILE_TYPE_ERROR = 'Input needs to be an instance of ::Packages::PackageFile'

        attr_accessor :global_id, :raw_file_id, :file, :sha1, :md5

        delegate :content_type, to: :file, allow_nil: true

        validates :global_id, :file, :sha1, :md5, presence: true
        validates :sha1, format: { with: /\A[0-9a-f]{40}\z/i }
        validates :md5, format: { with: /\A[0-9a-f]{32}\z/i }

        def self.from_raw_local_file(local_file)
          raise ArgumentError, INVALID_RAW_FILE_TYPE_ERROR unless local_file.is_a?(::Packages::PackageFile)

          instance = new(
            global_id: local_file.to_global_id.to_s,
            raw_file_id: local_file.id,
            file: local_file.file,
            sha1: local_file.file_sha1,
            md5: local_file.file_md5
          )

          raise ArgumentError, instance.errors.full_messages.to_sentence unless instance.valid?

          instance
        end

        # file field is a carrierwave uploader instance. We need to exclude it
        # from object comparison as two carrierwave wrappers for the same underlying
        # file will not be equal.
        def eql?(other)
          return false unless other.is_a?(self.class)

          global_id == other.global_id && sha1 == other.sha1 && md5 == other.md5
        end

        alias_method :==, :eql?

        def hash
          [global_id, sha1, md5].hash
        end

        def digests
          { sha1:, md5: }
        end
      end
    end
  end
end
