# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::AvailableFlowsForProjectResolver, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  subject(:resolver) { described_class }

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(:project_id)
  end

  describe '#resolve' do
    let(:project_gid) { project.to_global_id }

    before do
      enable_ai_catalog
    end

    context 'when user does not have admin_ai_catalog_item_consumer permission' do
      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolve(resolver, args: { project_id: project_gid }, ctx: { current_user: user })
        end
      end
    end

    context 'when user has admin_ai_catalog_item_consumer permission' do
      before_all do
        group.add_maintainer(user)
      end

      context 'when project is personal (no root group)' do
        let_it_be(:personal_namespace) { create(:namespace, owner: user) }
        let_it_be(:personal_project) { create(:project, namespace: personal_namespace) }

        it 'returns empty result' do
          result = resolve(resolver, args: { project_id: personal_project.to_global_id }, ctx: { current_user: user })

          expect(result).to be_empty
        end
      end

      context 'when root group has configured flows' do
        let_it_be(:flow) { create(:ai_catalog_flow) }
        let_it_be(:agent) { create(:ai_catalog_agent) }
        let_it_be(:flow_consumer) { create(:ai_catalog_item_consumer, group: group, item: flow) }
        let_it_be(:agent_consumer) { create(:ai_catalog_item_consumer, group: group, item: agent) }

        it 'returns only flow items configured at root group' do
          result = resolve(resolver, args: { project_id: project_gid }, ctx: { current_user: user })

          expect(result).to contain_exactly(flow_consumer)
        end
      end
    end
  end
end
