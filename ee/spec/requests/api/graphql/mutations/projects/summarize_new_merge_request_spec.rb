# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'AiAction for Summarize New Merge Request', :saas, feature_category: :code_review_workflow do
  include GraphqlHelpers
  include Graphql::Subscriptions::Notes::Helper

  let_it_be_with_reload(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: [project, group]) }

  let(:mutation) do
    params = {
      summarize_new_merge_request: {
        resource_id: project.to_gid,
        source_branch: 'feature',
        target_branch: 'master'
      }
    }

    graphql_mutation(:ai_action, params) do
      <<-QL.strip_heredoc
        errors
      QL
    end
  end

  include_context 'with duo enterprise addon'

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(summarize_new_merge_request: true, ai_features: true, experimental_features: true)
    allow(Ability).to receive(:allowed?).and_call_original
    group.namespace_settings.update!(experiment_features_enabled: true)
  end

  it 'successfully performs an explain code request' do
    expect(Llm::CompletionWorker).to receive(:perform_for).with(
      an_object_having_attributes(
        user: current_user,
        resource: project,
        ai_action: :summarize_new_merge_request),
      hash_including(
        source_branch: 'feature',
        target_branch: 'master'
      )
    )

    post_graphql_mutation(mutation, current_user: current_user)

    expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
  end

  context 'when experiment_features_enabled disabled' do
    before do
      group.namespace_settings.update!(experiment_features_enabled: false)
    end

    it 'returns nil' do
      expect(Llm::CompletionWorker).not_to receive(:perform_for)

      post_graphql_mutation(mutation, current_user: current_user)
    end
  end
end
