# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Search::ElasticsearchUrl, feature_category: :global_search do
  describe '.validate' do
    using RSpec::Parameterized::TableSyntax

    before do
      allow(::Gitlab::CurrentSettings).to receive_messages(
        deny_all_requests_except_allowed?: false,
        outbound_local_requests_whitelist: []
      )
    end

    where(:url_string, :is_valid) do
      'http://es.example.com:9200'                               | true
      'https://es.example.com:9200'                              | true
      'http://localhost:9200'                                    | true
      'http://127.0.0.1:9200'                                    | true
      'http://es1.example.com:9200,https://es2.example.com:9200' | true
      'https://user:pass@es.example.com:9200'                    | true
      ''                                                         | true
      'ftp://es.example.com'                                     | false
      'es.example.com'                                           | false
      'not_a_url'                                                | false
      'http://es.example.com:9200,ftp://bad.example.com'         | false
    end

    with_them do
      it 'validates correctly' do
        urls = described_class.parse(url_string)

        if is_valid
          expect { described_class.validate!(urls) }.not_to raise_error
        else
          expect { described_class.validate!(urls) }.to raise_error(::Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
        end
      end
    end
  end

  describe '.with_credentials' do
    it 'returns connection settings hashes for each URL' do
      result = described_class.with_credentials('http://es.example.com:9200', username: 'user', password: 'pass')

      expect(result).to match_array([{ scheme: 'http', host: 'es.example.com', port: 9200, path: '',
                                       user: 'user', password: 'pass' }])
    end

    it 'handles multiple comma-separated URLs' do
      result = described_class.with_credentials(
        'http://es1.example.com:9200,https://es2.example.com:9200',
        username: 'user', password: 'pass'
      )

      expect(result.size).to eq(2)
      expect(result[0]).to include(host: 'es1.example.com', user: 'user', password: 'pass')
      expect(result[1]).to include(host: 'es2.example.com', user: 'user', password: 'pass')
    end

    it 'prefers explicit credentials over URL-embedded ones' do
      result = described_class.with_credentials(
        'https://urluser:urlpass@es.example.com:9200',
        username: 'explicit', password: 'override'
      )

      expect(result.first).to include(host: 'es.example.com', user: 'explicit', password: 'override')
    end

    it 'falls back to URL-embedded credentials when none provided' do
      result = described_class.with_credentials('https://urluser:urlpass@es.example.com:9200')

      expect(result.first).to include(host: 'es.example.com', user: 'urluser', password: 'urlpass')
    end

    it 'returns empty array for blank url' do
      expect(described_class.with_credentials('')).to eq([])
      expect(described_class.with_credentials(nil)).to eq([])
    end
  end

  describe '.parse' do
    it 'returns an array of URIs' do
      result = described_class.parse('http://es1:9200,https://es2:9200')

      expect(result).to all(be_a(URI))
      expect(result.map(&:to_s)).to match_array(['http://es1:9200', 'https://es2:9200'])
    end

    it 'strips whitespace and removes trailing slashes' do
      result = described_class.parse('http://es1:9200// , http://es2:9200 ')

      expect(result.map(&:to_s)).to match_array(['http://es1:9200', 'http://es2:9200'])
    end

    it 'rejects blank entries' do
      expect(described_class.parse('http://es1:9200,,http://es2:9200').size).to eq(2)
    end

    it 'returns empty array for blank input' do
      expect(described_class.parse('')).to eq([])
      expect(described_class.parse(nil)).to eq([])
    end

    it 'handles URLs with credentials' do
      result = described_class.parse('https://user:pass@es.example.com:9200')

      expect(result.first.user).to eq('user')
      expect(result.first.password).to eq('pass')
    end
  end
end
