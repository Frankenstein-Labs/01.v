# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::DependencyAggregationResolver, feature_category: :dependency_management do
  include GraphqlHelpers

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:project_1) { create(:project, namespace: group) }
  let_it_be(:project_2) { create(:project, namespace: group) }

  let_it_be(:component_1) { create(:sbom_component, name: 'activestorage') }
  let_it_be(:occurrence_1) { create(:sbom_occurrence, component: component_1, project: project_1) }

  let_it_be(:component_2) { create(:sbom_component, name: 'activesupport') }
  let_it_be(:occurrence_2) { create(:sbom_occurrence, component: component_2, project: project_2) }

  subject(:sync_resolve) { sync(resolve_dependencies(args: args)) }

  context 'when project_ids is not given' do
    let(:args) { {} }

    it 'uses the aggregations finder' do
      expect(::Sbom::AggregationsFinder).to receive(:new).with(
        group, params: hash_excluding(:project_ids)
      ).and_call_original
      expect(::Sbom::DependenciesFinder).not_to receive(:new)

      sync_resolve
    end

    it 'returns aggregated occurrences across the group hierarchy' do
      expect(sync_resolve).to match_array([
        an_object_having_attributes(component_id: component_1.id),
        an_object_having_attributes(component_id: component_2.id)
      ])
    end
  end

  context 'when project_ids is given' do
    let(:args) { { project_ids: [project_1.to_gid] } }

    it 'uses the dependencies finder with coerced project ids' do
      expect(::Sbom::DependenciesFinder).to receive(:new).with(
        group, params: hash_including(project_ids: [project_1.id.to_s])
      ).and_call_original
      expect(::Sbom::AggregationsFinder).not_to receive(:new)

      sync_resolve
    end

    it 'returns only occurrences for the given projects' do
      expect(sync_resolve).to match_array([occurrence_1])
    end

    context 'with multiple project_ids' do
      let(:args) { { project_ids: [project_1.to_gid, project_2.to_gid] } }

      it 'returns occurrences for all given projects' do
        expect(sync_resolve).to match_array([occurrence_1, occurrence_2])
      end
    end
  end

  describe 'N+1 queries' do
    let_it_be(:nplus_group) { create(:group) }
    let_it_be(:nplus_project_1) { create(:project, namespace: nplus_group) }
    let_it_be(:nplus_project_2) { create(:project, namespace: nplus_group) }
    let_it_be(:nplus_user) { create(:user, developer_of: nplus_group) }

    def query(project_ids: nil)
      project_ids_arg = project_ids ? %((projectIds: [#{project_ids.map { |id| "\"#{id}\"" }.join(', ')}])) : ''

      %(
        query {
          group(fullPath: "#{nplus_group.full_path}") {
            dependencyAggregations#{project_ids_arg} {
              nodes {
                name
                version
                occurrenceCount
              }
            }
          }
        }
      )
    end

    def run_query(project_ids: nil)
      GitlabSchema.execute(query(project_ids: project_ids), context: { current_user: nplus_user })
    end

    def add_dependencies(project)
      component = create(:sbom_component)
      create(:sbom_occurrence, component: component, project: project)
    end

    context 'when project_ids is not given (aggregations finder)', :request_store do
      it 'avoids N+1 database queries' do
        add_dependencies(nplus_project_1)

        control = ActiveRecord::QueryRecorder.new { run_query }

        add_dependencies(nplus_project_2)
        add_dependencies(nplus_project_2)

        expect { run_query }.not_to exceed_query_limit(control)
      end
    end

    context 'when project_ids is given (dependencies finder)', :request_store do
      it 'avoids N+1 database queries' do
        add_dependencies(nplus_project_1)

        project_ids = [nplus_project_1.to_gid.to_s, nplus_project_2.to_gid.to_s]
        control = ActiveRecord::QueryRecorder.new { run_query(project_ids: project_ids) }

        add_dependencies(nplus_project_2)
        add_dependencies(nplus_project_2)

        expect { run_query(project_ids: project_ids) }.not_to exceed_query_limit(control)
      end
    end
  end

  private

  def resolve_dependencies(args: {})
    resolve(
      described_class,
      obj: group,
      args: args,
      ctx: { current_user: user }
    )
  end
end
