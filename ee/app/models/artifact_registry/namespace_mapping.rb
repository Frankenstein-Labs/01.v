# frozen_string_literal: true

module ArtifactRegistry
  # Named NamespaceMapping, not Namespace, to avoid colliding with the
  # monolith/S02 client's ArtifactRegistry::Namespace value object: ee/lib and
  # ee/app/models share a Zeitwerk root, so both names resolve to one constant.
  class NamespaceMapping < ApplicationRecord
    self.table_name = 'artifact_registry_namespace_mappings'

    belongs_to :organization, class_name: 'Organizations::Organization',
      inverse_of: :artifact_registry_namespace_mapping, optional: false

    validates :organization, uniqueness: true
    validates :ar_namespace_id, presence: true
  end
end
