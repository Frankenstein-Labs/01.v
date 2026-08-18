# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::ProductAnalytics::ConfiguratorUrlValidation, feature_category: :product_analytics do
  using RSpec::Parameterized::TableSyntax

  let(:allow_local_requests) { false }
  let(:deny_all_requests) { false }
  let(:local_requests_allowlist) { [] }
  let(:configurator_url) { 'https://example.com' }
  let(:project) { build(:project) }

  let(:validation_response) do
    [
      Addressable::URI.parse("https://example.com"),
      "https://example.com"
    ]
  end

  subject(:validator) { Class.new.include(described_class).new }

  before do
    stub_application_setting(allow_local_requests_from_web_hooks_and_services: allow_local_requests)
    stub_application_setting(deny_all_requests_except_allowed?: deny_all_requests)
    stub_application_setting(outbound_local_requests_whitelist: local_requests_allowlist)

    allow_next_instance_of(ProductAnalytics::Settings) do |settings|
      allow(settings).to receive(:product_analytics_configurator_connection_string).and_return(configurator_url)
    end
  end

  shared_examples 'returns a success response' do
    before do
      allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!).and_return(validation_response)
    end

    it 'calls the validation service' do
      expect(Gitlab::HTTP_V2::UrlBlocker)
        .to receive(:validate!)
        .with(configurator_url, {
          allow_localhost: allow_local_requests,
          allow_local_network: allow_local_requests,
          schemes: %w[http https],
          deny_all_requests_except_allowed: deny_all_requests,
          outbound_local_requests_allowlist: local_requests_allowlist
        })

      expect(validator.validate_url!(configurator_url)).to be(validation_response)
    end
  end

  shared_examples 'returns an error response' do
    before do
      allow(Gitlab::HTTP_V2::UrlBlocker)
        .to receive(:validate!)
        .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
    end

    it 'calls the validation service' do
      expect(Gitlab::HTTP_V2::UrlBlocker)
        .to receive(:validate!)
        .with(configurator_url, {
          allow_localhost: allow_local_requests,
          allow_local_network: allow_local_requests,
          schemes: %w[http https],
          deny_all_requests_except_allowed: deny_all_requests,
          outbound_local_requests_allowlist: local_requests_allowlist
        })

      expect { validator.validate_url!(configurator_url) }.to raise_error(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
    end
  end

  describe '#validate_url!' do
    it_behaves_like 'returns a success response'

    context 'when making a local request' do
      let(:configurator_url) { 'https://localhost' }
      let(:validation_response) do
        [
          Addressable::URI.parse("https://localhost"),
          "https://localhost"
        ]
      end

      it_behaves_like 'returns an error response'

      context 'when the requested domain is on the local request allowlist' do
        let(:local_requests_allowlist) { ['localhost'] }

        it_behaves_like 'returns a success response'
      end

      context 'when local requests are allowed' do
        let(:allow_local_requests) { true }

        it_behaves_like 'returns a success response'
      end
    end

    context 'when an allow list for requests has been set up' do
      let(:deny_all_requests_except_allowed) { true }

      context 'when the requested domain is not on the allow list' do
        it_behaves_like 'returns an error response'
      end

      context 'when the request domain is on the allow list' do
        let(:local_requests_allowlist) { ['example.com'] }

        it_behaves_like 'returns a success response'
      end
    end
  end

  describe '#allow_local_requests?' do
    where(:allow_local_requests) { [false, true] }

    with_them do
      it 'returns whether the local requests are allowed' do
        expect(validator.allow_local_requests?).to eq(allow_local_requests)
      end
    end
  end

  describe '#configurator_url' do
    where(:configurator_url) { [nil, '', 'https://example.com'] }

    with_them do
      it 'returns the configurator url' do
        expect(validator.configurator_url(project)).to eq(configurator_url)
      end
    end
  end
end
