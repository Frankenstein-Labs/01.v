# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::AccessTokensHelper, feature_category: :system_access do
  describe '#expires_at_field_data', :freeze_time do
    context 'when personal_access_token_max_expiry_date is nil' do
      before do
        allow(helper).to receive_messages(
          # The `false` condition is tested in the CE test.
          personal_access_token_expiration_policy_licensed?: true,
          personal_access_token_expiration_policy_enabled?: true,
          personal_access_token_max_expiry_date: nil,
          max_expiration_days: 365
        )
      end

      it 'returns expected hash' do
        expect(helper.expires_at_field_data).to eq({
          min_date: 1.day.from_now.iso8601,
          max_date: nil,
          max_expiration_days: 365,
          pat_expiration_required: 'true'
        })
      end
    end

    context 'when personal_access_token_max_expiry_date is a date' do
      before do
        travel_to Date.new(2022, 2, 2)

        allow(helper).to receive_messages(
          personal_access_token_expiration_policy_enabled?: true, # The `false` condition is tested in the CE test.
          personal_access_token_max_expiry_date: Time.new(2022, 3, 2, 10, 30, 45, 'UTC'),
          max_expiration_days: 25
        )
      end

      it 'returns expected hash' do
        expect(helper.expires_at_field_data).to eq({
          min_date: '2022-02-03T00:00:00Z',
          max_date: '2022-03-02T10:30:45Z',
          max_expiration_days: 25,
          pat_expiration_required: 'true'
        })
      end
    end

    context 'when the EE expiry policy is enabled but require_personal_access_token_expiry is off' do
      before do
        travel_to Date.new(2022, 2, 2)
        stub_application_setting(require_personal_access_token_expiry: false)

        allow(helper).to receive_messages(
          personal_access_token_expiration_policy_enabled?: true,
          personal_access_token_max_expiry_date: Time.new(2022, 3, 2, 10, 30, 45, 'UTC'),
          max_expiration_days: 25
        )
      end

      it 'reports max_date from the EE policy while expiration remains optional' do
        expect(helper.expires_at_field_data).to eq({
          min_date: '2022-02-03T00:00:00Z',
          max_date: '2022-03-02T10:30:45Z',
          max_expiration_days: 25,
          pat_expiration_required: 'false'
        })
      end
    end
  end

  describe '#max_expiration_days' do
    subject { helper.send(:max_expiration_days) }

    let(:group) do
      build(:group, max_personal_access_token_lifetime: group_level_max_personal_access_token_lifetime)
    end

    let(:group_level_max_personal_access_token_lifetime) { nil }
    let(:instance_level_max_personal_access_token_lifetime) { nil }
    let(:user) { build(:user) }
    let(:managed_user) { build(:user, managing_group: group) }

    before do
      allow(helper).to receive(:current_user) { user }
      stub_application_setting(max_personal_access_token_lifetime: instance_level_max_personal_access_token_lifetime)
    end

    context 'when the `personal_access_token_expiration_policy` feature is not licensed' do
      before do
        stub_licensed_features(personal_access_token_expiration_policy: false)
      end

      # Falls through to the CE implementation.
      it { is_expected.to eq(::PersonalAccessToken.max_expiration_lifetime_in_days) }
    end

    context 'when the `personal_access_token_expiration_policy` feature is licensed' do
      before do
        stub_licensed_features(personal_access_token_expiration_policy: true)
      end

      shared_examples_for 'returns the CE value when no policy applies' do
        # Falls through to the CE implementation because the EE expiration policy is not enabled for this user.
        it { is_expected.to eq(::PersonalAccessToken.max_expiration_lifetime_in_days) }
      end

      shared_examples_for 'falls back to instance level' do
        context 'when the instance has a max token lifetime configured' do
          let(:instance_level_max_personal_access_token_lifetime) { 20 }

          it { is_expected.to eq(20) }
        end

        context 'when the instance does not have a max token lifetime configured' do
          it_behaves_like 'returns the CE value when no policy applies'
        end
      end

      context 'when the current user belongs to a managed group' do
        let(:user) { managed_user }

        context 'when the managed group has a max token lifetime configured' do
          let(:group_level_max_personal_access_token_lifetime) { 10 }

          it { is_expected.to eq(10) }
        end

        context 'when the managed group does not have a max token lifetime configured' do
          it_behaves_like 'falls back to instance level'
        end
      end

      context 'when the current user does not belong to a managed group' do
        it_behaves_like 'falls back to instance level'
      end
    end
  end

  describe '#personal_access_token_data' do
    let_it_be(:user) { build_stubbed(:user) }

    subject(:data) { helper.personal_access_token_data({})[:access_token] }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'returns agentic_available true when the permissions assistant agent is available' do
      expect(user).to receive(:foundational_agent_available?).with('duo_permissions_assistant').and_return(true)
      expect(data[:agentic_available]).to eq('true')
    end

    it 'returns agentic_available false when the permissions assistant agent is not available' do
      expect(user).to receive(:foundational_agent_available?).with('duo_permissions_assistant').and_return(false)
      expect(data[:agentic_available]).to eq('false')
    end
  end
end
