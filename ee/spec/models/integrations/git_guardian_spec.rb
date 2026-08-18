# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::GitGuardian, feature_category: :source_code_management do
  include FakeBlobHelpers

  let_it_be(:project) { create(:project, :small_repo) }
  let(:token) { 'test-token' }

  let(:file_paths) { %w[README.md test_path/file.md test.yml] }
  let(:blobs) { file_paths.map { |path| fake_blob(path: path) } }
  let(:repository_url) { Gitlab::UrlBuilder.build(project, port: nil, protocol: false).delete_prefix('//') }

  subject(:integration) { create(:git_guardian_integration, project: project, token: token) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:token) }

    context 'when inactive' do
      before do
        integration.active = false
      end

      it { is_expected.not_to validate_presence_of(:token) }
    end

    describe 'api_url' do
      using RSpec::Parameterized::TableSyntax

      where(:api_url_value, :expected_valid) do
        ''                                     | true
        nil                                    | true
        'https://api.eu1.gitguardian.com'      | true
        'https://gitguardian.example.com'      | true
        'http://api.gitguardian.com'           | false
        'not-a-url'                            | false
      end

      with_them do
        it 'validates the api_url correctly' do
          integration.assign_attributes(api_url: api_url_value, token: token)

          if expected_valid
            expect(integration).to be_valid
          else
            expect(integration).not_to be_valid
          end
        end
      end
    end
  end

  describe '#avatar_url' do
    it 'returns the GitGuardian logo path' do
      expect(integration.avatar_url).to match(
        %r{/illustrations/third-party-logos/integrations-logos/gitguardian.*\.svg\z}
      )
    end
  end

  describe '#execute' do
    it 'sends a GitGuardian request through our client class' do
      expect_next_instance_of(
        ::Gitlab::GitGuardian::Client, token, api_url: nil
      ) do |client|
        expect(client).to receive(:execute).with(blobs, repository_url).and_return([])
      end

      integration.execute(blobs, repository_url)
    end
  end
end
