# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::HostProbe, feature_category: :duo_setting do
  describe '#execute' do
    subject(:probe) { described_class.new(uri) }

    let(:uri) { 'https://example.com' }

    context 'when the URI is nil' do
      let(:uri) { nil }

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match("Cannot validate connection to host because the URL is empty.")
      end
    end

    context 'when the URI is not valid' do
      let(:uri) { 'not_a_valid_url' }

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match("not_a_valid_url is not a valid URL.")
      end
    end

    context 'when the URI is reachable' do
      before do
        WebMock.stub_request(:head, uri).to_return(status: 200)
      end

      it 'returns a success result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be true
        expect(result.message).to match("example.com reachable")
      end
    end

    context 'when the request times out' do
      before do
        WebMock.stub_request(:head, uri).to_timeout
      end

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match("example.com connection failed: execution expired")
      end
    end

    context 'when connection cannot be established because an error is raised' do
      before do
        WebMock.stub_request(:head, uri).to_raise(Gitlab::HTTP_V2::BlockedUrlError.new("URL blocked"))
      end

      it 'returns a failure result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be false
        expect(result.message).to match("example.com connection failed: URL blocked")
      end
    end
  end
end
