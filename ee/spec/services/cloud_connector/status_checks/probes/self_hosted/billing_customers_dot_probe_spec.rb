# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::SelfHosted::BillingCustomersDotProbe,
  feature_category: :duo_setting do
  subject(:probe) { described_class.new }

  let(:url) { 'https://customers.example.com' }

  before do
    allow(::Gitlab::Routing.url_helpers).to receive(:subscription_portal_url).and_return(url)
  end

  describe '#execute' do
    context 'when Customers Dot is reachable' do
      before do
        WebMock.stub_request(:head, url).to_return(status: 200)
      end

      it 'returns a success result named after the probe', :aggregate_failures do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.name).to eq(:billing_customers_dot_probe)
        expect(result.success?).to be(true)
        expect(result.message).to match('customers.example.com reachable')
      end
    end

    context 'when the connection is blocked' do
      before do
        WebMock.stub_request(:head, url).to_raise(Gitlab::HTTP_V2::BlockedUrlError.new('URL blocked'))
      end

      it 'returns a failure result with firewall guidance', :aggregate_failures do
        result = probe.execute

        expect(result.success?).to be(false)
        expect(result.message).to match('customers.example.com connection failed: URL blocked')
        expect(result.message).to match('firewalls or proxy servers')
      end
    end
  end
end
