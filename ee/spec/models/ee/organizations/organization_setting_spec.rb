# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::OrganizationSetting, feature_category: :vulnerability_management do
  let_it_be(:organization) { create(:organization) }

  subject(:setting) { build(:organization_setting, organization: organization) }

  describe 'security_tracked_context_quota' do
    describe 'validation' do
      it { is_expected.to allow_value(nil).for(:security_tracked_context_quota) }
      it { is_expected.to allow_value(1).for(:security_tracked_context_quota) }
      it { is_expected.to allow_value(100).for(:security_tracked_context_quota) }
      it { is_expected.not_to allow_value(0).for(:security_tracked_context_quota) }
      it { is_expected.not_to allow_value(-1).for(:security_tracked_context_quota) }
      it { is_expected.not_to allow_value(1.5).for(:security_tracked_context_quota) }
    end

    describe '#security_tracked_context_quota_with_default' do
      context 'when quota is explicitly set' do
        before do
          setting.security_tracked_context_quota = 10
        end

        it 'returns the explicit value' do
          expect(setting.security_tracked_context_quota_with_default).to eq(10)
        end

        it 'ignores SaaS and application settings defaults' do
          stub_saas_features(gitlab_saas_features: true)
          stub_application_setting(default_security_tracked_context_quota: 5)

          expect(setting.security_tracked_context_quota_with_default).to eq(10)
        end
      end

      context 'when quota is not set' do
        before do
          setting.security_tracked_context_quota = nil
        end

        context 'on GitLab.com (SaaS)' do
          before do
            stub_saas_features(gitlab_saas_features: true)
          end

          it 'returns the application setting default when set' do
            stub_application_setting(default_security_tracked_context_quota: 5)

            expect(setting.security_tracked_context_quota_with_default).to eq(5)
          end

          it 'returns 2 as fallback when application setting is nil' do
            stub_application_setting(default_security_tracked_context_quota: nil)

            expect(setting.security_tracked_context_quota_with_default).to eq(2)
          end
        end

        context 'on self-managed' do
          before do
            stub_saas_features(gitlab_saas_features: false)
          end

          it 'returns nil (no quota enforced)' do
            stub_application_setting(default_security_tracked_context_quota: 5)

            expect(setting.security_tracked_context_quota_with_default).to be_nil
          end
        end
      end
    end

    describe '#security_tracked_context_quota_explicitly_set?' do
      it 'returns true when quota is set' do
        setting.security_tracked_context_quota = 5

        expect(setting.security_tracked_context_quota_explicitly_set?).to be(true)
      end

      it 'returns false when quota is nil' do
        setting.security_tracked_context_quota = nil

        expect(setting.security_tracked_context_quota_explicitly_set?).to be(false)
      end
    end
  end
end
