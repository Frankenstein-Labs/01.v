# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::ActivateService, feature_category: :plan_provisioning do
  subject(:execute_service) { described_class.new.execute(activation_code) }

  let!(:application_settings) { create(:application_setting) }

  let(:license_key) { build(:gitlab_license, :cloud).export }

  let(:activation_code) { 'activation_code' }
  let(:automated) { false }

  let_it_be(:organization) { create(:organization) }

  def stub_client_activate
    expect(Gitlab::SubscriptionPortal::Client).to receive(:activate)
      .with(activation_code, automated: automated)
      .and_return(customer_dot_response)
  end

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')

    allow(Gitlab::CurrentSettings).to receive(:current_application_settings).and_return(application_settings)
  end

  shared_examples 'call service to update license dependencies' do
    it 'calls the service to update license dependencies with the correct params' do
      expect_next_instance_of(
        GitlabSubscriptions::UpdateLicenseDependenciesService,
        future_subscriptions: future_subscriptions,
        license: an_instance_of(License),
        new_subscription: new_subscription
      ) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      execute_service
    end
  end

  context 'when CustomerDot returns success' do
    let(:future_subscriptions) { [] }
    let(:new_subscription) { false }
    let(:customer_dot_response) do
      {
        success: true,
        license_key: license_key,
        future_subscriptions: future_subscriptions,
        new_subscription: new_subscription
      }
    end

    before do
      stub_client_activate
    end

    it_behaves_like 'call service to update license dependencies'

    it 'triggers SeatLinkData sync' do
      expect_next_instance_of(::Gitlab::SeatLinkData, refresh_token: true) do |sync_link_data|
        expect(sync_link_data).to receive(:sync)
      end

      execute_service
    end

    context 'when there are no future subscriptions' do
      it_behaves_like 'call service to update license dependencies'
    end

    context 'when there are future subscriptions' do
      let(:future_subscriptions) do
        future_date = 4.days.from_now.to_date

        [
          {
            "cloud_license_enabled" => true,
            "offline_cloud_license_enabled" => false,
            "plan" => 'ultimate',
            "name" => 'User Example',
            "company" => 'Example Inc',
            "email" => 'user@example.com',
            "starts_at" => future_date.to_s,
            "expires_at" => (future_date + 1.year).to_s,
            "users_in_license_count" => 10
          }
        ]
      end

      it_behaves_like 'call service to update license dependencies'
    end

    context 'when the activated subscription is a new subscription' do
      let(:new_subscription) { true }

      it_behaves_like 'call service to update license dependencies'
    end

    context 'when the current license key does not match the one returned from activation' do
      it 'creates a new license' do
        previous_license = create(:license, cloud: true, last_synced_at: 3.days.ago)

        freeze_time do
          expect { execute_service }.to change { License.cloud.count }.by(1)

          current_license = License.current
          expect(current_license.id).not_to eq(previous_license.id)
          expect(current_license).to have_attributes(
            data: license_key,
            cloud: true,
            last_synced_at: Time.current
          )
        end
      end
    end

    context 'when the current license key matches the one returned from activation' do
      it 'reuses the current license and updates the last_synced_at' do
        create(:license, cloud: true, last_synced_at: 3.days.ago)
        current_license = create(:license, cloud: true, data: license_key, last_synced_at: 1.day.ago)

        freeze_time do
          expect { execute_service }.not_to change { License.cloud.count }

          expect(License.current).to have_attributes(
            id: current_license.id,
            data: license_key,
            cloud: true,
            last_synced_at: Time.current
          )
        end
      end
    end

    context 'when persisting fails' do
      let(:license_key) { 'invalid key' }

      it 'returns error' do
        expect(execute_service).to match({ errors: [be_a_kind_of(String)], success: false })
      end
    end
  end

  context 'when CustomerDot returns failure' do
    let(:customer_dot_response) { { success: false, errors: ['foo'] } }

    it 'returns error' do
      stub_client_activate

      expect(execute_service).to eq(customer_dot_response)

      expect(License.current&.data).not_to eq(license_key)
    end
  end

  context 'when not self managed instance' do
    let(:customer_dot_response) { { success: false, errors: [described_class::ERROR_MESSAGES[:not_self_managed]] } }

    it 'returns error' do
      allow(Gitlab).to receive(:com?).and_return(true)
      expect(Gitlab::SubscriptionPortal::Client).not_to receive(:activate)

      expect(execute_service).to eq(customer_dot_response)
    end
  end

  context 'when error is raised' do
    it 'captures error' do
      expect(Gitlab::SubscriptionPortal::Client).to receive(:activate).and_raise('foo')

      expect(execute_service).to eq({ success: false, errors: ['foo'] })
    end
  end
end
