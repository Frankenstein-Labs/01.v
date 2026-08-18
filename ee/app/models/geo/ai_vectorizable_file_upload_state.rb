# frozen_string_literal: true

module Geo
  class AiVectorizableFileUploadState < ApplicationRecord
    include ::Geo::VerificationStateDefinition

    self.primary_key = :ai_vectorizable_file_upload_id

    belongs_to :ai_vectorizable_file_upload, inverse_of: :ai_vectorizable_file_upload_state,
      class_name: 'Geo::AiVectorizableFileUpload'

    validates :verification_state, :ai_vectorizable_file_upload, presence: true
  end
end
