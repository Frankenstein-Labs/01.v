# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestPollCachedWidgetEntity, feature_category: :merge_trains do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:target_branch) { 'feature' }

  let(:request) { double('request', current_user: user, project: project) }
  let(:title) { 'MR title' }
  let(:description) { 'MR description' }
  let(:merge_request) do
    create(
      :merge_request,
      source_project: project,
      target_project: project,
      target_branch: target_branch,
      title: title,
      description: description
    )
  end

  subject(:entity) { described_class.new(merge_request, request: request).as_json }

  it 'includes policy violation status' do
    is_expected.to include(:policy_violation)
  end

  describe 'jira_associations' do
    context 'when feature is available' do
      let_it_be(:jira_integration) { create(:jira_integration, project: project, active: true) }

      before do
        stub_licensed_features(jira_issues_integration: true, jira_issue_association_enforcement: true)
      end

      it { is_expected.to include(:jira_associations) }

      shared_examples 'contains the issue key specified in MR title / description' do
        context 'when Jira issue is provided in MR title' do
          let(:issue_key) { 'SIGNUP-1234' }
          let(:title) { "Fixes sign up issue #{issue_key}" }

          it { expect(entity[:jira_associations][:issue_keys]).to contain_exactly(issue_key) }
        end

        context 'when Jira issue is provided in MR description' do
          let(:issue_key) { 'SECURITY-1234' }
          let(:description) { "Related to #{issue_key}" }

          it { expect(entity[:jira_associations][:issue_keys]).to contain_exactly(issue_key) }
        end
      end

      shared_examples 'when issue key is NOT specified in MR title / description' do
        let(:title) { "Fixes sign up issue" }
        let(:description) { "Prevent spam sign ups by adding a rate limiter" }

        it { expect(entity[:jira_associations][:issue_keys]).to be_empty }
      end

      context 'when jira issue is required for merge' do
        before do
          project.create_project_setting(prevent_merge_without_jira_issue: true)
        end

        it { expect(entity[:jira_associations][:enforced]).to be_truthy }

        it_behaves_like 'contains the issue key specified in MR title / description'
        it_behaves_like 'when issue key is NOT specified in MR title / description'
      end

      context 'when jira issue is NOT required for merge' do
        before do
          project.create_project_setting(prevent_merge_without_jira_issue: false)
        end

        it { expect(entity[:jira_associations][:enforced]).to be_falsey }

        it_behaves_like 'contains the issue key specified in MR title / description'
        it_behaves_like 'when issue key is NOT specified in MR title / description'
      end
    end

    context 'when feature is NOT available' do
      using RSpec::Parameterized::TableSyntax

      where(licensed: [true, false])

      with_them do
        before do
          stub_licensed_features(jira_issue_association_enforcement: licensed)
        end

        it { is_expected.not_to include(:jira_associations) }
      end
    end
  end

  describe 'squash fields' do
    context 'when branch rule squash option is defined for target branch' do
      let_it_be(:protected_branch) { create(:protected_branch, name: target_branch, project: project) }
      let_it_be_with_reload(:branch_rule_squash_option) do
        create(:branch_rule_squash_option, project: project, protected_branch: protected_branch)
      end

      where(:project_squash_option, :squash_option, :value, :default, :readonly) do
        'default_off' | 'always'      | true  | true  | true
        'default_on'  | 'never'       | false | false | true
        'never'       | 'default_on'  | false | true  | false
        'always'      | 'default_off' | false | false | false
      end

      with_them do
        before do
          project.project_setting.update!(squash_option: project_squash_option)
          branch_rule_squash_option.update!(squash_option: squash_option)
        end

        it 'the key reflects the project squash option value' do
          expect(entity[:squash_on_merge]).to eq(value)
          expect(entity[:squash_enabled_by_default]).to eq(default)
          expect(entity[:squash_readonly]).to eq(readonly)
        end
      end
    end

    context 'when no branch rule squash option exists' do
      where(:project_squash_option, :value, :default, :readonly) do
        'always'      | true  | true  | true
        'never'       | false | false | true
        'default_on'  | false | true  | false
        'default_off' | false | false | false
      end

      with_them do
        before do
          project.project_setting.update!(squash_option: project_squash_option)
        end

        it 'the key reflects the project squash option value' do
          expect(entity[:squash_on_merge]).to eq(value)
          expect(entity[:squash_enabled_by_default]).to eq(default)
          expect(entity[:squash_readonly]).to eq(readonly)
        end
      end
    end
  end
end
