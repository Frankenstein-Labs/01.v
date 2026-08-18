# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::DatasetProcessor, feature_category: :duo_chat do
  let(:config_class) { Gitlab::Duo::Developments::SweBenchSeeder::Config }

  describe '.fetch_dataset_from_langsmith' do
    let(:api_key) { 'test-api-key' }
    let(:dataset_name) { 'duo_workflow.swe-bench-verified-test.1' }
    let(:dataset_id) { '6cd898d8-3b3c-49d4-bfd5-944f83bea1f2' }
    let(:split_name) { 'validation_stratified_b06f4db4_p20' }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('LANGSMITH_DATASET_NAME', anything).and_return(dataset_name)
      allow(ENV).to receive(:fetch).with('LANGSMITH_DATASET_ID', anything).and_return(dataset_id)
      allow(ENV).to receive(:fetch).with('LANGSMITH_SPLIT_NAME', anything).and_return(split_name)
    end

    context 'when API key is missing' do
      before do
        allow(config_class).to receive(:langsmith_api_key!).and_return(nil)
      end

      it 'returns empty dataset with default names' do
        dataset, name, split = described_class.fetch_dataset_from_langsmith

        expect(dataset).to eq([])
        expect(name).to eq(dataset_name)
        expect(split).to eq(split_name)
      end
    end

    context 'when API request is successful' do
      let(:response_data) do
        [
          { 'inputs' => { 'repo' => 'pallets/flask', 'issue' => 'Issue 1' }, 'outputs' => { 'solution' => 'Fix 1' } },
          { 'inputs' => { 'repo' => 'django/django', 'issue' => 'Issue 2' }, 'outputs' => { 'solution' => 'Fix 2' } }
        ]
      end

      before do
        # rubocop:disable RSpec/VerifiedDoubles -- Response object doesn't have success? method
        response = double(success?: true, body: response_data.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive_messages(langsmith_api_key!: api_key, langsmith_request: response)
      end

      it 'returns dataset with examples' do
        dataset, name, split = described_class.fetch_dataset_from_langsmith

        expect(dataset.length).to eq(2)
        expect(name).to eq(dataset_name)
        expect(split).to eq(split_name)
      end
    end

    context 'when response has examples key' do
      let(:response_data) do
        {
          'examples' => [
            { 'inputs' => { 'repo' => 'pallets/flask' }, 'outputs' => {} }
          ]
        }
      end

      before do
        # rubocop:disable RSpec/VerifiedDoubles -- Response object doesn't have success? method
        response = double(success?: true, body: response_data.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive_messages(langsmith_api_key!: api_key, langsmith_request: response)
      end

      it 'extracts examples from the examples key' do
        dataset, _name, _split = described_class.fetch_dataset_from_langsmith

        expect(dataset.length).to eq(1)
        expect(dataset.first['inputs']['repo']).to eq('pallets/flask')
      end
    end

    context 'when response has data key' do
      let(:response_data) do
        {
          'data' => [
            { 'inputs' => { 'repo' => 'django/django' }, 'outputs' => {} }
          ]
        }
      end

      before do
        # rubocop:disable RSpec/VerifiedDoubles -- Response object doesn't have success? method
        response = double(success?: true, body: response_data.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive_messages(langsmith_api_key!: api_key, langsmith_request: response)
      end

      it 'extracts examples from the data key' do
        dataset, _name, _split = described_class.fetch_dataset_from_langsmith

        expect(dataset.length).to eq(1)
        expect(dataset.first['inputs']['repo']).to eq('django/django')
      end
    end

    context 'when response is a single object (not an array)' do
      let(:response_data) do
        { 'inputs' => { 'repo' => 'single/repo' }, 'outputs' => {} }
      end

      before do
        # rubocop:disable RSpec/VerifiedDoubles -- Response object doesn't have success? method
        response = double(success?: true, body: response_data.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive_messages(langsmith_api_key!: api_key, langsmith_request: response)
      end

      it 'wraps single object in an array' do
        dataset, _name, _split = described_class.fetch_dataset_from_langsmith

        expect(dataset.length).to eq(1)
        expect(dataset.first['inputs']['repo']).to eq('single/repo')
      end
    end

    context 'when API request fails' do
      before do
        # rubocop:disable RSpec/VerifiedDoubles -- Response object doesn't have success? method
        response = double(success?: false, code: '400', message: 'Bad Request',
          body: 'Error')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive_messages(langsmith_api_key!: api_key, langsmith_request: response)
      end

      it 'returns empty dataset and prints error' do
        expect { described_class.fetch_dataset_from_langsmith }.to output(/Failed to fetch dataset/).to_stdout

        dataset, name, _ = described_class.fetch_dataset_from_langsmith

        expect(dataset).to eq([])
        expect(name).to eq(dataset_name)
      end
    end

    context 'when an error occurs' do
      before do
        allow(config_class).to receive(:langsmith_api_key!).and_raise(StandardError, 'Connection error')
      end

      it 'handles error gracefully' do
        expect { described_class.fetch_dataset_from_langsmith }.to output(/Error fetching dataset/).to_stdout
      end
    end
  end

  describe '.filter_by_project' do
    let(:dataset) do
      [
        { 'inputs' => { 'repo' => 'pallets/flask', 'instance_id' => 'pallets__flask-1234' } },
        { 'inputs' => { 'repo' => 'django/django', 'instance_id' => 'django__django-5678' } },
        { 'inputs' => { 'repo' => 'tornadoweb/tornado', 'instance_id' => 'tornadoweb__tornado-9999' } }
      ]
    end

    context 'when no filter is provided' do
      it 'returns all examples' do
        result = described_class.filter_by_project(dataset, nil)

        expect(result).to eq(dataset)
      end
    end

    context 'when filter is provided' do
      it 'filters by exact instance_id' do
        result = described_class.filter_by_project(dataset, ['django__django-5678'])

        expect(result.length).to eq(1)
        expect(result.first['inputs']['instance_id']).to eq('django__django-5678')
      end

      it 'filters by instance_id prefix' do
        result = described_class.filter_by_project(dataset, ['pallets__flask'])

        expect(result.length).to eq(1)
        expect(result.first['inputs']['instance_id']).to eq('pallets__flask-1234')
      end

      it 'filters by substring match' do
        result = described_class.filter_by_project(dataset, ['flask'])

        expect(result.length).to eq(1)
        expect(result.first['inputs']['instance_id']).to eq('pallets__flask-1234')
      end

      it 'filters by multiple projects' do
        result = described_class.filter_by_project(dataset, %w[flask django])

        expect(result.length).to eq(2)
        instance_ids = result.map { |e| e['inputs']['instance_id'] }
        expect(instance_ids).to include('pallets__flask-1234', 'django__django-5678')
        expect(instance_ids).not_to include('tornadoweb__tornado-9999')
      end
    end

    context 'when example has nil inputs' do
      let(:dataset_with_nil_inputs) do
        [
          { 'inputs' => nil },
          { 'inputs' => { 'repo' => 'django/django', 'instance_id' => 'django__django-5678' } }
        ]
      end

      it 'handles nil inputs gracefully' do
        result = described_class.filter_by_project(dataset_with_nil_inputs, ['django'])

        expect(result.length).to eq(1)
        expect(result.first['inputs']['instance_id']).to eq('django__django-5678')
      end
    end

    context 'when example has missing instance_id' do
      let(:dataset_with_missing_id) do
        [
          { 'inputs' => { 'repo' => 'pallets/flask' } },
          { 'inputs' => { 'repo' => 'django/django', 'instance_id' => 'django__django-5678' } }
        ]
      end

      it 'excludes examples without instance_id' do
        result = described_class.filter_by_project(dataset_with_missing_id, ['django'])

        expect(result.length).to eq(1)
        expect(result.first['inputs']['instance_id']).to eq('django__django-5678')
      end
    end
  end
end
