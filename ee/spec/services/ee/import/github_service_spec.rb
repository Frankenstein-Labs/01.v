# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::GithubService, feature_category: :importers do
  let_it_be(:user) { create(:user, :with_namespace) }

  let(:token) { 'complex-token' }
  let(:access_params) { { github_access_token: 'ghp_complex-token' } }
  let(:settings) { instance_double(Gitlab::GithubImport::Settings) }
  let(:user_namespace_path) { user.namespace_path }
  let(:optional_stages) { nil }
  let(:timeout_strategy) { "optimistic" }
  let(:pagination_limit) { nil }
  let(:params) do
    {
      repo_id: 123,
      new_name: 'new_repo',
      target_namespace: user_namespace_path,
      optional_stages: optional_stages,
      timeout_strategy: timeout_strategy,
      pagination_limit: pagination_limit
    }
  end

  let(:client) { Gitlab::GithubImport::Client.new(token) }
  let(:project_double) { instance_double(Project, persisted?: true) }

  subject(:github_importer) { described_class.new(client, user, params) }

  before do
    allow(client).to receive_message_chain(:octokit, :rate_limit, :limit)
    allow(client).to receive_message_chain(:octokit, :rate_limit, :remaining).and_return(100)
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).with(:github_import, scope: user).and_return(false)
    allow(Gitlab::GithubImport::Settings).to receive(:new).with(project_double).and_return(settings)

    # catch every call to write, regardless of arguments
    allow(settings).to receive(:write)
  end

  context 'when validating repository size' do
    let(:repository_double) { { name: 'repository', size: 99 } }

    before do
      allow(github_importer).to receive(:authorized?).and_return(true)
      allow(client).to receive_message_chain(:octokit, :repository).and_return({ status: 200 })
      allow(client).to receive_message_chain(:octokit, :collaborators).and_return({ status: 200 })
      allow(client).to receive(:repository).and_return(repository_double)

      allow_next_instance_of(Gitlab::LegacyGithubImport::ProjectCreator) do |creator|
        allow(creator).to receive(:execute).and_return(project_double)
      end
    end

    context 'when there is no repository size limit defined' do
      it 'skips the check, succeeds, and tracks an access level' do
        expect(github_importer.execute(access_params, :github)).to include(status: :success)
        expect(settings)
          .to have_received(:write)
          .with(
            hash_including(
              optional_stages: nil,
              timeout_strategy: timeout_strategy,
              pagination_limit: pagination_limit
            )
          )
        expect_snowplow_event(
          category: 'Import::GithubService',
          action: 'create',
          label: 'import_access_level',
          user: user,
          extra: { import_type: 'github', user_role: 'Owner' }
        )
      end
    end

    context 'when the target namespace repository size limit is defined' do
      let_it_be(:group) { create(:group, repository_size_limit: 100) }

      before do
        params[:target_namespace] = group.full_path
      end

      it 'succeeds if the repository is smaller than the limit' do
        expect(github_importer.execute(access_params, :github)).to include(status: :success)
        expect(settings)
          .to have_received(:write)
          .with(
            hash_including(
              optional_stages: nil,
              timeout_strategy: timeout_strategy,
              pagination_limit: pagination_limit
            )
          )
        expect_snowplow_event(
          category: 'Import::GithubService',
          action: 'create',
          label: 'import_access_level',
          user: user,
          extra: { import_type: 'github', user_role: 'Not a member' }
        )
      end

      it 'returns error if the repository is larger than the limit' do
        repository_double[:size] = 101

        expect(github_importer.execute(access_params, :github)).to include(
          size_limit_error(repository_double[:name], repository_double[:size], group.repository_size_limit)
        )
      end
    end

    context 'when target namespace repository limit is not defined' do
      let_it_be(:group) { create(:group) }
      let(:repository_size_limit) { 100 }

      before do
        stub_application_setting(repository_size_limit: 100)
      end

      context 'when application size limit is defined' do
        it 'succeeds if the repository is smaller than the limit' do
          expect(github_importer.execute(access_params, :github)).to include(status: :success)
          expect(settings)
            .to have_received(:write)
            .with(
              hash_including(
                optional_stages: nil,
                timeout_strategy: timeout_strategy,
                pagination_limit: pagination_limit
              )
            )
          expect_snowplow_event(
            category: 'Import::GithubService',
            action: 'create',
            label: 'import_access_level',
            user: user,
            extra: { import_type: 'github', user_role: 'Owner' }
          )
        end

        it 'returns error if the repository is larger than the limit' do
          repository_double[:size] = 101

          expect(github_importer.execute(access_params, :github)).to include(
            size_limit_error(repository_double[:name], repository_double[:size], repository_size_limit)
          )
        end
      end
    end

    context 'when optional stages params present' do
      let(:optional_stages) do
        {
          single_endpoint_notes_import: 'false',
          attachments_import: false
        }
      end

      it 'saves optional stages choice to import_data' do
        github_importer.execute(access_params, :github)

        expect(settings)
          .to have_received(:write)
          .with(
            hash_including(
              optional_stages: optional_stages,
              timeout_strategy: timeout_strategy,
              pagination_limit: pagination_limit
            )
          )
      end
    end

    context 'when timeout strategy param is present' do
      let(:timeout_strategy) { 'pessimistic' }

      it 'saves timeout strategy to import_data' do
        github_importer.execute(access_params, :github)

        expect(settings)
          .to have_received(:write)
          .with(
            hash_including(
              optional_stages: optional_stages,
              timeout_strategy: timeout_strategy,
              pagination_limit: pagination_limit
            )
          )
      end
    end

    context 'when pagination limit param is present' do
      let(:pagination_limit) { 50 }

      it 'saves pagination limit to import_data' do
        github_importer.execute(access_params, :github)

        expect(settings)
          .to have_received(:write)
          .with(
            hash_including(
              optional_stages: optional_stages,
              timeout_strategy: timeout_strategy,
              pagination_limit: pagination_limit
            )
          )
      end
    end

    context 'when additional access tokens are present' do
      it 'saves additional access tokens to import_data' do
        github_importer.execute(access_params, :github)

        expect(settings)
          .to have_received(:write)
          .with(
            hash_including(
              optional_stages: optional_stages,
              timeout_strategy: timeout_strategy,
              pagination_limit: pagination_limit
            )
          )
      end
    end
  end

  def size_limit_error(repository_name, repository_size, limit)
    {
      status: :error,
      http_status: :unprocessable_entity,
      message: format(
        s_('GithubImport|"%{repository_name}" size (%{repository_size}) is larger than the limit of %{limit}.'),
        repository_name: repository_name,
        repository_size: ActiveSupport::NumberHelper.number_to_human_size(repository_size),
        limit: ActiveSupport::NumberHelper.number_to_human_size(limit))
    }
  end
end
