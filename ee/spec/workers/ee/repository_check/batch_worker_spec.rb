# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::RepositoryCheck::BatchWorker, feature_category: :source_code_management do
  include ::EE::GeoHelpers

  let(:shard_name) { 'default' }

  subject(:worker) { RepositoryCheck::BatchWorker.new }

  before do
    Gitlab::ShardHealthCache.update([shard_name])
  end

  context 'with Geo enabled' do
    let_it_be(:primary) { create(:geo_node, :primary) }
    let_it_be(:secondary) { create(:geo_node, :secondary) }

    context 'on a Geo primary site' do
      before do
        stub_current_geo_node(primary)
      end

      it 'loads project ids from main database' do
        projects = create_list(:project, 3, created_at: 1.week.ago, repository_storage: shard_name)

        expect(worker.perform(shard_name)).to match_array(projects.map(&:id))
      end
    end

    context 'on a Geo secondary site' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does nothing' do
        create(:project, created_at: 1.week.ago, repository_storage: shard_name)

        expect(worker.perform(shard_name)).to eq(nil)
      end
    end

    context 'when on an org migration target cell' do
      let_it_be_with_refind(:org_migration_target_node) { create(:geo_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
      end

      context 'when selective sync by organizations is configured' do
        before_all do
          org_migration_target_node.update!(selective_sync_type: 'organizations')
        end

        context 'with organization links' do
          let(:replica_org) { create(:organization) }
          let(:source_org) { create(:organization) }

          it 'excludes projects belonging to replica organizations' do
            create(:geo_node_organization_link, geo_node: org_migration_target_node, organization: replica_org)
            replica_project = create(
              :project, created_at: 1.week.ago, repository_storage: shard_name, organization: replica_org)
            source_project = create(
              :project, created_at: 1.week.ago, repository_storage: shard_name, organization: source_org)

            result = worker.perform(shard_name)

            expect(result).to include(source_project.id)
            expect(result).not_to include(replica_project.id)
          end
        end

        context 'without organization links' do
          it 'checks all projects' do
            projects = create_list(:project, 3, created_at: 1.week.ago, repository_storage: shard_name)

            expect(worker.perform(shard_name)).to match_array(projects.map(&:id))
          end
        end
      end

      context 'when selective sync by organizations is not configured' do
        it 'checks all projects' do
          projects = create_list(:project, 3, created_at: 1.week.ago, repository_storage: shard_name)

          expect(worker.perform(shard_name)).to match_array(projects.map(&:id))
        end
      end
    end
  end
end
