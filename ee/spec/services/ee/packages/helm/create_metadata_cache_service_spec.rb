# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Helm::CreateMetadataCacheService, :clean_gitlab_redis_shared_state, feature_category: :geo_replication do
  include ExclusiveLeaseHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:channel) { "stable" }
  let_it_be(:package) { create(:helm_package, project: project) }
  let_it_be(:package_file) { create(:helm_package_file, package: package, channel: channel) }

  let(:service) { described_class.new(project, channel) }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when updating an existing metadata cache' do
      let_it_be(:helm_metadata_cache) { create(:helm_metadata_cache, project_id: project.id, channel: channel) }

      it 'calls geo_handle_after_update on the metadata cache' do
        expect_next_found_instance_of(Packages::Helm::MetadataCache) do |metadata_cache|
          expect(metadata_cache).to receive(:geo_handle_after_update)
        end

        execute
      end
    end

    context 'when creating a new metadata cache' do
      it 'does not call geo_handle_after_update' do
        expect_next_instance_of(Packages::Helm::MetadataCache) do |metadata_cache|
          expect(metadata_cache).not_to receive(:geo_handle_after_update)
        end

        execute
      end
    end
  end
end
