# frozen_string_literal: true

module Geo
  class AiVectorizableFileUploadRegistry < Geo::BaseRegistry
    include ::Geo::ReplicableRegistry
    include ::Geo::VerifiableRegistry
    include ::Geo::PartitionUploadRegistry

    belongs_to :ai_vectorizable_file_upload, class_name: 'Geo::AiVectorizableFileUpload'

    def self.model_class
      ::Geo::AiVectorizableFileUpload
    end

    def self.model_foreign_key
      :ai_vectorizable_file_upload_id
    end

    def self.model_updated_last
      :created_at
    end
  end
end
