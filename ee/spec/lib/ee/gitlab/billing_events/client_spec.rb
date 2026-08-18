# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BillingEvents::Client, :freeze_time, feature_category: :application_instrumentation do
  let_it_be(:namespace) { create(:group) }

  let(:args) do
    {
      event_type: 'secrets_read',
      category: 'TestCategory',
      unit_of_measure: 'request',
      quantity: 1,
      namespace: namespace
    }
  end

  before do
    allow(Gitlab::Tracking).to receive(:billing_event)
  end

  describe 'secrets_read billing metrics', :clean_gitlab_redis_shared_state do
    subject(:track) { described_class.new.track_billing_event(**args) }

    it 'increments the secrets_read billing metrics' do
      expect { track }
        .to increment_usage_metrics(
          'counts.count_total_usage_billing_event_secrets_read',
          'counts.count_total_usage_billing_event_secrets_read_weekly',
          'counts.count_total_usage_billing_event_secrets_read_monthly'
        )
    end
  end

  describe 'secrets_stored billing metrics', :clean_gitlab_redis_shared_state do
    subject(:track) { described_class.new.track_billing_event(**args) }

    let(:args) do
      {
        event_type: 'secrets_stored',
        category: 'TestCategory',
        unit_of_measure: 'secret',
        quantity: 5,
        namespace: namespace
      }
    end

    it 'increments the secrets_stored billing metrics' do
      expect { track }
        .to increment_usage_metrics(
          'counts.count_total_usage_billing_event_secrets_stored',
          'counts.count_total_usage_billing_event_secrets_stored_weekly',
          'counts.count_total_usage_billing_event_secrets_stored_monthly'
        )
    end
  end

  describe 'realm mapping' do
    using RSpec::Parameterized::TableSyntax

    where(:cloud_connector_realm, :expected_realm) do
      'saas'         | 'SaaS'
      'self-managed' | 'SM'
      'dedicated'    | 'Dedicated'
    end

    with_them do
      before do
        allow(CloudConnector).to receive(:gitlab_realm).and_return(cloud_connector_realm)
      end

      it 'maps to the billing schema realm value' do
        described_class.new.track_billing_event(**args)

        expect(Gitlab::Tracking).to have_received(:billing_event) do |_cat, _action, context:|
          data = context.first.to_json[:data]
          expect(data[:realm]).to eq(expected_realm)
        end
      end
    end
  end

  describe 'deployment_type' do
    before do
      allow(CloudConnector).to receive(:deployment_type).and_return('.com')
    end

    it 'uses CloudConnector deployment_type' do
      described_class.new.track_billing_event(**args)

      expect(Gitlab::Tracking).to have_received(:billing_event) do |_cat, _action, context:|
        data = context.first.to_json[:data]
        expect(data[:deployment_type]).to eq('.com')
      end
    end
  end
end
