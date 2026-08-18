# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::GitGuardian::Client, feature_category: :source_code_management do
  include FakeBlobHelpers

  let_it_be(:project) { build(:project) }
  let_it_be(:guardian_url) { 'https://api.gitguardian.com/v1/multiscan' }
  let_it_be(:token) { 'test-token' }

  let(:file_paths) { [] }
  let(:request_body) { [] }
  let(:project_repository_url) { 'gitlab.example.com/my-project' }

  let(:stubbed_response) do
    # see doc https://api.gitguardian.com/docs#operation/multiple_scan to know more about the response structure
    file_paths.map do |_|
      {
        policy_break_count: 0,
        policies: [
          "Filename",
          "File extensions",
          "Secrets detection"
        ],
        policy_breaks: []
      }
    end.to_json
  end

  let(:blobs) { file_paths.map { |path| fake_blob(path: path) } }

  let(:status) { 200 }

  let(:stub_guardian_request) do
    stub_request(:post, guardian_url).with(
      body: request_body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        Authorization: "Token #{token}",
        'GGshield-Repository-URL' => project_repository_url
      }
    ).to_return(
      status: status,
      body: stubbed_response
    )
  end

  subject(:client) { described_class.new(token) }

  describe 'api_url handling' do
    using RSpec::Parameterized::TableSyntax

    let(:file_paths) { %w[README.md] }
    let(:request_body) { [{ document: 'foo', filename: 'README.md' }] }

    let(:stubbed_response) do
      [{ policy_break_count: 0, policies: [], policy_breaks: [] }].to_json
    end

    def stub_multiscan_request(url)
      stub_request(:post, url).with(
        body: request_body.to_json,
        headers: {
          'Content-Type' => 'application/json',
          Authorization: "Token #{token}",
          'GGshield-Repository-URL' => project_repository_url
        }
      ).to_return(status: 200, body: stubbed_response)
    end

    where(:api_url, :expected_url) do
      'https://api.eu1.gitguardian.com'  | 'https://api.eu1.gitguardian.com/v1/multiscan'
      'https://api.eu1.gitguardian.com/' | 'https://api.eu1.gitguardian.com/v1/multiscan'
      nil                                | 'https://api.gitguardian.com/v1/multiscan'
      ''                                 | 'https://api.gitguardian.com/v1/multiscan'
    end

    with_them do
      subject(:client) { described_class.new(token, api_url: api_url) }

      let!(:api_request) { stub_multiscan_request(expected_url) }

      it 'sends requests to the correct URL' do
        client.execute(blobs, project_repository_url)

        expect(api_request).to have_been_requested
      end
    end
  end

  context 'without credentials' do
    let(:token) { '' }
    let!(:guardian_api_request) { stub_guardian_request }

    it 'raises a config error' do
      expect { client }.to raise_error(::Gitlab::GitGuardian::Client::ConfigError)
      expect(guardian_api_request).not_to have_been_requested
    end
  end

  context 'with credential' do
    let!(:guardian_api_request) { stub_guardian_request }
    let(:client_response) { client.execute(blobs, project_repository_url) }

    context 'with no blobs' do
      let(:blobs) { [] }

      it 'returns an empty array' do
        expect(client_response).to eq []
        expect(guardian_api_request).not_to have_been_requested
      end
    end

    context 'when a blob has no path' do
      let(:blobs) { [fake_blob(path: nil)] }
      let(:request_body) { [{ document: 'foo' }] }

      it 'returns an empty array' do
        expect(client_response).to eq []
        expect(guardian_api_request).to have_been_requested
      end
    end

    context 'with blobs without policy breaks' do
      let(:file_paths) { %w[README.md test_path/file.md test.yml] }

      let(:request_body) do
        [
          { document: 'foo', filename: 'README.md' },
          { document: 'foo', filename: 'file.md' },
          { document: 'foo', filename: 'test.yml' }
        ]
      end

      it 'returns an empty array' do
        expect(client_response).to eq []
        expect(guardian_api_request).to have_been_requested
      end
    end

    context 'with errors' do
      let(:file_paths) { %w[test_path/file.md lib/.env] }

      let(:request_body) do
        [
          { document: 'foo', filename: 'file.md' },
          { document: 'foo', filename: '.env' }
        ]
      end

      context 'when an API respond with an error' do
        # see doc https://api.gitguardian.com/docs#operation/multiple_scan to know more about possible error responses
        let(:status) { 403 }

        let(:stubbed_response) { nil }

        it 'raises a request error' do
          expect { client_response }.to raise_error(::Gitlab::GitGuardian::Client::RequestError)
          expect(guardian_api_request).to have_been_requested
        end
      end

      context 'when API response is malformed' do
        context 'with invalid JSON syntax' do
          let(:stubbed_response) { '{fsde' }

          it 'raises Error with invalid response format message', :aggregate_failures do
            expect { client_response }.to raise_error(
              ::Gitlab::GitGuardian::Client::Error,
              'invalid response format'
            )
            expect(guardian_api_request).to have_been_requested
          end
        end

        context 'with valid JSON but response is a Hash instead of Array' do
          let(:stubbed_response) { '{"error": "unexpected structure"}' }

          it 'raises Error with invalid response format message', :aggregate_failures do
            expect { client_response }.to raise_error(
              ::Gitlab::GitGuardian::Client::Error,
              'invalid response format'
            )
            expect(guardian_api_request).to have_been_requested
          end
        end
      end
    end

    context 'with policy breaking blobs' do
      let(:file_paths) { %w[file.md .env] }

      let(:blobs) do
        document_with_policy_breaks = <<~DOCUMENT
          import urllib.request
          url = 'http://simple_username:simple_password@hi@gitlab.com/hello.json'
          response = urllib.request.urlopen(url)
          consume(response.read())
        DOCUMENT

        blob_with_policy_breaks = fake_blob(
          path: ".env",
          data: document_with_policy_breaks
        )

        [
          fake_blob(path: "file.md"),
          blob_with_policy_breaks
        ]
      end

      let(:request_body) do
        blobs.map do |blob|
          { document: blob.data, filename: blob.name }
        end
      end

      let(:stubbed_response) do
        # see doc https://api.gitguardian.com/docs#operation/multiple_scan to know more about the response structure
        [
          {
            policy_break_count: 0,
            policies: [
              "Filename",
              "File extensions",
              "Secrets detection"
            ],
            policy_breaks: []
          },
          {
            policy_break_count: 2,
            policies: [
              "Filename",
              "File extensions",
              "Secrets detection"
            ],
            policy_breaks: [
              {
                type: ".env",
                policy: "Filenames",
                matches: [
                  {
                    type: "filename",
                    match: ".env"
                  }
                ]
              },
              {
                type: "Basic Auth String",
                policy: "Secrets detection",
                validity: "cannot_check",
                known_secret: true,
                incident_url: 'https://incident.example.com',
                matches: [
                  {
                    type: "username",
                    match: "simple_username",
                    index_start: 37,
                    index_end: 45,
                    line_start: 2,
                    line_end: 2
                  },
                  {
                    type: "password",
                    match: "simple_password",
                    index_start: 46,
                    index_end: 61,
                    line_start: 2,
                    line_end: 2
                  },
                  {
                    type: "host",
                    match: "hi@gitlab.com",
                    index_start: 62,
                    index_end: 70,
                    line_start: 2,
                    line_end: 2
                  }
                ]
              }
            ]
          }
        ].to_json
      end

      it 'returns appropriate error messages' do
        expected_message = <<~POLICY_BREAKS
          .env: 2 incidents detected:

           >> Filenames: .env
              Validity: N/A
              Known by GitGuardian: No
              Incident URL: N/A
              Violation: filename `.env` detected

           >> Secrets detection: Basic Auth String
              Validity: Cannot check
              Known by GitGuardian: Yes
              Incident URL: https://incident.example.com
              Violation: username `simple_username` detected
              2 | url = 'http://simple_username:simple_password@hi@gitlab.com/hello.json'
                                |__username___|
              Violation: password `simple_password` detected
              2 | url = 'http://simple_username:simple_password@hi@gitlab.com/hello.json'
                                                |__password___|
              Violation: host `hi@gitlab.com` detected
              2 | url = 'http://simple_username:simple_password@hi@gitlab.com/hello.json'
                                                                |___host____|

        POLICY_BREAKS

        expect(client_response).to eq [expected_message]

        expect(guardian_api_request).to have_been_requested
      end
    end

    context 'with multiple blob batches' do
      let(:blobs) { Array.new(46) { |i| fake_blob(path: "fake_path#{i}.txt") } }
      let(:policies_breaks_message) do
        [
          <<~POLICY_BREAK
          .env: 2 incidents detected:

           >> Filenames: .env
              Validity: N/A
              Known by GitGuardian: No
              Incident URL: N/A
              Violation: filename `.env` detected
          POLICY_BREAK
        ]
      end

      let(:stub_guardian_request) do
        stub_request(:post, guardian_url).to_return(
          { status: status, body: stubbed_response }
        )
      end

      before do
        allow(client).to receive(:process_response).and_return([], policies_breaks_message, [])
      end

      it 'returns appropriate error messages' do
        expect(client_response).to eq policies_breaks_message
        expect(guardian_api_request).to have_been_requested.times(3)
      end
    end

    describe 'filename limit' do
      let(:response) { instance_double(Net::HTTPResponse, body: stubbed_response) }
      let(:response_double) do
        instance_double(HTTParty::Response, code: status, response: response)
      end

      context 'when file names is withing the limit' do
        let(:file_paths) { %w[test_path/file.md lib/.env] }

        let(:params) do
          [
            { document: blobs[0].data, filename: 'file.md' },
            { document: blobs[1].data, filename: '.env' }
          ]
        end

        it 'does not raise an error' do
          expect(client).to receive(:perform_request).with(params, project_repository_url).and_return(response)
          expect(client_response).to eq []
        end
      end

      context 'when file name is outside of the limit' do
        let(:filler) { 'x' * 237 }
        let(:long_filename) { "NOT_256_CHARACTERS_#{filler}.txt" }
        let(:long_path) { "test/#{long_filename}" }
        let(:file_paths) { ["test_path/file.md", long_path] }
        let(:params) do
          [
            { document: blobs[0].data, filename: 'file.md' },
            { document: blobs[1].data, filename: "256_CHARACTERS_#{filler}.txt" }
          ]
        end

        it 'does not raise an error' do
          number_of_trimmed_characters = long_filename.length - described_class::FILENAME_LIMIT
          expect(number_of_trimmed_characters).to be(4)
          expect(client).to receive(:perform_request).with(params, project_repository_url).and_return(response)
          expect(client_response).to eq []
        end
      end
    end
  end

  context 'with a blob containing binary data' do
    let(:filename) { 'rails_sample.jpg' }
    let(:blobs) do
      [
        fake_blob(
          path: filename,
          data: File.read(File.join('spec', 'fixtures', filename)),
          binary: true
        )
      ]
    end

    it 'warns and does not call GitGuardian API' do
      expect(::Gitlab::AppJsonLogger).to receive(:warn).with(class: described_class.name,
        message: "Not processing data with filename '#{filename}' as it cannot be JSONified")
      expect(::Gitlab::AppJsonLogger).to receive(:warn).with(class: described_class.name,
        message: "Nothing to process")

      expect(client.execute(blobs, project_repository_url)).to eq([])
    end
  end
end
