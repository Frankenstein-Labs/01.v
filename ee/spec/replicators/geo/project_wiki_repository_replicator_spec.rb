# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectWikiRepositoryReplicator, feature_category: :geo_replication do
  let(:project) { create(:project, :wiki_repo, wiki_repository: build(:project_wiki_repository, project: nil)) }
  let(:model_record) { project.wiki_repository }

  include_examples 'a repository replicator' do
    let(:housekeeping_model_record) { model_record.wiki }

    describe '#verify' do
      context 'when wiki git repository does not exist' do
        let(:project) { create(:project, wiki_repository: build(:project_wiki_repository, project: nil)) }
        let(:model_record) { project.wiki_repository }

        it 'creates an empty git repository' do
          expect { replicator.verify }
            .to change { model_record.repository.exists? }
            .from(false)
            .to(true)

          expect(replicator.primary_checksum).to be_present
        end
      end
    end

    context 'on an org_migration_target node' do
      let(:placeholder_storage) { Geo::OrgMigrationRepositoryReplicatorConcern::PLACEHOLDER_STORAGE }

      before do
        stub_org_migration_target_cell
      end

      describe '#org_migration_storage_ready?' do
        it 'returns false when project repository_storage is the placeholder' do
          project.update_column(:repository_storage, placeholder_storage)

          expect(replicator.org_migration_storage_ready?).to be false
        end

        it 'returns true when project repository_storage is a real shard' do
          expect(replicator.org_migration_storage_ready?).to be true
        end
      end

      describe '#assign_org_migration_storage!' do
        it_behaves_like 'a replicator that does not assign storage outside org migration target cells'

        it 'does not raise when storage is ready' do
          expect { replicator.assign_org_migration_storage! }.not_to raise_error
        end

        it 'raises OrgMigrationRepositoryStorageNotReadyError when storage is not ready' do
          project.update_column(:repository_storage, placeholder_storage)

          expect { replicator.assign_org_migration_storage! }
            .to raise_error(Geo::Errors::OrgMigrationRepositoryStorageNotReadyError)
        end
      end

      it_behaves_like 'a replicator with default no-op track_repository_after_org_migration!'
    end
  end
end
