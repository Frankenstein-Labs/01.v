# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::SecretDetection::PartnerTokens, feature_category: :secret_detection do
  let(:histogram) { instance_double(Prometheus::Client::Histogram) }
  let(:counter) { instance_double(Prometheus::Client::Counter) }

  before do
    allow(Gitlab::Metrics).to receive_messages(histogram: histogram, counter: counter)
  end

  describe '.observe_api_duration' do
    it 'records API duration with correct labels' do
      expect(histogram).to receive(:observe).with(
        { partner: 'aws' },
        1.5
      )

      described_class.observe_api_duration(1.5, partner: 'aws')
    end
  end

  describe '.increment_api_requests' do
    it 'increments counter for successful requests' do
      expect(counter).to receive(:increment).with(
        { partner: 'gcp', status: 'success', error_type: 'none' }
      )

      described_class.increment_api_requests(partner: 'gcp', status: 'success', error_type: 'none')
    end

    it 'increments counter for failed requests' do
      expect(counter).to receive(:increment).with(
        { partner: 'gcp', status: 'failure', error_type: 'network_error' }
      )

      described_class.increment_api_requests(partner: 'gcp', status: 'failure', error_type: 'network_error')
    end
  end

  describe '.increment_network_errors' do
    it 'increments network errors counter with correct labels' do
      expect(counter).to receive(:increment).with(
        { partner: 'aws', error_class: 'Timeout' }
      )

      described_class.increment_network_errors(partner: 'aws', error_class: 'Timeout')
    end
  end

  describe '.increment_rate_limit_hits' do
    it 'increments rate limit counter with correct labels' do
      expect(counter).to receive(:increment).with(
        { limit_type: 'partner_aws_api' }
      )

      described_class.increment_rate_limit_hits(limit_type: 'partner_aws_api')
    end
  end
end
