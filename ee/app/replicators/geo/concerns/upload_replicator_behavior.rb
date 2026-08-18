# frozen_string_literal: true

module Geo
  module Concerns
    # Shared behaviour for replicators backed by Upload or upload partition
    # models (e.g. Geo::AbuseReportUpload, Geo::ProjectUpload).
    #
    # Implements BlobReplicatorStrategy's abstract carrierwave_uploader (every
    # Upload-backed model resolves it the same way), plus two overrides:
    #
    # 1. Model-ownership validation: Upload models carry a polymorphic `model`
    #    association. If the owning record has been deleted, attempting to build
    #    file paths raises an opaque exception. `predownload_validation_failure`
    #    and `calculate_checksum` intercept that case early and surface a clear
    #    error message.
    #
    # 2. Parent-checksum adoption: Upload partition models share a row in
    #    Geo::UploadState with their parent Upload. When the parent has already
    #    been verified, `calculate_checksum` returns the stored checksum
    #    directly instead of re-reading and re-hashing the file, avoiding
    #    redundant I/O when a partition replicator FF is first enabled.
    module UploadReplicatorBehavior
      extend ActiveSupport::Concern

      # Every Upload-backed replicable resolves its CarrierWave uploader the
      # same way, so implement BlobReplicatorStrategy's abstract
      # carrierwave_uploader here instead of redefining it in each replicator.
      def carrierwave_uploader
        model_record.retrieve_uploader
      end

      # Do not attempt download unless the upload's owner `model` is present.
      # Otherwise, attempting to build file paths will raise an exception.
      def predownload_validation_failure
        error_message = model_is_missing_error_message
        return error_message if error_message

        super
      end

      def calculate_checksum
        error_message = model_is_missing_error_message
        raise error_message if error_message

        # Upload partition models inherit from Upload, which has a has_one
        # :upload_state association pointing to Geo::UploadState. If the parent
        # upload has already been verified, adopt its checksum directly instead
        # of re-reading and re-hashing the file. Uploads are immutable in
        # GitLab, so the parent's checksum is always valid for the partition.
        #
        # See: https://gitlab.com/gitlab-org/gitlab/-/work_items/594341
        return model_record.upload_state.verification_checksum if parent_upload_verification_succeeded?

        super
      end

      # Returns true when the parent Upload's verification state has succeeded
      # and the replicable is immutable, meaning its checksum can be safely
      # adopted by the partition replicator without risk of stale data.
      def parent_upload_verification_succeeded?
        return false unless immutable? && model_record.upload_state

        model_record.upload_state.verification_succeeded?
      end

      def model_is_missing_error_message
        return if model_record.model.present?

        "The model which owns this #{replicable_name} is missing. " \
          "#{replicable_name} ID##{model_record.id}, #{model_record.model_type} ID##{model_record.model_id}"
      end
    end
  end
end
