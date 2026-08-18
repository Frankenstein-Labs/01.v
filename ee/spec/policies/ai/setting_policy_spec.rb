# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SettingPolicy, :enable_admin_mode, feature_category: :"self-hosted_models" do
  subject(:policy) { described_class.new(current_user, duo_settings) }

  let_it_be(:duo_settings) { create(:ai_settings, duo_core_features_enabled: true) }
  let_it_be_with_reload(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

  describe 'read_ai_gateway_timeout' do
    context 'when user can manage self-hosted models' do
      it { is_expected.to be_allowed(:read_ai_gateway_timeout) }
    end

    context 'when user cannot manage self-hosted models but can update AIGW timeout' do
      before do
        allow(current_user).to receive(:can?).with(:manage_self_hosted_models_settings).and_return(false)
        allow(current_user).to receive(:can?).with(:update_ai_gateway_timeout, :global).and_return(true)
      end

      it { is_expected.to be_allowed(:read_ai_gateway_timeout) }
    end

    context 'when user cannot manage self-hosted models or update AIGW timeout' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(:read_ai_gateway_timeout) }
    end
  end

  describe 'read_self_hosted_models_settings' do
    context 'when user is authorized to manage Duo self-hosted settings' do
      it { is_expected.to be_allowed(:read_self_hosted_models_settings) }
    end

    context 'when user is not authorized to manage Duo self-hosted settings' do
      before do
        allow(current_user).to receive(:can?).with(:manage_self_hosted_models_settings).and_return(false)
      end

      it { is_expected.to be_disallowed(:read_self_hosted_models_settings) }
    end
  end

  describe 'read_duo_core_settings' do
    context 'when user is nil' do
      let!(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_duo_core_settings) }
    end

    context 'when user is not authorized to manage Duo Core settings' do
      before do
        stub_licensed_features(code_suggestions: false, ai_chat: false)
      end

      it { is_expected.to be_disallowed(:read_duo_core_settings) }
    end

    context 'when user is authorized to manage Duo Core settings' do
      it { is_expected.to be_allowed(:read_duo_core_settings) }
    end
  end

  describe 'update_ai_role_based_permission_settings' do
    context 'when user is nil' do
      let!(:current_user) { nil }

      it { is_expected.to be_disallowed(:update_ai_role_based_permission_settings) }
    end

    context 'when user is not authorized to manage Duo Core settings' do
      before do
        stub_licensed_features(code_suggestions: false, ai_chat: false)
      end

      it { is_expected.to be_disallowed(:update_ai_role_based_permission_settings) }
    end

    context 'when user is authorized to manage Duo Core settings' do
      it { is_expected.to be_allowed(:update_ai_role_based_permission_settings) }
    end
  end

  describe 'read_ai_role_based_permission_settings' do
    context 'when user is nil' do
      let!(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_ai_role_based_permission_settings) }
    end

    context 'when user is not authorized to manage Duo Core settings' do
      before do
        stub_licensed_features(code_suggestions: false, ai_chat: false)
      end

      it { is_expected.to be_disallowed(:read_ai_role_based_permission_settings) }
    end

    context 'when user is authorized to manage Duo Core settings' do
      it { is_expected.to be_allowed(:read_ai_role_based_permission_settings) }
    end
  end
end
