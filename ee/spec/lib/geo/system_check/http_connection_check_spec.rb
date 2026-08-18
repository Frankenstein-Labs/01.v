# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::HttpConnectionCheck, feature_category: :geo_replication do
  include EE::GeoHelpers

  # freeze: true prevents accidental mutation of shared test data
  let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:http_method) { :get }

  subject(:http_connection_check) { described_class.new }

  describe 'skip?' do
    it 'skips when Geo is disabled' do
      allow(Gitlab::Geo).to receive(:enabled?).and_return(false)

      expect(http_connection_check.skip?).to be_truthy
      expect(http_connection_check.skip_reason).to eq('Geo is not enabled')
    end

    it 'skips when Geo is enabled but its a primary node' do
      allow(Gitlab::Geo).to receive_messages(enabled?: true, secondary_or_org_migration_target?: false)

      expect(http_connection_check.skip?).to be_truthy
      expect(http_connection_check.skip_reason).to eq('not a secondary node')
    end

    it 'does not skip when Geo is enabled and its a secondary or org_migration_target node' do
      allow(Gitlab::Geo).to receive_messages(enabled?: true, secondary_or_org_migration_target?: true)

      expect(http_connection_check.skip?).to be_falsey
    end
  end

  describe 'multi_check' do
    before do
      stub_current_geo_node(primary_node)
    end

    context 'with connection success' do
      it 'puts yes if check works' do
        stub_request(http_method, primary_node.internal_uri).to_return(status: 200, body: "", headers: {})

        expect do
          http_connection_check.multi_check
        end.to output("\n* Can connect to the primary node ... yes\n").to_stdout
      end
    end

    context 'with redirects' do
      def stub_many_requests(num_redirects)
        url = primary_node.internal_uri
        location = "https://example.com"

        num_redirects.times do |index|
          next_url = "#{location}/#{index}"
          stub_request(http_method, url).to_return(status: 301, headers: { 'Location' => next_url })
          url = next_url
        end

        stub_request(http_method, url).to_return(status: 200, body: "", headers: {})
      end

      context 'when connection succeeds after 9 redirects' do
        it 'puts yes' do
          stub_many_requests(9)

          expect do
            http_connection_check.multi_check
          end.to output("\n* Can connect to the primary node ... yes\n").to_stdout
        end
      end

      context 'when connection would succeed after 10 redirects' do
        it 'puts no' do
          stub_many_requests(10)

          expect do
            http_connection_check.multi_check
          end
            .to output("\n* Can connect to the primary node ... no\n  Reason:\n  Gitlab::HTTP_V2::RedirectionTooDeep\n")
              .to_stdout
        end
      end
    end

    context 'when connection errored' do
      it 'puts no if check errored' do
        stub_request(http_method, primary_node.internal_uri).to_return(status: 400, body: "", headers: {})

        expect do
          http_connection_check.multi_check
        end.to output("\n* Can connect to the primary node ... no\n").to_stdout
      end
    end

    context 'when connection exceptions' do
      it 'calls try_fixing_it for econnrefused' do
        stub_request(http_method, primary_node.internal_uri).to_raise(Errno::ECONNREFUSED)

        expect do
          http_connection_check.multi_check
        end.to output(econnrefused_help_messages).to_stdout
      end

      it 'calls try_fixing_it for econnrefused' do
        stub_request(http_method, primary_node.internal_uri).to_raise(SocketError.new)

        expect do
          http_connection_check.multi_check
        end.to output(socketerror_help_messages).to_stdout
      end

      it 'calls try_fixing_it for openssl errors' do
        stub_request(http_method, primary_node.internal_uri).to_raise(OpenSSL::SSL::SSLError.new)

        expect do
          http_connection_check.multi_check
        end.to output(openssl_error_help_messages).to_stdout
      end
    end
  end

  private

  def econnrefused_help_messages
    /Can connect to the primary node ... no.*Connection refused/m
  end

  def socketerror_help_messages
    /Can connect to the primary node ... no.*SocketError/m
  end

  def openssl_error_help_messages
    /Can connect to the primary node ... no.*OpenSSL::SSL::SSLError/m
  end
end
