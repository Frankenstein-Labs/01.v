# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectRepositoryReplicator, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:project) { create(:project_with_repo) }
  let(:model_record) { project }
  let(:primary_node) { create(:geo_node, :primary) }

  subject(:replicator) { model_record.replicator }

  context 'with project repository replication (V1)' do
    before do
      stub_feature_flags(geo_project_repository_replication_v2: false)
    end

    it_behaves_like 'a repository replicator'

    it 'invokes replicator.geo_handle_after_create on create' do
      # This is a hacky workaround used instead of the ActiveRecord based
      # method `expect_next_found_2_instances_of` because `replicator_class`
      # is not an ActiveRecord model.

      # We want to assert that Geo::ProjectRepositoryReplicator#geo_handle_after_create
      # is called twice - one for each of the two model's the replicator class supports
      expect_next_instance_of(described_class) do |replicator|
        expect(replicator).to receive(:geo_handle_after_create)
      end

      expect_next_instance_of(described_class) do |replicator|
        expect(replicator).to receive(:geo_handle_after_create)
      end

      model_record.save!
    end

    describe 'housekeeping implementation' do
      let_it_be_with_reload(:pool_repository) { create(:pool_repository) }
      let_it_be(:model_record, freeze: true) { create(:project, pool_repository: pool_repository) }

      context 'on a primary node' do
        before do
          stub_current_geo_node(primary_node)
        end

        it 'does not call Geo::CreateObjectPoolService' do
          expect(Geo::CreateObjectPoolService).not_to receive(:new)

          replicator.before_housekeeping
        end
      end

      it 'calls Geo::CreateObjectPoolService' do
        stub_secondary_node

        expect_next_instance_of(Geo::CreateObjectPoolService) do |service|
          expect(service).to receive(:execute)
        end

        replicator.before_housekeeping
      end

      context 'on an org_migration_target node' do
        before do
          stub_feature_flags(org_migration_target_cell: true)
          stub_current_geo_node(create(:geo_node))
        end

        it 'calls Geo::CreateObjectPoolService' do
          expect_next_instance_of(Geo::CreateObjectPoolService) do |service|
            expect(service).to receive(:execute)
          end

          replicator.before_housekeeping
        end
      end

      # NOTE: Keep this context last. It mutates the let_it_be pool_repository
      # via update_column, which would otherwise leak state into sibling tests.
      context 'when pool repository source_project is nil' do
        before do
          stub_secondary_node
          pool_repository.update_column(:source_project_id, nil)
        end

        it 'does not raise an error and does not call Geo::CreateObjectPoolService' do
          expect(Geo::CreateObjectPoolService).not_to receive(:new)

          expect { replicator.before_housekeeping }.not_to raise_error
        end
      end
    end
  end

  describe '.geo_project_repository_replication_v2_enabled?' do
    context 'when feature flag is enabled' do
      it 'returns true' do
        expect(described_class.geo_project_repository_replication_v2_enabled?).to be true
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(geo_project_repository_replication_v2: false)
      end

      it 'returns false' do
        expect(described_class.geo_project_repository_replication_v2_enabled?).to be false
      end
    end
  end

  describe '#should_publish_replication_event?' do
    before do
      stub_current_geo_node(primary_node)
    end

    context 'when parent method returns false' do
      before do
        allow(described_class).to receive(:replication_enabled?).and_return(false)
      end

      it 'returns false regardless of model type' do
        expect(replicator.should_publish_replication_event?).to be false
      end
    end

    context 'when parent method returns true' do
      before do
        allow(described_class).to receive(:replication_enabled?).and_return(true)
      end

      context 'with Project model' do
        context 'when v2 feature flag is disabled' do
          before do
            stub_feature_flags(geo_project_repository_replication_v2: false)
          end

          it 'returns true for Project models' do
            expect(replicator.should_publish_replication_event?).to be true
          end
        end

        context 'when v2 feature flag is enabled' do
          it 'returns true for Project models' do
            expect(replicator.should_publish_replication_event?).to be true
          end
        end
      end

      context 'with ProjectRepository model' do
        let(:model_record) { project.project_repository }

        context 'when v2 feature flag is disabled' do
          before do
            stub_feature_flags(geo_project_repository_replication_v2: false)
          end

          it 'returns false for ProjectRepository models' do
            expect(replicator.should_publish_replication_event?).to be false
          end
        end

        context 'when v2 feature flag is enabled' do
          it 'returns true for ProjectRepository models' do
            expect(replicator.should_publish_replication_event?).to be true
          end
        end
      end
    end

    describe 'org migration' do
      let(:placeholder_storage) { Geo::OrgMigrationRepositoryReplicatorConcern::PLACEHOLDER_STORAGE }

      before do
        stub_org_migration_target_cell
      end

      describe '#org_migration_storage_ready?' do
        context 'with v2 enabled' do
          let(:model_record) { project.project_repository }

          it_behaves_like 'an org_migration_storage_ready? check based on shard_id'
        end

        context 'with v1 (v2 disabled)' do
          before do
            stub_feature_flags(geo_project_repository_replication_v2: false)
          end

          it 'returns false when repository_storage is the placeholder' do
            project.update_column(:repository_storage, placeholder_storage)

            expect(replicator.org_migration_storage_ready?).to be false
          end

          it 'returns true when repository_storage is a real shard' do
            expect(replicator.org_migration_storage_ready?).to be true
          end
        end
      end

      describe '#assign_org_migration_storage!' do
        it_behaves_like 'a replicator that does not assign storage outside org migration target cells'

        context 'with v2 enabled' do
          let(:model_record) { project.project_repository }

          before do
            model_record.update_column(:shard_id, nil)
            project.update_column(:repository_storage, placeholder_storage)
          end

          it 'assigns shard_id on ProjectRepository and repository_storage on Project' do
            replicator.assign_org_migration_storage!

            expect(model_record.reload.shard_id).to be_present
            expect(project.reload.repository_storage).not_to eq(placeholder_storage)
          end

          it 'is a no-op when shard_id is already present' do
            existing_shard = create(:shard, name: 'existing')
            model_record.update_column(:shard_id, existing_shard.id)

            replicator.assign_org_migration_storage!

            expect(model_record.reload.shard_id).to eq(existing_shard.id)
          end

          it 'raises OrgMigrationRepositoryStorageNotReadyError when storage is not ready after assignment' do
            allow(replicator).to receive(:org_migration_storage_ready?).and_return(false)

            expect { replicator.assign_org_migration_storage! }
              .to raise_error(Geo::Errors::OrgMigrationRepositoryStorageNotReadyError)
          end
        end

        context 'with v1 (v2 disabled)' do
          before do
            stub_feature_flags(geo_project_repository_replication_v2: false)
            project.update_column(:repository_storage, placeholder_storage)
          end

          it 'assigns repository_storage on Project' do
            replicator.assign_org_migration_storage!

            expect(project.reload.repository_storage).not_to eq(placeholder_storage)
          end

          it 'is a no-op when repository_storage is already valid' do
            project.update_column(:repository_storage, 'existing')

            replicator.assign_org_migration_storage!

            expect(project.reload.repository_storage).to eq('existing')
          end

          it 'raises OrgMigrationRepositoryStorageNotReadyError when storage is not ready after assignment' do
            allow(replicator).to receive(:org_migration_storage_ready?).and_return(false)

            expect { replicator.assign_org_migration_storage! }
              .to raise_error(Geo::Errors::OrgMigrationRepositoryStorageNotReadyError)
          end
        end
      end

      describe '#track_repository_after_org_migration!' do
        context 'when not an org migration target' do
          before do
            stub_feature_flags(org_migration_target_cell: false)
          end

          it 'is a no-op' do
            expect(model_record).not_to receive(:track_project_repository)

            replicator.track_repository_after_org_migration!
          end
        end

        context 'with v2 enabled' do
          let(:model_record) { project.project_repository }

          it 'calls track_project_repository' do
            expect(model_record).to receive(:track_project_repository)

            replicator.track_repository_after_org_migration!
          end
        end

        context 'with v1 (v2 disabled)' do
          before do
            stub_feature_flags(geo_project_repository_replication_v2: false)
          end

          it 'calls track_project_repository' do
            expect(model_record).to receive(:track_project_repository)

            replicator.track_repository_after_org_migration!
          end
        end
      end
    end

    describe 'integration test for event publishing behavior' do
      let_it_be(:secondary, freeze: true) { create(:geo_node, :secondary) }

      before do
        # Calling these earlier, so that no unintended :created events are
        # not published during the tests
        replicator
        project.project_repository.replicator
      end

      context 'when v2 feature flag is disabled' do
        before do
          stub_feature_flags(geo_project_repository_replication_v2: false)
        end

        it 'publishes events for Project updates but not ProjectRepository updates' do
          expect { replicator.publish(:updated) }.to change { Geo::Event.count }.by(1)
          expect { project.project_repository.replicator.publish(:updated) }.not_to change { Geo::Event.count }
        end
      end

      context 'when v2 feature flag is enabled' do
        it 'publishes events for both Project and ProjectRepository updates' do
          expect { replicator.publish(:updated) }.to change { Geo::Event.count }.by(1)
          expect { project.project_repository.replicator.publish(:updated) }.to change { Geo::Event.count }.by(1)
        end
      end
    end
  end
end
