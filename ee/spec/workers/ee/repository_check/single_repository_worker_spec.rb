# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::RepositoryCheck::SingleRepositoryWorker, feature_category: :source_code_management do
  include ::EE::GeoHelpers

  let_it_be(:project) { create(:project) }

  subject(:worker) { RepositoryCheck::SingleRepositoryWorker.new }

  context 'with Geo enabled' do
    let_it_be(:primary) { create(:geo_node, :primary) }
    let_it_be(:secondary) { create(:geo_node, :secondary) }

    context 'on a Geo primary site' do
      before do
        stub_current_geo_node(primary)
      end

      it 'saves results to main database' do
        expect do
          worker.perform(project.id)
        end.to change { project.reload.last_repository_check_at }

        expect(project.last_repository_check_failed).to be_falsy
      end
    end

    context 'on a Geo secondary site' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does nothing' do
        create(:project, created_at: 1.week.ago)

        expect(worker.perform(project.id)).to eq(nil)
      end
    end

    context 'when on an org migration target cell' do
      before do
        stub_feature_flags(org_migration_target_cell: true)
      end

      context 'when project is a replica' do
        before do
          allow(Gitlab::Geo).to receive(:replica_project_id?).with(project.id).and_return(true)
        end

        it 'does nothing' do
          expect(worker.perform(project.id)).to eq(nil)
        end
      end

      context 'when project is not a replica' do
        before do
          allow(Gitlab::Geo).to receive(:replica_project_id?).with(project.id).and_return(false)
        end

        it 'saves results to main database' do
          expect do
            worker.perform(project.id)
          end.to change { project.reload.last_repository_check_at }

          expect(project.last_repository_check_failed).to be_falsy
        end
      end
    end
  end
end
