# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectCiCdSetting, feature_category: :continuous_integration do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create_default(:project) }
  let(:settings) { project.reload.ci_cd_settings }

  describe '#restrict_pipeline_cancellation_role' do
    it 'defines an enum' do
      described_class.restrict_pipeline_cancellation_roles.each_key do |role|
        settings.update!(restrict_pipeline_cancellation_role: role)
        expect(settings.restrict_pipeline_cancellation_role).to eq role
      end
    end

    it 'defaults to developer' do
      expect(settings.restrict_pipeline_cancellation_role).to eq('developer')
    end
  end

  describe '#merge_pipelines_enabled?' do
    subject { project.merge_pipelines_enabled? }

    let(:project) { create(:project) }
    let(:merge_pipelines_enabled) { true }

    before do
      project.merge_pipelines_enabled = merge_pipelines_enabled
    end

    context 'when Merge pipelines (EEP) is available through license' do
      before do
        stub_licensed_features(merge_pipelines: true)
      end

      it { is_expected.to be_truthy }

      context 'when project setting is disabled' do
        let(:merge_pipelines_enabled) { false }

        it { is_expected.to be_falsy }
      end
    end

    context 'when Merge pipelines (EEP) is available through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it { is_expected.to be_truthy }

      context 'when project setting is disabled' do
        let(:merge_pipelines_enabled) { false }

        it { is_expected.to be_falsy }
      end
    end

    context 'when usage ping is disabled on free license' do
      before do
        stub_usage_ping_features(false)
      end

      it { is_expected.to be_falsy }
    end

    context 'when Merge pipelines (EEP) is unavailable' do
      before do
        stub_licensed_features(merge_pipelines: false)
      end

      it { is_expected.to be_falsy }

      context 'when project setting is disabled' do
        let(:merge_pipelines_enabled) { false }

        it { is_expected.to be_falsy }
      end
    end
  end

  describe '#merge_trains_enabled?' do
    subject(:result) { project.merge_trains_enabled? }

    let(:project) { create(:project) }

    where(:merge_pipelines_enabled, :merge_trains_enabled, :feature_available, :expected_result) do
      true      | true     | true    | true
      true      | false    | true    | false
      false     | false    | true    | false
      false     | true     | true    | false
      true      | true     | false   | false
      true      | false    | false   | false
      false     | false    | false   | false
    end

    with_them do
      before do
        stub_licensed_features(merge_pipelines: feature_available, merge_trains: feature_available)
      end

      it 'returns merge trains availability' do
        project.update!(merge_pipelines_enabled: merge_pipelines_enabled, merge_trains_enabled: merge_trains_enabled)

        expect(result).to eq(expected_result)
      end
    end
  end

  describe '#merge_trains_skip_train_allowed?' do
    subject(:result) { project.merge_trains_skip_train_allowed? }

    let(:project) { create(:project) }

    where(:merge_pipelines_enabled, :merge_trains_enabled, :skip_train_allowed, :ff_only, :rebase, :feature_available,
      :expected_result) do
      true  | true  | true  | false | false | true  | true
      false | true  | true  | false | false | true  | false
      true  | false | true  | false | false | true  | false
      true  | true  | false | false | false | true  | false
      true  | true  | true  | false | false | false | false

      # For flags rebase and ff_only
      true  | true  | true  | true  | true  | true  | false
      true  | true  | true  | false | true  | true  | false
      true  | true  | true  | true  | false | true  | false
    end

    with_them do
      before do
        stub_licensed_features(merge_pipelines: feature_available, merge_trains: feature_available)
      end

      it 'returns true only if all of the related settings and features are true' do
        project.update!(
          merge_pipelines_enabled: merge_pipelines_enabled,
          merge_trains_enabled: merge_trains_enabled,
          merge_trains_skip_train_allowed: skip_train_allowed,
          merge_requests_rebase_enabled: rebase,
          merge_requests_ff_only_enabled: ff_only
        )

        expect(result).to eq(expected_result)
      end
    end
  end

  describe '#merge_train_enforced_for?' do
    let_it_be(:project, freeze: false) { create(:project) }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:admin) { create(:admin) }

    let(:owner) { project.first_owner }

    before do
      stub_licensed_features(merge_pipelines: true, merge_trains: true)
      project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)
    end

    context 'when enforcement is allow_bypass (default)' do
      it 'is not enforced for anyone' do
        expect(project.merge_train_enforced_for?(maintainer)).to be(false)
      end
    end

    context 'when enforcement is enforce_for_all_users' do
      before do
        project.ci_cd_settings.update!(merge_train_enforcement: :enforce_for_all_users)
      end

      it 'is enforced for everyone, including owners', :aggregate_failures do
        expect(project.merge_train_enforced_for?(maintainer)).to be(true)
        expect(project.merge_train_enforced_for?(owner)).to be(true)
      end

      it 'is enforced for administrators', :enable_admin_mode do
        expect(project.merge_train_enforced_for?(admin)).to be(true)
      end

      context 'when merge trains are not available' do
        before do
          stub_licensed_features(merge_pipelines: true, merge_trains: false)
        end

        it { expect(project.merge_train_enforced_for?(maintainer)).to be(false) }
      end
    end

    context 'when enforcement is enforce_with_owner_override' do
      before do
        project.ci_cd_settings.update!(merge_train_enforcement: :enforce_with_owner_override)
      end

      it 'is enforced for non-owners but exempts owners', :aggregate_failures do
        expect(project.merge_train_enforced_for?(maintainer)).to be(true)
        expect(project.merge_train_enforced_for?(owner)).to be(false)
      end

      it 'exempts administrators', :enable_admin_mode do
        expect(project.merge_train_enforced_for?(admin)).to be(false)
      end
    end
  end

  describe '#auto_rollback_enabled?' do
    using RSpec::Parameterized::TableSyntax

    let(:project) { create(:project) }

    where(:license_feature, :actual_setting) do
      true  | true
      false | true
      true  | true
      false | true
      true  | false
      false | false
      true  | false
      false | false
    end

    with_them do
      before do
        stub_licensed_features(auto_rollback: license_feature)
        project.auto_rollback_enabled = actual_setting
      end

      it 'is only enabled if set and both the license and the feature flag allows' do
        expect(project.auto_rollback_enabled?).to be(actual_setting && license_feature)
      end
    end
  end

  describe '#merge_pipelines_were_disabled?' do
    subject { project.merge_pipelines_were_disabled? }

    let(:project) { create(:project) }

    before do
      stub_licensed_features(merge_pipelines: true, merge_trains: true)
    end

    context 'when merge pipelines option was enabled' do
      before do
        project.update!(merge_pipelines_enabled: true)
      end

      context 'when merge pipelines option is disabled' do
        before do
          project.update!(merge_pipelines_enabled: false)
        end

        it { is_expected.to be true }
      end

      context 'when merge pipelines option is intact' do
        it { is_expected.to be false }
      end
    end

    context 'when merge pipelines option was disabled' do
      before do
        project.update!(merge_pipelines_enabled: false)
      end

      context 'when merge pipelines option is disabled' do
        before do
          project.update!(merge_pipelines_enabled: true)
        end

        it { is_expected.to be false }
      end

      context 'when merge pipelines option is intact' do
        it { is_expected.to be false }
      end
    end
  end
end
