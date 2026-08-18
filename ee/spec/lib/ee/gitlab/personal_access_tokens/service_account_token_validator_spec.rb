# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::Gitlab::PersonalAccessTokens::ServiceAccountTokenValidator, feature_category: :system_access do
  describe '#expiry_enforced?' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }
    let(:validator) { described_class.new(user) }

    context 'when saas enabled', :saas do
      context 'when not service account user' do
        it 'returns true' do
          expect(validator.expiry_enforced?).to be(true)
        end
      end

      context 'when service account user' do
        let(:user) { create(:service_account) }

        context 'when provisioned by group' do
          before do
            user.provisioned_by_group_id = group.id
            user.save!
            allow(::Authn::ServiceAccounts).to receive(:free_tier_namespace?).and_return(false)
            group.namespace_settings.update!(service_access_tokens_expiration_enforced: false)
          end

          it "returns setting value" do
            expect(validator.expiry_enforced?).to be(false)
          end
        end

        context 'when not provisioned by group' do
          it "returns true" do
            expect(validator.expiry_enforced?).to be(true)
          end
        end

        context 'when on free tier' do
          context 'when provisioned by group' do
            before do
              user.provisioned_by_group_id = group.id
              user.save!
              allow(::Authn::ServiceAccounts).to receive(:free_tier_namespace?).and_return(true)
              group.namespace_settings.update!(service_access_tokens_expiration_enforced: false)
            end

            it 'returns true (always enforced on free tier regardless of setting)' do
              expect(validator.expiry_enforced?).to be(true)
            end
          end

          context 'when not provisioned by group' do
            it 'returns true (not considered free tier, falls back to default SaaS behavior)' do
              expect(validator.expiry_enforced?).to be(true)
            end
          end
        end
      end
    end

    context 'when self managed' do
      context 'when not service account user' do
        it 'returns true' do
          expect(validator.expiry_enforced?).to be(true)
        end
      end

      context 'when service account user' do
        let(:user) { create(:service_account) }
        let!(:application_settings) { create(:application_setting) }

        it "returns setting value" do
          allow(::Authn::ServiceAccounts).to receive(:free_tier?).and_return(false)
          stub_ee_application_setting(service_access_tokens_expiration_enforced: false)

          expect(validator.expiry_enforced?).to be(false)
        end
      end
    end
  end
end
