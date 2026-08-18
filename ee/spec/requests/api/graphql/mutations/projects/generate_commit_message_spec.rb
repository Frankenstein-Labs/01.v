# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'AiAction for Generate Commit Message', :saas, feature_category: :code_review_workflow do
  include GraphqlHelpers
  include Graphql::Subscriptions::Notes::Helper

  let_it_be_with_reload(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: [project, group]) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
  end

  let_it_be(:seat_assignment) do
    create(
      :gitlab_subscription_user_add_on_assignment,
      user: current_user,
      add_on_purchase: add_on_purchase
    )
  end

  let(:mutation) do
    params = { generate_commit_message: { resource_id: merge_request.to_gid } }

    graphql_mutation(:ai_action, params) do
      <<-QL.strip_heredoc
        errors
      QL
    end
  end

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(generate_commit_message: true, ai_features: true, experimental_features: true)
    group.namespace_settings.update!(experiment_features_enabled: true)

    allow(current_user).to receive(:allowed_to_use?)
      .with(:generate_commit_message, licensed_feature: :generate_commit_message).and_return(true)
  end

  it 'successfully performs an generate commit message request' do
    expect(Llm::CompletionWorker).to receive(:perform_for).with(
      an_object_having_attributes(
        user: current_user,
        resource: merge_request,
        ai_action: :generate_commit_message),
      anything
    )

    post_graphql_mutation(mutation, current_user: current_user)

    expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
  end
end
