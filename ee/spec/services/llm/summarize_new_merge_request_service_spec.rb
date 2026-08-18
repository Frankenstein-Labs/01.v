# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::SummarizeNewMergeRequestService, :saas, feature_category: :duo_code_review do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let(:can_access_summarize_new_merge_request) { true }
  let(:current_user) { user }

  describe '#perform' do
    include_context 'with ai features enabled for group'

    before_all do
      group.add_guest(user)
    end

    before do
      stub_ee_application_setting(should_check_namespace_plan: true)
      stub_licensed_features(summarize_new_merge_request: true, ai_features: true)

      allow(user).to receive(:allowed_to_use?).with(:summarize_new_merge_request).and_return(true)
      allow(user)
        .to receive(:allowed_to_use?)
        .with(:summarize_new_merge_request, licensed_feature: :summarize_new_merge_request)
        .and_return(true)

      stub_feature_flags(ai_global_switch: true, add_ai_summary_for_new_mr: true)

      # Multiple base permissions are checked before executing this service
      # so we stub all permission checks to return true to avoid having to stub each one individually
      allow(user).to receive(:can?).and_return(true)

      allow(user)
        .to receive(:can?)
        .with(:access_summarize_new_merge_request, project)
        .and_return(can_access_summarize_new_merge_request)

      allow_next_instance_of(Gitlab::Llm::FeatureAuthorizer) do |authorizer|
        allow(authorizer).to receive(:allowed?).and_return(true)
      end
    end

    subject(:execute_service) { described_class.new(current_user, project, {}).execute }

    it_behaves_like 'schedules completion worker' do
      subject { described_class.new(current_user, project, options) }

      let(:options) { {} }
      let(:resource) { project }
      let(:action_name) { :summarize_new_merge_request }
    end

    it 'tracks the summarize_new_merge_request internal event with the project and namespace' do
      allow(::Llm::CompletionWorker).to receive(:perform_for)

      expect { execute_service }
        .to trigger_internal_events('summarize_new_merge_request')
        .with(user: current_user, project: project, namespace: project.namespace)
    end

    context 'when user is not member of project group' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when project is not a project' do
      let(:project) { create(:epic, group: group) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when user has no ability to access summarize_new_merge_request' do
      let(:can_access_summarize_new_merge_request) { false }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }

      it 'does not track the summarize_new_merge_request internal event' do
        expect { execute_service }
          .not_to trigger_internal_events('summarize_new_merge_request')
      end
    end
  end
end
