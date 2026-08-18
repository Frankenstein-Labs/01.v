# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ExternalStatusChecks::DispatchService, feature_category: :source_code_management do
  include StubRequests

  let_it_be(:rule) { build_stubbed(:external_status_check, external_url: 'https://test.example.com/callback') }

  subject { described_class.new(rule, {}).execute }

  describe '#execute' do
    context 'service responds with success' do
      before do
        stub_full_request(rule.external_url, method: :post)
      end

      it 'is successful' do
        expect(subject.success?).to be true
      end

      it 'passes back the http status code' do
        expect(subject.http_status).to eq(200)
      end

      context 'without shared secret' do
        it 'sets correct headers when there is no HMAC secret' do
          expect(subject).to have_requested(:post, stubbed_hostname(rule.external_url)).with(
            headers: { 'Content-Type' => 'application/json' }
          ).once
        end
      end

      context 'with shared secret' do
        let_it_be(:shared_secret) { 'shared_secret' }
        let_it_be(:request_body_size_limit) { 25.megabytes }
        let_it_be(:rule) { build_stubbed(:external_status_check, external_url: 'https://test.example.com/callback', shared_secret: shared_secret) }

        subject { described_class.new(rule, {}).execute }

        it 'sets correct headers when there is no HMAC secret' do
          expect(subject).to have_requested(:post, stubbed_hostname(rule.external_url)).with(
            headers: { 'Content-Type' => 'application/json',
                       'X-GitLab-Signature': '6c52a647de5847fc387ead12919dc6a5b9ed08e9538583c83da266d958e33aec' }
          ).once
        end
      end
    end

    context 'service responds with error' do
      before do
        stub_failure
      end

      it 'is unsuccessful' do
        expect(subject.success?).to be false
      end

      it 'passes back the http status code' do
        expect(subject.http_status).to eq(500)
      end
    end

    context 'service responds with BlockedUrlError' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_raise(::Gitlab::HTTP_V2::BlockedUrlError)
      end

      it 'is unsuccessful' do
        expect(subject.success?).to be false
      end

      it 'passes back the bad request http status code' do
        expect(subject.http_status).to eq(:bad_request)
      end
    end
  end

  private

  def stub_failure
    stub_request(:post, 'https://test.example.com/callback')
      .with(headers: { 'Content-Type' => 'application/json' })
      .to_return(status: 500, body: "", headers: {})
  end
end
