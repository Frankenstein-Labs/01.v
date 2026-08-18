# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PersonalAccessTokens::RotateService, feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:token) { create(:personal_access_token) }

  subject(:response) { described_class.new(token.user, token).execute }

  context 'when target user is a service account' do
    let_it_be(:service_account) { create(:user, :service_account) }
    let_it_be_with_reload(:service_token) { create(:personal_access_token, user: service_account) }

    context 'when expires_at is nil', time_travel_to: '2024-08-24' do
      let(:params) { { expires_at: nil } }

      subject(:response) { described_class.new(service_account, service_token, nil, params).execute }

      where(:require_token_expiry, :require_token_expiry_for_service_accounts, :expires_at) do
        true | true | Date.new(2024, 8, 31) # 1 week from now
        true | false | nil
        false | true | Date.new(2024, 8, 31) # 1 week from now
        false | false | nil
      end

      with_them do
        before do
          allow(::Authn::ServiceAccounts).to receive(:free_tier?).and_return(false)
          stub_application_setting(require_personal_access_token_expiry: require_token_expiry)
          stub_ee_application_setting(
            service_access_tokens_expiration_enforced: require_token_expiry_for_service_accounts)
        end

        it "rotates user's own token" do
          expect(response).to be_success

          new_token = response.payload[:personal_access_token]

          expect(new_token.token).not_to eq(service_token.token)
          expect(new_token.expires_at).to eq(expires_at)
          expect(new_token.user).to eq(service_account)
        end
      end
    end
  end

  context 'when max lifetime is set to less than 1 week', :freeze_time do
    before do
      allow(Gitlab::CurrentSettings).to receive(:max_personal_access_token_lifetime_from_now)
        .and_return(2.days.from_now)
    end

    let_it_be_with_reload(:token) { create(:personal_access_token) }

    subject(:response) { described_class.new(token.user, token).execute }

    it "rotates user's own token" do
      expect(response).to be_success

      new_token = response.payload[:personal_access_token]

      expect(new_token.token).not_to eq(token.token)
      expect(new_token.expires_at).to eq(Date.current + 2.days)
      expect(new_token.user).to eq(token.user)
    end
  end

  context 'when max lifetime is set to more than 1 week' do
    before do
      allow(Gitlab::CurrentSettings).to receive(:max_personal_access_token_lifetime_from_now)
        .and_return(10.days.from_now)
    end

    let_it_be_with_reload(:token) { create(:personal_access_token) }

    subject(:response) { described_class.new(token.user, token).execute }

    it "rotates user's own token", :freeze_time do
      expect(response).to be_success

      new_token = response.payload[:personal_access_token]

      expect(new_token.token).not_to eq(token.token)
      expect(new_token.expires_at).not_to eq(Date.current + 10.days)
      expect(new_token.expires_at).to eq(Date.current + 7.days)
      expect(new_token.user).to eq(token.user)
    end
  end

  context "for enterprise_user's token" do
    let_it_be(:current_user) { create(:enterprise_user) }
    let_it_be_with_reload(:token) do
      create(:personal_access_token, user: current_user)
    end

    it "rotates user's own token" do
      expect(response).to be_success

      new_token = response.payload[:personal_access_token]

      expect(new_token.token).not_to eq(token.token)
      expect(new_token.user).to eq(token.user)
      expect(new_token.user_type).to eq(token.user_type)
      expect(new_token.group_id).to eq(token.group_id)
      expect(new_token.user.namespace).to eq(token.user.namespace)
      expect(new_token.organization).to eq(token.organization)
      expect(new_token.description).to eq(token.description)
    end
  end

  context "for group service account's token" do
    let_it_be(:group) { create(:group) }
    let_it_be(:current_user) { create(:user, :service_account, provisioned_by_group: group) }
    let_it_be_with_reload(:token) do
      create(:personal_access_token, user: current_user)
    end

    it "rotates user's own token" do
      expect(response).to be_success

      new_token = response.payload[:personal_access_token]

      expect(new_token.token).not_to eq(token.token)
      expect(new_token.user).to eq(token.user)
      expect(new_token.user_type).to eq(token.user_type)
      expect(new_token.group_id).to eq(token.group_id)
      expect(new_token.user.namespace).to eq(token.user.namespace)
      expect(new_token.organization).to eq(token.organization)
      expect(new_token.description).to eq(token.description)
    end
  end
end
