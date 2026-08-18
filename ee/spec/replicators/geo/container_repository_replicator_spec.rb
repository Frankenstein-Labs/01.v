# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ContainerRepositoryReplicator, :geo, feature_category: :geo_replication do
  include_context 'container registry client stubs'

  let_it_be(:primary, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: true) { create(:geo_node) }

  before do
    stub_container_registry_gitlab_api_support(supported: false)
  end

  # Based on shared example 'a repository replicator'
  context 'for base replicator functionality' do
    include EE::GeoHelpers

    let(:model_record) { build(:container_repository) }

    subject(:replicator) { model_record.replicator }

    before do
      stub_current_geo_node(primary)
    end

    it_behaves_like 'a replicator' do
      let_it_be(:event_name, freeze: true) { ::Geo::ReplicatorEvents::EVENT_UPDATED }
    end

    # This could be included in each model's spec, but including it here is DRYer.
    include_examples 'a replicable model' do
      let(:replicator_class) { described_class }
    end

    describe '#geo_handle_after_update' do
      context 'on a Geo primary' do
        before do
          stub_current_geo_node(primary)
        end

        it 'creates a Geo::Event' do
          model_record.save!

          expect do
            replicator.geo_handle_after_update
          end.to change { ::Geo::Event.count }.by(1)

          expect(::Geo::Event.last.attributes).to include(
            "replicable_name" => replicator.replicable_name,
            "event_name" => ::Geo::ReplicatorEvents::EVENT_UPDATED,
            "payload" => {
              "model_record_id" => replicator.model_record.id,
              "correlation_id" => an_instance_of(String)
            })
        end

        context 'when replication feature flag is disabled' do
          before do
            stub_feature_flags(replicator.replication_enabled_feature_key => false)
          end

          it 'does not publish' do
            expect do
              replicator.geo_handle_after_update
            end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
          end
        end
      end

      context 'on a Geo secondary' do
        before do
          stub_current_geo_node(secondary)
        end

        it 'does not create an event' do
          expect do
            replicator.geo_handle_after_update
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    describe '#geo_handle_after_destroy' do
      context 'on a Geo primary' do
        before do
          stub_current_geo_node(primary)
        end

        it 'creates a Geo::Event' do
          expect do
            replicator.geo_handle_after_destroy
          end.to change { ::Geo::Event.count }.by(1)

          expect(::Geo::Event.last.attributes).to include(
            "replicable_name" => replicator.replicable_name,
            "event_name" => ::Geo::ReplicatorEvents::EVENT_DELETED,
            "payload" => {
              "model_record_id" => replicator.model_record.id,
              "path" => replicator.model_record.path,
              "correlation_id" => an_instance_of(String)
            })
        end

        context 'when replication feature flag is disabled' do
          before do
            stub_feature_flags(replicator.replication_enabled_feature_key => false)
          end

          it 'does not publish' do
            expect do
              replicator.geo_handle_after_destroy
            end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
          end
        end
      end

      context 'on a Geo secondary' do
        before do
          stub_current_geo_node(secondary)
        end

        it 'does not create an event' do
          expect do
            replicator.geo_handle_after_destroy
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    describe 'updated event consumption' do
      before do
        model_record.save!
      end

      context 'when in replicables_for_current_secondary list' do
        it 'runs Geo::ContainerRepositorySyncService service' do
          allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(true)
          sync_service = double

          expect(sync_service).to receive(:execute)
          expect(::Geo::ContainerRepositorySyncService)
            .to receive(:new).with(model_record)
                  .and_return(sync_service)

          replicator.consume(::Geo::ReplicatorEvents::EVENT_UPDATED)
        end
      end

      context 'when not in replicables_for_current_secondary list' do
        it 'does not run Geo::ContainerRepositorySyncService service' do
          allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)

          expect(::Geo::ContainerRepositorySyncService)
            .not_to receive(:new)

          replicator.consume(::Geo::ReplicatorEvents::EVENT_UPDATED)
        end
      end
    end

    describe 'created event consumption' do
      it 'calls update event consumer' do
        expect(replicator).to receive(:consume_event_updated)

        replicator.consume_event_created
      end
    end

    describe 'deleted event consumption' do
      before do
        model_record.save!
      end

      it 'runs Geo::ContainerRepositoryRegistryRemovalService service' do
        removal_service = double

        expect(removal_service).to receive(:execute)
        expect(::Geo::ContainerRepositoryRegistryRemovalService)
          .to receive(:new).with(model_record.id, model_record.path)
                .and_return(removal_service)

        replicator.consume(
          ::Geo::ReplicatorEvents::EVENT_DELETED,
          model_record_id: model_record,
          path: model_record.path
        )
      end
    end

    describe '#model' do
      let(:invoke_model) { replicator.class.model }

      it 'is implemented' do
        expect do
          invoke_model
        end.not_to raise_error
      end

      it 'is a Class' do
        expect(invoke_model).to be_a(Class)
      end
    end
  end

  describe '.replication_enabled?' do
    context 'on primary site' do
      before do
        stub_current_geo_node(primary)
      end

      it 'returns false when registry is disabled' do
        stub_container_registry_config(enabled: false)
        expect(described_class.replication_enabled?).to be false
      end

      it 'returns true when registry is enabled' do
        stub_container_registry_config(enabled: true)
        expect(described_class.replication_enabled?).to be true
      end

      it 'returns false even when force_primary_checksumming feature flag is enabled' do
        stub_feature_flags(geo_container_repository_force_primary_checksumming: true)
        stub_container_registry_config(enabled: false)
        expect(described_class.replication_enabled?).to be false
      end
    end

    context 'on secondary site' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns false when registry is disabled' do
        stub_container_registry_config(enabled: false)
        expect(described_class.replication_enabled?).to be false
      end

      it 'returns true when registry is enabled' do
        stub_container_registry_config(enabled: true)
        expect(described_class.replication_enabled?).to be true
      end

      it 'returns false even when force_primary_checksumming feature flag is enabled' do
        stub_feature_flags(geo_container_repository_force_primary_checksumming: true)
        stub_container_registry_config(enabled: false)
        expect(described_class.replication_enabled?).to be false
      end
    end
  end

  describe '.verification_enabled?' do
    context 'on primary site' do
      before do
        stub_current_geo_node(primary)
      end

      it 'returns false when registry is disabled' do
        stub_container_registry_config(enabled: false)
        expect(described_class.verification_enabled?).to be false
      end

      it 'returns true when registry is enabled' do
        stub_container_registry_config(enabled: true)
        expect(described_class.verification_enabled?).to be true
      end

      it 'returns false even when force_primary_checksumming feature flag is enabled' do
        stub_feature_flags(geo_container_repository_force_primary_checksumming: true)
        stub_container_registry_config(enabled: false)
        expect(described_class.verification_enabled?).to be false
      end
    end

    context 'on secondary site' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns false when registry is disabled' do
        stub_container_registry_config(enabled: false)
        expect(described_class.verification_enabled?).to be false
      end

      it 'returns true when registry is enabled' do
        stub_container_registry_config(enabled: true)
        expect(described_class.verification_enabled?).to be true
      end

      it 'returns false even when force_primary_checksumming feature flag is enabled' do
        stub_feature_flags(geo_container_repository_force_primary_checksumming: true)
        stub_container_registry_config(enabled: false)
        expect(described_class.verification_enabled?).to be false
      end
    end
  end

  include_examples 'a verifiable replicator' do
    let(:model_record) { create(:container_repository) }
    let(:api_url) { 'http://registry.gitlab' }
    let(:repository_url) { "#{api_url}/v2/#{model_record.path}" }
    let(:tags) { { 'latest' => 'sha256:1111' } }

    subject(:replicator) { model_record.replicator }

    before do
      allow(Geo::ContainerRepositoryRegistry).to receive(:replication_enabled?).and_return(true)

      stub_container_registry_config(enabled: true, api_url: api_url)

      stub_request(:get, "#{repository_url}/tags/list?n=#{::ContainerRegistry::Client::DEFAULT_TAGS_PAGE_SIZE}")
        .to_return(
          status: 200,
          body: Gitlab::Json.dump(tags: tags.keys),
          headers: { 'Content-Type' => 'application/json' })

      tags.each do |tag, digest|
        stub_request(:head, "#{repository_url}/manifests/#{tag}")
          .to_return(status: 200, body: "", headers: { DependencyProxy::Manifest::DIGEST_HEADER => digest })
      end
    end

    describe '#after_verifiable_update' do
      using RSpec::Parameterized::TableSyntax

      where(:verification_enabled, :immutable, :checksum, :checksummable, :expect_verify_async) do
        true  | true  | nil      | true  | true
        true  | true  | nil      | false | false
        true  | true  | 'abc123' | true  | false
        true  | true  | 'abc123' | false | false
        true  | false | nil      | true  | true
        true  | false | nil      | false | false
        true  | false | 'abc123' | true  | true
        true  | false | 'abc123' | false | false
        false | true  | nil      | true  | false
        false | true  | nil      | false | false
        false | true  | 'abc123' | true  | false
        false | true  | 'abc123' | false | false
        false | false | nil      | true  | false
        false | false | nil      | false | false
        false | false | 'abc123' | true  | false
        false | false | 'abc123' | false | false
      end

      with_them do
        before do
          allow(described_class).to receive(:verification_enabled?).and_return(verification_enabled)
          allow(replicator).to receive(:immutable?).and_return(immutable)
          allow(replicator).to receive(:primary_checksum).and_return(checksum)
          allow(replicator).to receive(:checksummable?).and_return(checksummable)
        end

        it 'calls verify_async only if needed' do
          if expect_verify_async
            expect(replicator).to receive(:verify_async)
          else
            expect(replicator).not_to receive(:verify_async)
          end

          replicator.after_verifiable_update
        end
      end
    end
  end
end
