# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::IdentityVerification::Settings, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  describe '.arkose_client_id' do
    subject { described_class.arkose_client_id }

    before do
      stub_application_setting(arkose_labs_client_xid: 'client_id')
    end

    it { is_expected.to eq 'client_id' }
  end

  describe '.arkose_client_secret' do
    subject { described_class.arkose_client_secret }

    before do
      stub_application_setting(arkose_labs_client_secret: 'client_secret')
    end

    it { is_expected.to eq 'client_secret' }
  end

  describe '.arkose_public_api_key' do
    subject { described_class.arkose_public_api_key }

    context 'when set in application settings' do
      let(:setting_value) { 'setting_public_key' }

      before do
        stub_application_setting(arkose_labs_public_api_key: setting_value)
      end

      it { is_expected.to eq setting_value }
    end

    context 'when NOT set in application settings' do
      let(:env_var_value) { 'env_var_public_key' }

      before do
        stub_env('ARKOSE_LABS_PUBLIC_KEY', env_var_value)
      end

      it { is_expected.to eq env_var_value }
    end
  end

  describe '.arkose_private_api_key' do
    subject { described_class.arkose_private_api_key }

    context 'when set in application settings' do
      let(:setting_value) { 'setting_value' }

      before do
        stub_application_setting(arkose_labs_private_api_key: setting_value)
      end

      it { is_expected.to eq setting_value }
    end

    context 'when NOT set in application settings' do
      let(:env_var_value) { 'env_var_value' }

      before do
        stub_env('ARKOSE_LABS_PRIVATE_KEY', env_var_value)
      end

      it { is_expected.to eq env_var_value }
    end
  end

  describe '.arkose_labs_domain' do
    subject { described_class.arkose_labs_domain }

    let(:setting_value) { 'setting_value' }

    before do
      stub_application_setting(arkose_labs_namespace: setting_value)
    end

    it { is_expected.to eq "#{setting_value}-api.arkoselabs.com" }
  end

  describe '.arkose_enabled?' do
    let_it_be(:a_user) { create(:user) }

    subject(:enabled) { described_class.arkose_enabled?(user: user, user_agent: 'user_agent') }

    context 'when fail-open is active' do
      let(:user) { a_user }

      before do
        allow(AntiAbuse::IdentityVerification::ArkoseFailOpen).to receive(:active?).and_return(true)
      end

      it 'returns false immediately' do
        expect(enabled).to be false
      end

      it 'short-circuits other checks' do
        expect(::Gitlab::CurrentSettings).not_to receive(:arkose_labs_enabled)
        expect(described_class).not_to receive(:arkose_public_api_key)
        expect(described_class).not_to receive(:arkose_private_api_key)

        enabled
      end
    end

    context 'when fail-open is not active' do
      where(:private_key, :public_key, :namespace, :qa_request, :user, :group_saml_user, :result) do
        nil       | 'public' | 'namespace' | false | ref(:a_user) | false | false
        'private' | nil      | 'namespace' | false | ref(:a_user) | false | false
        'private' | 'public' | nil         | false | ref(:a_user) | false | false
        'private' | 'public' | 'namespace' | true  | ref(:a_user) | false | false
        'private' | 'public' | 'namespace' | false | ref(:a_user) | true  | false
        'private' | 'public' | 'namespace' | false | ref(:a_user) | false | true
        'private' | 'public' | 'namespace' | false | nil          | false | true
      end

      with_them do
        before do
          allow(AntiAbuse::IdentityVerification::ArkoseFailOpen).to receive(:active?).and_return(false)

          allow(described_class).to receive_messages(
            arkose_private_api_key: private_key,
            arkose_public_api_key: public_key
          )

          stub_application_setting(arkose_labs_namespace: namespace)
          allow(::Gitlab::Qa).to receive(:request?).with('user_agent').and_return(qa_request)
          create(:group_saml_identity, user: user) if group_saml_user
        end

        context 'when arkose labs is enabled' do
          before do
            stub_application_setting(arkose_labs_enabled: true)
          end

          it { is_expected.to eq result }
        end

        context 'when arkose labs is disabled' do
          before do
            stub_application_setting(arkose_labs_enabled: false)
          end

          it { is_expected.to be false }
        end
      end
    end
  end

  describe '.arkose_data_exchange_key' do
    subject { described_class.arkose_data_exchange_key }

    context 'when set in application settings' do
      let(:setting_value) { 'setting_public_key' }

      before do
        stub_application_setting(arkose_labs_data_exchange_key: setting_value)
      end

      it { is_expected.to eq setting_value }
    end

    context 'when not set in application settings' do
      before do
        stub_application_setting(arkose_labs_data_exchange_key: nil)
      end

      it { is_expected.to be_nil }
    end
  end
end
