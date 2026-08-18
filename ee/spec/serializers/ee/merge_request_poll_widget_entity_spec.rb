# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestPollWidgetEntity, feature_category: :merge_trains do
  include ProjectForksHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:target_branch) { 'feature' }

  let(:project) { create(:project, :repository, developers: user) }
  let(:request) { double('request', current_user: user) }
  let(:merge_request) do
    create(:merge_request, source_project: project, target_project: project, target_branch: target_branch)
  end

  subject(:entity) do
    described_class.new(merge_request, current_user: user, request: request).as_json
  end

  describe 'Merge Trains' do
    let!(:merge_train) { create(:merge_train_car, merge_request: merge_request) }

    before do
      stub_licensed_features(merge_pipelines: true, merge_trains: true)
      project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)
    end

    it 'has merge train entity' do
      expect(entity).to include(:merge_trains_skip_train_allowed)
    end

    it 'exposes whether the merge train is enforced for the current user' do
      expect(entity[:merge_train_enforced]).to be(false)
    end

    context 'when merge train enforcement is enabled' do
      before do
        project.ci_cd_settings.update!(merge_train_enforcement: :enforce_for_all_users)
      end

      it 'is true' do
        expect(entity[:merge_train_enforced]).to be(true)
      end
    end
  end

  describe 'can_resolve_with_ai' do
    it 'exposes the value from the merge request' do
      allow(merge_request).to receive(:can_resolve_with_ai?).with(user).and_return(true)

      expect(entity[:can_resolve_with_ai]).to be true
    end
  end

  describe 'auto merge' do
    context 'when head pipeline is running' do
      before do
        create(
          :ci_pipeline, :running,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
        merge_request.update_head_pipeline
      end

      it 'returns available auto merge strategies' do
        expect(entity[:available_auto_merge_strategies]).to(
          eq(%w[merge_when_checks_pass])
        )
      end
    end

    context 'when head pipeline is finished and approvals are pending' do
      before do
        create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: 1, users: [user])
        create(
          :ci_pipeline, :success,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
        merge_request.update_head_pipeline
      end

      it 'returns available auto merge strategies' do
        expect(entity[:available_auto_merge_strategies]).to(
          eq(%w[merge_when_checks_pass])
        )
      end
    end
  end

  describe 'squash fields' do
    context 'when branch rule squash option is defined for target branch' do
      let(:protected_branch) { create(:protected_branch, name: target_branch, project: project) }
      let(:branch_rule_squash_option) do
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
