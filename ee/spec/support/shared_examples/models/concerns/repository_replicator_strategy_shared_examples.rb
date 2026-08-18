# frozen_string_literal: true

# Include these shared examples in specs of Replicators that include
# RepositoryReplicatorStrategy.
#
# Required let variables:
#
# - model_record: A valid, unpersisted instance of the model class. Or a valid,
#                 persisted instance of the model class in a not-yet loaded let
#                 variable (so we can trigger creation).
#
RSpec.shared_examples 'a repository replicator' do
  include EE::GeoHelpers

  let_it_be(:primary, freeze: false) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: false) { create(:geo_node) }

  let(:housekeeping_model_record) { model_record }

  subject(:replicator) { model_record.replicator }

  before do
    stub_current_geo_node(primary)
  end

  it_behaves_like 'a replicator' do
    let_it_be(:event_name, freeze: false) { ::Geo::ReplicatorEvents::EVENT_UPDATED }
  end

  it_behaves_like 'a verifiable replicator'

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
        model_record

        expect do
          replicator.geo_handle_after_update
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name,
          "event_name" => ::Geo::ReplicatorEvents::EVENT_UPDATED,
          "payload" => {
            "model_record_id" => replicator.model_record.id,
            "correlation_id" => an_instance_of(String)
          }
        )
      end

      it 'calls #after_verifiable_update' do
        expect(replicator).to receive(:after_verifiable_update)

        replicator.geo_handle_after_update
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

  describe '#geo_handle_after_create' do
    context 'on a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'creates a Geo::Event' do
        model_record.save!

        expect do
          replicator.geo_handle_after_create
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name,
          "event_name" => ::Geo::ReplicatorEvents::EVENT_CREATED,
          "payload" => {
            "model_record_id" => replicator.model_record.id,
            "correlation_id" => an_instance_of(String)
          }
        )
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(replicator.replication_enabled_feature_key => false)
        end

        it 'does not publish' do
          expect do
            replicator.geo_handle_after_create
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
          replicator.geo_handle_after_create
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
        model_record

        expect do
          replicator.geo_handle_after_destroy
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name, "event_name" => ::Geo::ReplicatorEvents::EVENT_DELETED)
        expect(::Geo::Event.last.payload).to include({ "model_record_id" => replicator.model_record.id })
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags("geo_#{replicator.replicable_name}_replication": false)
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

    context 'in replicables_for_current_secondary list' do
      it 'runs Geo::FrameworkRepositorySyncService service' do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(true)
        sync_service = double

        expect(sync_service).to receive(:execute)
        expect(::Geo::FrameworkRepositorySyncService)
          .to receive(:new).with(replicator)
                .and_return(sync_service)

        replicator.consume(::Geo::ReplicatorEvents::EVENT_UPDATED)
      end
    end

    context 'not in replicables_for_current_secondary list' do
      it 'does not run Geo::FrameworkRepositorySyncService service' do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)

        expect(::Geo::FrameworkRepositorySyncService)
          .not_to receive(:new)

        replicator.consume(::Geo::ReplicatorEvents::EVENT_UPDATED)
      end
    end

    context 'when a sync is currently running' do
      let(:registry) { replicator.registry }

      it 'moves registry state to pending' do
        registry.start!

        # sync no-op, as if the lease is already taken
        allow(replicator).to receive(:sync_repository)

        expect do
          replicator.consume(::Geo::ReplicatorEvents::EVENT_UPDATED)
        end.to change { registry.reload.pending? }.from(false).to(true)
      end
    end
  end

  describe 'deleted event consumption' do
    it 'runs Geo::RepositoryRegistryRemovalService service' do
      model_record.save!

      sync_service = double

      expect(sync_service).to receive(:execute)

      expect(Geo::RepositoryRegistryRemovalService)
        .to receive(:new).with(replicator, {})
              .and_return(sync_service)

      replicator.consume(::Geo::ReplicatorEvents::EVENT_DELETED)
    end
  end

  describe '.housekeeping_enabled?' do
    it 'is implemented' do
      expect(replicator.class.housekeeping_enabled?).to be_in([true, false])
    end
  end

  describe '#housekeeping_model_record' do
    it 'is implemented' do
      expect(replicator.housekeeping_model_record).to eq(housekeeping_model_record)
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

  describe '#mutable?' do
    it 'is true' do
      expect(replicator.mutable?).to eq(true)
    end
  end
end
