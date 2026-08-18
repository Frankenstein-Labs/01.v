# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectCacheWorker, feature_category: :groups_and_projects do
  include ::EE::GeoHelpers

  let_it_be(:project) { create(:project, :small_repo) }

  let(:worker) { described_class.new }

  describe '#perform' do
    context 'with an existing project' do
      shared_examples_for 'updates only non database cache' do
        it 'updates only non database cache' do
          allow(Project).to receive(:find_by_id).with(project.id).and_return(project)

          expect(project.repository).to receive(:refresh_method_caches)
          expect(project).not_to receive(:update_repository_size)
          expect(project).not_to receive(:update_commit_count)

          worker.perform(project.id, %w[readme])
        end
      end

      shared_examples_for 'updates all caches' do
        it 'updates all caches (including database caches)' do
          allow(Project).to receive(:find_by_id).with(project.id).and_return(project)

          expect(project.repository).to receive(:refresh_method_caches)

          # update database caches
          expect(worker).to receive(:update_statistics)
          expect(project).to receive(:cleanup)

          worker.perform(project.id, %w[readme])
        end
      end

      context 'when in Geo primary site' do
        before do
          stub_primary_site
        end

        it_behaves_like 'updates all caches'

        it 'is idempotent' do
          expect { perform_multiple([project.id, %w[readme]]) }.not_to raise_error
        end
      end

      context 'when in Geo secondary site' do
        before do
          stub_secondary_site
        end

        it_behaves_like 'updates only non database cache'

        it 'is idempotent' do
          expect { perform_multiple([project.id, %w[readme]]) }.not_to raise_error
        end
      end

      context 'when on an org migration target cell' do
        before do
          stub_org_migration_target_cell
        end

        context 'when project is a replica' do
          before do
            allow(Gitlab::Geo).to receive(:replica_project?).with(project).and_return(true)
          end

          it_behaves_like 'updates only non database cache'
        end

        context 'when project is not a replica' do
          before do
            allow(Gitlab::Geo).to receive(:replica_project?).with(project).and_return(false)
          end

          it_behaves_like 'updates all caches'
        end
      end
    end

    context 'when project does not exist' do
      it 'returns early' do
        expect(worker.perform(non_existing_record_id)).to be_nil
      end
    end
  end
end
