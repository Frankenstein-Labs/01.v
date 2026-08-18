# frozen_string_literal: true

require 'spec_helper'

# Also see ee/spec/support/shared_examples/models/concerns/replicable_model_shared_examples.rb:
#
# - Place tests here in replicable_model_spec.rb if you want to run them once,
#   against a DummyModel.
# - Place tests in replicable_model_shared_examples.rb if you want them to be
#   run against every real Model.
RSpec.describe Geo::ReplicableModel, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:secondary_node, freeze: true) { create(:geo_node) }

  before_all do
    create_dummy_model_table
  end

  after(:all) do
    drop_dummy_model_table
  end

  before do
    stub_dummy_replicator_class
    stub_dummy_model_class
  end

  subject { DummyModel.new }

  it_behaves_like 'a replicable model' do
    let(:model_record) { subject }
    let(:replicator_class) { Geo::DummyReplicator }
  end

  describe '.replicable_title' do
    it 'raises NotImplementedError by default' do
      expect { described_class.replicable_title }.to raise_error(NotImplementedError)
    end
  end

  describe '.replicable_title_plural' do
    it 'raises NotImplementedError by default' do
      expect { described_class.replicable_title_plural }.to raise_error(NotImplementedError)
    end
  end

  describe '#geo_create_event!' do
    context 'when the replicator raises an error' do
      let(:error) { StandardError.new("testing error") }

      before do
        expect_next_instance_of(Geo::DummyReplicator) do |instance|
          expect(instance).to receive(:geo_handle_after_create).and_raise(error)
        end
      end

      it 'saves the model' do
        expect { subject.save! }.to change { DummyModel.count }.by(1)
      end
    end

    context 'when the replicator does not respond to geo_handle_after_create' do
      before do
        allow_next_instance_of(Geo::DummyReplicator) do |instance|
          allow(instance).to receive(:respond_to?).with(:geo_handle_after_create).and_return(false)
          expect(instance).not_to receive(:geo_handle_after_create)
        end
      end

      it 'saves the model' do
        expect { subject.save! }.to change { DummyModel.count }.by(1)
      end
    end
  end

  describe 'after_destroy hook' do
    context 'when the replicator raises an error' do
      let(:error) { StandardError.new("testing error") }

      before do
        expect_next_instance_of(Geo::DummyReplicator) do |instance|
          expect(instance).to receive(:geo_handle_after_destroy).and_raise(error)
        end
      end

      it 'destroys the model', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/18782' do
        subject.save!

        expect { subject.destroy! }.to change { DummyModel.count }.by(-1)
      end
    end
  end

  describe '.verifiables' do
    before do
      stub_current_geo_node(primary_node)
    end

    context 'when geo_object_storage_verification feature flag is disabled' do
      before do
        stub_feature_flags(geo_object_storage_verification: false)
      end

      context 'when the model can be filtered by locally stored files' do
        it 'filters by locally stored files' do
          allow(DummyModel).to receive(:respond_to?).with(:all).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:object_storage_scope).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:selective_sync_scope).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:object_storable?).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:with_files_stored_locally).and_return(true)

          expect(DummyModel).to receive(:with_files_stored_locally).once.and_return(DummyModel.none)

          DummyModel.verifiables
        end
      end

      context 'when the model cannot be filtered by locally stored files' do
        it 'does not filter by locally stored files' do
          allow(DummyModel).to receive(:respond_to?).with(:all).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:object_storage_scope).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:selective_sync_scope).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:object_storable?).and_call_original
          allow(DummyModel).to receive(:respond_to?).with(:with_files_stored_locally).and_return(false)

          expect(DummyModel).not_to receive(:with_files_stored_locally)

          DummyModel.verifiables
        end
      end
    end

    # We don't need to test the case when geo_object_storage_verification is enabled
    # because the whole .verifiables method won't be needed anymore after the FF is removed.
    # This one has only symbolic meaning before the removal
    context 'when geo_object_storage_verification feature flag is enabled' do
      it 'aliasses to .available_replicables' do
        expect(DummyModel).to receive(:available_replicables).once.and_call_original

        DummyModel.verifiables
      end
    end
  end

  describe '.object_storage_scope_for' do
    # object_storage_scope only applies the with_files_stored_locally filter for a secondary that
    # does NOT sync object storage; otherwise it returns `all` and the locality check is a no-op.
    let_it_be(:node) { create(:geo_node, :secondary, sync_object_storage: false) }

    context 'for a table partitioned by partition_id (e.g. Ci::JobArtifact)' do
      # Records are built per-example so the object storage stub (a per-example mock) is active
      # when the :remote_store trait stores the file; a let_it_be would create them in before(:all).
      let(:local_artifact) { create(:ci_job_artifact) }
      let(:remote_artifact) { create(:ci_job_artifact, :remote_store) }

      before do
        stub_artifacts_object_storage(enabled: true)
      end

      it 'finds a locally stored record when scoped by its partition_id' do
        scope = Ci::JobArtifact.object_storage_scope_for(
          node, local_artifact.id, partition_id: local_artifact.partition_id
        )

        expect(scope).to contain_exactly(local_artifact)
      end

      it 'does not find a remotely stored record' do
        scope = Ci::JobArtifact.object_storage_scope_for(
          node, remote_artifact.id, partition_id: remote_artifact.partition_id
        )

        expect(scope).to be_empty
      end
    end

    context 'for a table partitioned by model_type (e.g. Upload)' do
      let_it_be(:local_upload) { create(:upload) }
      let_it_be(:remote_upload) { create(:upload, :object_storage) }

      it 'finds a locally stored record when scoped by its model_type' do
        scope = Upload.object_storage_scope_for(
          node, local_upload.id, model_type: local_upload.model_type
        )

        expect(scope).to contain_exactly(local_upload)
      end

      it 'does not find a remotely stored record' do
        scope = Upload.object_storage_scope_for(
          node, remote_upload.id, model_type: remote_upload.model_type
        )

        expect(scope).to be_empty
      end
    end

    context 'for a table that is not partitioned (e.g. LfsObject)' do
      let(:local_lfs_object) { create(:lfs_object) }
      let(:remote_lfs_object) { create(:lfs_object, :object_storage) }

      before do
        stub_lfs_object_storage(enabled: true)
      end

      it 'finds a locally stored record without needing a partition key' do
        scope = LfsObject.object_storage_scope_for(node, local_lfs_object.id)

        expect(scope).to contain_exactly(local_lfs_object)
      end

      it 'does not find a remotely stored record' do
        scope = LfsObject.object_storage_scope_for(node, remote_lfs_object.id)

        expect(scope).to be_empty
      end
    end
  end

  describe '#in_replicables_for_current_secondary?' do
    it 'reuses replicables_for_current_secondary' do
      expect(DummyModel).to receive(:replicables_for_current_secondary).once.with(subject).and_call_original

      subject.in_replicables_for_current_secondary?
    end
  end
end
