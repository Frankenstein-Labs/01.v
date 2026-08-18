# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::BaseBatcher,
  :use_clean_rails_memory_store_caching,
  feature_category: :geo_replication do
  include EE::GeoHelpers

  # Models which are operated on by VerificationStateBackfillService
  models_with_separate_verification_state_table = [
    Ci::JobArtifact,
    Ci::SecureFile,
    ContainerRepository,
    DependencyProxy::Blob,
    DependencyProxy::Manifest,
    DesignManagement::Repository,
    GroupWikiRepository,
    LfsObject,
    MergeRequestDiff,
    PagesDeployment,
    Projects::WikiRepository,
    Project,
    Upload
  ]

  models_with_separate_verification_state_table.each do |model|
    context "for #{model.name}" do
      let(:source_class) { model }
      let(:destination_class) { model.verification_state_table_class }
      let(:destination_class_factory) { registry_factory_name(destination_class) }
      let(:key) { "verification_backfill:#{model.name.parameterize}" }

      def batcher(batch_size)
        service = Geo::VerificationStateBackfillService.new(source_class, batch_size: batch_size)
        service.send(:batcher)
      end

      include_examples 'is a Geo batcher'
    end
  end
end
