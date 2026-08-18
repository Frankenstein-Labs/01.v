# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Ci::PipelinesHelper, feature_category: :continuous_integration do
  include Devise::Test::ControllerHelpers

  let_it_be(:project) { build_stubbed(:project) }

  describe '#pipelines_list_data' do
    let_it_be(:current_user) { build_stubbed(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:user_can_run_jobs?).and_return(authorized)
      end
    end

    subject(:data) { helper.pipelines_list_data(project) }

    context 'when the user is authorized to run jobs' do
      let(:authorized) { true }

      it 'includes the expected identity verification params' do
        expect(data).to include(
          identity_verification_required: 'false',
          identity_verification_path: identity_verification_path
        )
      end

      context 'when the user has the `:admin_runners` permission' do
        before do
          allow_next_instance_of(Authz::CustomAbility, current_user, project) do |ability|
            allow(ability).to receive(:allowed?).with(:admin_runners).and_return(true)
          end
        end

        it { is_expected.to include(reset_cache_path: reset_cache_project_settings_ci_cd_path(project)) }
      end
    end

    context 'when the user is not authorized to run jobs' do
      let(:authorized) { false }

      it 'includes the expected identity verification params' do
        expect(data).to include(
          identity_verification_required: 'true',
          identity_verification_path: identity_verification_path
        )
      end
    end

    context 'when the user is nil' do
      let(:current_user) { nil }

      it 'includes the expected identity verification params' do
        expect(data).to include(
          identity_verification_required: 'false',
          identity_verification_path: identity_verification_path
        )
      end
    end
  end

  describe '#show_iv_alert_for_pipelines_list?' do
    subject { helper.send(:show_iv_alert_for_pipelines_list?, project) }

    context 'when current_user is nil' do
      before do
        allow(helper).to receive(:current_user).and_return(nil)
      end

      it { is_expected.to be false }
    end
  end

  describe '#new_pipeline_data' do
    subject(:data) { helper.new_pipeline_data(project) }

    it 'includes identity_verification_path' do
      expect(data[:identity_verification_path]).to eq identity_verification_path
    end
  end
end
