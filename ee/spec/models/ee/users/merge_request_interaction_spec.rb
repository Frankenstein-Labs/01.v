# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Users::MergeRequestInteraction do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:current_user) { nil }

  subject { described_class.new(user: user, merge_request: merge_request, current_user: current_user) }

  describe '#applicable_approval_rules' do
    before do
      merge_request.reset
      merge_request.clear_memoization(:approval_state)
    end

    context 'when there are no approval rules' do
      it { is_expected.to have_attributes(applicable_approval_rules: be_empty) }
    end

    context 'when there are approval rules' do
      before do
        create(:approval_merge_request_rule, merge_request: merge_request)
        create(:code_owner_rule, merge_request: merge_request)
        create(:any_approver_rule, merge_request: merge_request)
      end

      context 'when the feature is not available' do
        it { is_expected.to have_attributes(applicable_approval_rules: be_empty) }
      end

      context 'when the feature is available' do
        before do
          stub_licensed_features(merge_request_approvers: true)
        end

        it { is_expected.to have_attributes(applicable_approval_rules: be_empty) }

        context 'when the user is associated with a rule' do
          let(:rule) { create(:code_owner_rule, merge_request: merge_request) }

          before do
            create(:code_owner_rule, merge_request: merge_request) # irrelevant rule
            rule.users << user
          end

          specify do
            is_expected.to have_attributes(
              applicable_approval_rules: contain_exactly(
                have_attributes(approval_rule: rule)
              )
            )
          end
        end
      end
    end
  end

  describe '#can_update?' do
    let_it_be(:current_user) { create(:user) }

    context 'when user is Duo Code review bot' do
      let_it_be(:user) { create(:user, user_type: :duo_code_review_bot) }

      context 'when current user has permission' do
        before do
          allow(merge_request.project).to receive(:ai_review_merge_request_allowed?).and_return(true)
        end

        it { is_expected.to be_can_update }
      end

      context 'when current user does not have permission' do
        before do
          allow(merge_request.project).to receive(:ai_review_merge_request_allowed?).and_return(false)
        end

        it { is_expected.not_to be_can_update }
      end
    end
  end
end
