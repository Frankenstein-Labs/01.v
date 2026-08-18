# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SnippetRepositoryReplicator, feature_category: :geo_replication do
  let(:snippet) { create(:project_snippet, :repository) }
  let(:model_record) { snippet.snippet_repository }

  include_examples 'a repository replicator' do
    context 'on an org_migration_target node' do
      before do
        stub_org_migration_target_cell
      end

      describe '#org_migration_storage_ready?' do
        it_behaves_like 'an org_migration_storage_ready? check based on shard_id'
      end

      describe '#assign_org_migration_storage!' do
        it_behaves_like 'a replicator that does not assign storage outside org migration target cells'

        context 'when shard_id is nil' do
          before do
            model_record.update_column(:shard_id, nil)
          end

          it 'assigns a real shard_id' do
            replicator.assign_org_migration_storage!

            expect(model_record.reload.shard_id).to be_present
          end
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

      it_behaves_like 'a replicator with default no-op track_repository_after_org_migration!'
    end
  end
end
