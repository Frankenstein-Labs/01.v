# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ci::Catalog::Resources::Components::ProjectUsageResolver, feature_category: :pipeline_composition do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:component_1) { create(:ci_catalog_resource_component, name: 'component1') }
  let_it_be(:component_2) { create(:ci_catalog_resource_component, name: 'component2') }

  let_it_be(:usage_1) do
    create(:catalog_resource_component_last_usage, component: component_1, used_by_project_id: project.id)
  end

  let_it_be(:usage_2) do
    create(:catalog_resource_component_last_usage, component: component_2, used_by_project_id: project.id)
  end

  describe '#resolve' do
    let(:resolve_project_component_usage) do
      batch_sync { resolve(described_class, obj: project, ctx: { current_user: current_user }) }
    end

    context 'when licensed' do
      before do
        stub_licensed_features(ci_component_usages_in_projects: true)
      end

      context 'when on SaaS' do
        before do
          stub_saas_features(ci_component_usages_in_projects: true)
        end

        context 'when user is a maintainer of the group' do
          before_all do
            group.add_maintainer(current_user)
          end

          it 'returns all component usages' do
            expect(resolve_project_component_usage).to contain_exactly(usage_1, usage_2)
          end
        end

        context 'when user is not a maintainer of the group' do
          before_all do
            group.add_developer(current_user)
          end

          it 'returns empty array' do
            expect(resolve_project_component_usage).to be_empty
          end
        end

        context 'when user is not part of the group' do
          let_it_be(:unauthorized_user) { create(:user) }

          it 'returns empty array' do
            expect(batch_sync { resolve(described_class, obj: project, ctx: { current_user: unauthorized_user }) })
              .to be_empty
          end
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let_it_be(:current_user) { create(:admin) }

        before do
          stub_licensed_features(ci_component_usages_in_projects: true)
        end

        it 'returns all component usages' do
          expect(resolve_project_component_usage).to contain_exactly(usage_1, usage_2)
        end
      end
    end

    context 'when not licensed' do
      before do
        stub_licensed_features(ci_component_usages_in_projects: false)
      end

      it 'raises resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolve_project_component_usage
        end
      end
    end
  end
end
