# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:duo_chat:seed:failed_ci_jobs', :silence_stdout, type: :task, feature_category: :duo_chat do
  let(:langchain_endpoint) { 'https://api.smith.langchain.com' }
  let(:dataset_version) { '1' }
  let(:langchain_api_key) { 'test_api_key' }
  let(:jsonl_response) do
    <<~JSONL
      {"inputs": {"job_id": 135534952, "trace": "Failed job trace"}}
      {"inputs": {"job_id": 135534953, "trace": "Another failed job trace"}}
    JSONL
  end

  let(:organization) { create(:organization) }
  let!(:user) { create(:user, organizations: [organization], username: 'root') }
  let(:group_path) { 'ai-evaluation' }
  let(:project_path) { 'rca' }
  let(:project_clone_url) { "https://gitlab.com/gitlab-org/modelops/ai-model-validation-and-research/ai-evaluation/test-repo.git" }
  let(:run) { run_rake_task('gitlab:duo_chat:seed:failed_ci_jobs') }

  before do
    Rake.application.rake_require 'tasks/gitlab/duo_chat/seed_failed_ci_jobs'
    stub_env('LANGCHAIN_ENDPOINT', langchain_endpoint)
    stub_env('RCA_DATASET_VERSION', dataset_version)
    stub_env('LANGCHAIN_API_KEY', langchain_api_key)
  end

  context 'when an unknown dataset version is provided' do
    let(:dataset_version) { '999' } # Unknown version

    it 'prints an error message about unknown version and does not proceed' do
      expect { run }.to output(/Unknown dataset version: 999. Available versions: 1/).to_stdout
    end
  end

  context 'when the API request fails' do
    let(:dataset_version) { '1' }
    let(:expected_dataset_id) { 'cdba1bb8-8234-4a70-8524-c33dee5a1570' }

    before do
      stub_request(:get, "#{langchain_endpoint}/api/v1/datasets/#{expected_dataset_id}/jsonl")
        .with(headers: { 'X-API-Key' => langchain_api_key })
        .to_return(status: 401, body: 'Unauthorized')
    end

    it 'prints an error and does not proceed' do
      expect { run }.to output(/Failed to fetch dataset: 401/).to_stdout
    end
  end

  context 'when LANGCHAIN_API_KEY is missing' do
    before do
      stub_env('LANGCHAIN_API_KEY', nil)
    end

    it 'returns an empty array and prints an error' do
      expect { run }.to output(/Missing LANGCHAIN_API_KEY environment variable!/).to_stdout
    end
  end

  context 'when the dataset response is malformed JSON' do
    let(:dataset_version) { '1' }
    let(:expected_dataset_id) { 'cdba1bb8-8234-4a70-8524-c33dee5a1570' }

    before do
      stub_request(:get, "#{langchain_endpoint}/api/v1/datasets/#{expected_dataset_id}/jsonl")
        .with(headers: { 'X-API-Key' => langchain_api_key })
        .to_return(status: 200, body: "invalid_json")
    end

    it 'prints a JSON parsing error message' do
      expect { run }.to output(/Error parsing JSONL line/).to_stdout
    end
  end

  context 'when an unexpected error occurs' do
    before do
      allow(Net::HTTP).to receive(:start).and_raise(StandardError.new("Network failure"))
    end

    it 'prints an error message and returns an empty array' do
      expect { run }.to output(/Error fetching dataset from LangSmith: Network failure/).to_stdout
    end
  end

  context 'when the dataset is empty' do
    let(:dataset_version) { '1' }
    let(:expected_dataset_id) { 'cdba1bb8-8234-4a70-8524-c33dee5a1570' }

    before do
      stub_request(:get, "#{langchain_endpoint}/api/v1/datasets/#{expected_dataset_id}/jsonl")
        .with(headers: { 'X-API-Key' => langchain_api_key })
        .to_return(status: 200, body: "")
    end

    it 'prints a message indicating no jobs to seed' do
      expect { run }.to output(/Seeding complete! Created 0 failed jobs./).to_stdout
    end
  end

  context 'when the dataset contains failed jobs' do
    let(:dataset_version) { '1' }
    let(:expected_dataset_id) { 'cdba1bb8-8234-4a70-8524-c33dee5a1570' }

    before do
      stub_request(:get, "#{langchain_endpoint}/api/v1/datasets/#{expected_dataset_id}/jsonl")
        .with(headers: { 'X-API-Key' => langchain_api_key })
        .to_return(status: 200, body: jsonl_response)
    end

    context 'when the project and group do not exist' do
      it 'creates them and seeds failed jobs correctly' do
        expect { run }.to change { Ci::Build.count }.by(2)
                                  .and change { Group.count }.by(1)
                                  .and change { Project.count }.by(1)
      end
    end

    context 'when the project and group already exist' do
      let(:group) { create(:group, path: group_path, organization: organization) }

      before do
        create(:project, path: project_path, namespace: group)
      end

      it 'seeds failed jobs without creating extra groups or projects' do
        expect { run }.to change { Ci::Build.count }.by(2)
        expect { run }.not_to change { Group.count }
        expect { run }.not_to change { Project.count }
      end
    end
  end
end
