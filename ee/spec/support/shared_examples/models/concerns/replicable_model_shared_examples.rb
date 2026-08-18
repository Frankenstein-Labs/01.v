# frozen_string_literal: true

# Required let variables:
#
# - model_record: A valid, unpersisted instance of the model class. Or a valid,
#                 persisted instance of the model class in a not-yet loaded let
#                 variable (so we can trigger creation).
# - replicator_class
#
# Also see ee/spec/lib/gitlab/geo/replicable_model_spec.rb:
#
# - Place tests in replicable_model_spec.rb if you want to run them once,
#   against a DummyModel.
# - Place tests here in replicable_model_shared_examples.rb if you want them to
#   be run against every real Model.
RSpec.shared_examples 'a replicable model' do
  include EE::GeoHelpers

  describe '#replicator' do
    it 'is defined and does not raise error' do
      expect(model_record.replicator).to be_a(Gitlab::Geo::Replicator)
    end
  end

  it 'invokes replicator.geo_handle_after_create on create' do
    # A custom test based on this test has been added to
    # ee/spec/replicators/geo/project_repository_replicator_spec.rb
    skip if replicator_class == Geo::ProjectRepositoryReplicator

    expect_next_instance_of(replicator_class) do |replicator|
      expect(replicator).to receive(:geo_handle_after_create)
    end

    model_record.save!
  end

  describe '.replicable_title' do
    it 'returns replicator title' do
      expect(replicator_class.replicable_title).to be_a(String)
      expect(replicator_class.replicable_title).not_to be_empty
    end
  end

  describe '.replicable_title_plural' do
    it 'returns replicator pluralized title' do
      expect(replicator_class.replicable_title_plural).to be_a(String)
      expect(replicator_class.replicable_title_plural).not_to be_empty
    end
  end

  describe '.replicables_for_current_secondary' do
    let_it_be(:secondary, freeze: false) { create(:geo_node) }

    before do
      stub_current_geo_node(secondary)
    end

    shared_examples 'is implemented and returns a valid relation' do
      it 'is implemented' do
        expect(model_record.class.replicables_for_current_secondary(model_record.id)).to be_an(ActiveRecord::Relation)
      end
    end

    context 'when syncing object storage is enabled' do
      before do
        secondary.update!(sync_object_storage: true)
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'when syncing object storage is disabled' do
      before do
        secondary.update!(sync_object_storage: false)
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'with selective sync disabled' do
      before do
        secondary.update!(selective_sync_type: nil)
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'with selective sync enabled for namespaces' do
      before do
        secondary.update!(selective_sync_type: 'namespaces', namespaces: [build(:group)])
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'with selective sync enabled for shards' do
      before do
        secondary.update!(selective_sync_type: 'shards', selective_sync_shards: ['broken'])
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end
  end
end
