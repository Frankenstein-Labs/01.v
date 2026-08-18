# frozen_string_literal: true

module PackageMetadata
  # Tracks the last synced position for supported types of package metadata
  # (advisories, licenses, etc) uniquedly defined by data_type, version_format,
  # purl_type.
  class Checkpoint < ApplicationRecord
    enum :purl_type, ::Enums::Sbom.purl_types
    enum :data_type, ::Enums::PackageMetadata.data_types
    enum :version_format, ::Enums::PackageMetadata.version_formats

    validates :data_type, presence: true
    validates :version_format, presence: true
    validates :sequence, presence: true, numericality: { only_integer: true }
    validates :chunk, presence: true, numericality: { only_integer: true }
    validates :purl_type, presence: true, uniqueness: { scope: [:data_type, :version_format] }

    scope :advisory_purl_type_sequences, -> {
      where(data_type: 'advisories', version_format: 'v2').to_h { |c| [c.purl_type, c.sequence] }
    }

    scope :for_advisories, -> { where(data_type: data_types[:advisories]) }
    scope :for_malware_advisories, -> { where(data_type: data_types[:malware_advisories]) }
    scope :with_purl_types, ->(purl_types) { where(purl_type: purl_types) }
    scope :synced_since, ->(epoch_seconds) { where(sequence: epoch_seconds..) }

    # These components uniquely identify the last sync position for a
    # path determined by data_type_bucket_or_dir/version_format/purl_type.
    def self.with_path_components(data_type, version_format, purl_type)
      find_or_initialize_by(data_type: data_type, purl_type: purl_type, version_format: version_format)
    end

    # True on a first sync (never synced, sequence still 0) or while a resumable
    # full sync is in progress (full_sync_target_sequence marker set). The
    # malware connectors use this to fetch the /all snapshot rather than a delta;
    # full_sync_target_sequence is nil for other data types, so this reduces to
    # "sequence == 0" there. See
    # https://gitlab.com/gitlab-org/gitlab/-/work_items/603628
    def first_sync?
      full_sync_target_sequence.present? || sequence.to_i == 0
    end
  end

  class NullCheckpoint
    def update(*args); end

    def blank?
      true
    end
  end
end
