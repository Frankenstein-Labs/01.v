# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::LangsmithClient, feature_category: :duo_chat do
  let(:api_key) { 'test-api-key' }
  let(:dataset_name) { 'test-dataset' }
  let(:dataset_id) { 'dataset-123' }
  let(:langsmith_endpoint) { 'https://api.smith.langchain.com' }
  let(:config_class) { Gitlab::Duo::Developments::SweBenchSeeder::Config }

  before do
    allow(config_class).to receive(:langsmith_endpoint).and_return(langsmith_endpoint)
  end

  describe '.save_issue_urls_to_langsmith' do
    let(:issue_data) do
      [
        {
          inputs: { issue_url: 'https://github.com/example/repo/issues/1' },
          outputs: { issue_id: '1' }
        },
        {
          inputs: { issue_url: 'https://github.com/example/repo/issues/2' },
          outputs: { issue_id: '2' }
        }
      ]
    end

    subject(:save_issue_urls) do
      described_class.save_issue_urls_to_langsmith(issue_data, dataset_name)
    end

    context 'when API key is missing' do
      it 'returns early without making requests' do
        allow(config_class).to receive(:langsmith_api_key!).and_return(nil)

        expect(config_class).not_to receive(:langsmith_request)

        save_issue_urls
      end
    end

    context 'when API key is present' do
      before do
        allow(config_class).to receive(:langsmith_api_key!).and_return(api_key)
      end

      it 'calls delete_and_create_dataset' do
        expect(described_class).to receive(:delete_and_create_dataset).with(api_key, dataset_name)
          .and_return(dataset_id)
        expect(described_class).to receive(:add_examples_to_dataset).with(api_key, dataset_id, issue_data)

        save_issue_urls
      end

      it 'calls add_examples_to_dataset with the correct parameters' do
        allow(described_class).to receive(:delete_and_create_dataset).and_return(dataset_id)
        expect(described_class).to receive(:add_examples_to_dataset).with(api_key, dataset_id, issue_data)

        save_issue_urls
      end

      it 'prints success message' do
        allow(described_class).to receive(:delete_and_create_dataset).and_return(dataset_id)
        allow(described_class).to receive(:add_examples_to_dataset)

        expect { save_issue_urls }.to output(/Successfully saved #{issue_data.size} issue URLs/).to_stdout
      end

      context 'when delete_and_create_dataset returns nil' do
        it 'returns early without adding examples' do
          allow(described_class).to receive(:delete_and_create_dataset).and_return(nil)
          expect(described_class).not_to receive(:add_examples_to_dataset)

          save_issue_urls
        end
      end
    end

    context 'when an error occurs' do
      before do
        allow(config_class).to receive(:langsmith_api_key!).and_return(api_key)
      end

      it 'catches and logs the error' do
        allow(described_class).to receive(:delete_and_create_dataset).and_raise(StandardError, 'Test error')

        expect { save_issue_urls }.to output(/Error saving issue URLs to LangSmith: Test error/).to_stdout
      end

      it 'prints the backtrace' do
        error = StandardError.new('Test error')
        allow(described_class).to receive(:delete_and_create_dataset).and_raise(error)

        expect { save_issue_urls }.to output(/Error saving issue URLs to LangSmith/).to_stdout
      end
    end
  end

  describe '.delete_and_create_dataset' do
    subject(:delete_and_create) do
      described_class.delete_and_create_dataset(api_key, dataset_name)
    end

    context 'when dataset does not exist' do
      it 'creates a new dataset' do
        allow(described_class).to receive(:find_dataset).and_return(nil)

        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created',
          body: { id: dataset_id }.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = delete_and_create

        expect(result).to eq(dataset_id)
      end

      it 'makes a POST request to create the dataset' do
        allow(described_class).to receive(:find_dataset).and_return(nil)

        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created',
          body: { id: dataset_id }.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        expect(config_class).to receive(:langsmith_request).with(
          method: :post,
          path: '/api/v1/datasets',
          body: {
            name: dataset_name,
            description: "Issue URLs created by SWE Bench seeder"
          },
          api_key: api_key
        ).and_return(response)

        delete_and_create
      end

      it 'prints a message about creating the dataset' do
        allow(described_class).to receive(:find_dataset).and_return(nil)

        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created',
          body: { id: dataset_id }.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { delete_and_create }.to output(/Created new dataset/).to_stdout
      end
    end

    context 'when dataset already exists' do
      it 'prints a warning and raises an error' do
        allow(described_class).to receive(:find_dataset).and_return(dataset_id)

        expect { delete_and_create }.to output(/WARNING: Found existing dataset/).to_stdout
          .and raise_error(RuntimeError, /already exists/)
      end
    end

    context 'when dataset creation fails' do
      it 'returns nil when the response is not successful' do
        allow(described_class).to receive(:find_dataset).and_return(nil)

        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: false, code: '400', message: 'Bad Request',
          body: 'Invalid request')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = delete_and_create

        expect(result).to be_nil
      end

      it 'prints an error message when creation fails' do
        allow(described_class).to receive(:find_dataset).and_return(nil)

        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: false, code: '400', message: 'Bad Request',
          body: 'Invalid request')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { delete_and_create }.to output(/Failed to create dataset/).to_stdout
      end
    end

    context 'when an error occurs during dataset creation' do
      it 'lets the error propagate' do
        allow(described_class).to receive(:find_dataset).and_raise(StandardError, 'Test error')

        expect { delete_and_create }.to raise_error(StandardError, 'Test error')
      end
    end

    context 'when response body contains dataset_id instead of id' do
      it 'extracts dataset_id from response' do
        allow(described_class).to receive(:find_dataset).and_return(nil)

        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created',
          body: { dataset_id: dataset_id }.to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = delete_and_create

        expect(result).to eq(dataset_id)
      end
    end
  end

  describe '.find_dataset' do
    subject(:find_dataset) do
      described_class.find_dataset(api_key, dataset_name)
    end

    context 'when dataset exists' do
      it 'returns the dataset ID' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true,
          body: [{ id: dataset_id, name: dataset_name }].to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = find_dataset

        expect(result).to eq(dataset_id)
      end

      it 'makes a GET request to find the dataset' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true,
          body: [{ id: dataset_id, name: dataset_name }].to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        expect(config_class).to receive(:langsmith_request).with(
          method: :get,
          path: '/api/v1/datasets',
          query: { name: dataset_name },
          api_key: api_key
        ).and_return(response)

        find_dataset
      end

      it 'handles dataset_name field in response' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true,
          body: [{ id: dataset_id, dataset_name: dataset_name }].to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = find_dataset

        expect(result).to eq(dataset_id)
      end

      it 'handles dataset_id field in response' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true,
          body: [{ dataset_id: dataset_id, name: dataset_name }].to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = find_dataset

        expect(result).to eq(dataset_id)
      end
    end

    context 'when dataset does not exist' do
      it 'returns nil when no datasets are found' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, body: '[]')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = find_dataset

        expect(result).to be_nil
      end

      it 'returns nil when response is not an array' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, body: '{}')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = find_dataset

        expect(result).to be_nil
      end

      it 'returns nil when no matching dataset is found' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true,
          body: [{ id: 'other-id', name: 'other-dataset' }].to_json)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = find_dataset

        expect(result).to be_nil
      end
    end

    context 'when the API request fails' do
      it 'returns nil when response is not successful' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: false)
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        result = find_dataset

        expect(result).to be_nil
      end
    end

    context 'when an error occurs' do
      it 'returns nil and handles the error gracefully' do
        allow(config_class).to receive(:langsmith_request).and_raise(StandardError, 'Test error')

        result = find_dataset

        expect(result).to be_nil
      end
    end
  end

  describe '.delete_dataset' do
    subject(:delete_dataset) do
      described_class.delete_dataset(api_key, dataset_id)
    end

    context 'when deletion is successful' do
      it 'makes a DELETE request' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '204', message: 'No Content')
        # rubocop:enable RSpec/VerifiedDoubles
        expect(config_class).to receive(:langsmith_request).with(
          method: :delete,
          path: "/api/v1/datasets/#{dataset_id}",
          api_key: api_key
        ).and_return(response)

        delete_dataset
      end

      it 'prints a success message' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '204', message: 'No Content')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { delete_dataset }.to output(/Deleted existing dataset/).to_stdout
      end
    end

    context 'when deletion fails' do
      it 'prints a warning message when the response is not successful' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: false, code: '404', message: 'Not Found')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { delete_dataset }.to output(/Warning: Failed to delete existing dataset/).to_stdout
      end
    end

    context 'when an error occurs' do
      it 'prints a warning message and handles the error gracefully' do
        allow(config_class).to receive(:langsmith_request).and_raise(StandardError, 'Test error')

        expect { delete_dataset }.to output(/Warning: Error deleting dataset/).to_stdout
      end
    end
  end

  describe '.add_examples_to_dataset' do
    let(:issue_data) do
      [
        {
          inputs: { issue_url: 'https://github.com/example/repo/issues/1' },
          outputs: { issue_id: '1' }
        },
        {
          inputs: { issue_url: 'https://github.com/example/repo/issues/2' },
          outputs: { issue_id: '2' }
        }
      ]
    end

    subject(:add_examples) do
      described_class.add_examples_to_dataset(api_key, dataset_id, issue_data)
    end

    context 'when all examples are added successfully' do
      it 'makes POST requests for each example' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created')
        # rubocop:enable RSpec/VerifiedDoubles
        expect(config_class).to receive(:langsmith_request).twice.and_return(response)

        add_examples
      end

      it 'prints progress messages' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { add_examples }.to output(%r{Adding examples: 2/2}).to_stdout
      end

      it 'prints success count' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { add_examples }.to output(/Added 2 examples successfully/).to_stdout
      end
    end

    context 'when some examples fail to be added' do
      it 'tracks success and failure counts' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        success_response = double(success?: true, code: '201', message: 'Created')
        failure_response = double(success?: false, code: '400', message: 'Bad Request',
          body: 'Invalid data')
        # rubocop:enable RSpec/VerifiedDoubles

        allow(config_class).to receive(:langsmith_request).and_return(success_response, failure_response)

        expect { add_examples }.to output(/Added 1 examples successfully, 1 failed/).to_stdout
      end

      it 'prints failure messages' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        success_response = double(success?: true, code: '201', message: 'Created')
        failure_response = double(success?: false, code: '400', message: 'Bad Request',
          body: 'Invalid data')
        # rubocop:enable RSpec/VerifiedDoubles

        allow(config_class).to receive(:langsmith_request).and_return(success_response, failure_response)

        expect { add_examples }.to output(/Failed to add example/).to_stdout
      end

      it 'prints summary with failure count' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        success_response = double(success?: true, code: '201', message: 'Created')
        failure_response = double(success?: false, code: '400', message: 'Bad Request',
          body: 'Invalid data')
        # rubocop:enable RSpec/VerifiedDoubles

        allow(config_class).to receive(:langsmith_request).and_return(success_response, failure_response)

        expect { add_examples }.to output(/1 failed/).to_stdout
      end
    end

    context 'when adding examples with large dataset' do
      let(:large_issue_data) do
        (1..25).map do |i|
          {
            inputs: { issue_url: "https://github.com/example/repo/issues/#{i}" },
            outputs: { issue_id: i.to_s }
          }
        end
      end

      it 'logs progress every 10 examples' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { described_class.add_examples_to_dataset(api_key, dataset_id, large_issue_data) }
          .to output(%r{Adding examples: 10/25}).to_stdout
      end

      it 'logs progress on the last example' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(config_class).to receive(:langsmith_request).and_return(response)

        expect { described_class.add_examples_to_dataset(api_key, dataset_id, large_issue_data) }
          .to output(%r{Adding examples: 25/25}).to_stdout
      end
    end

    context 'when an error occurs during example addition' do
      it 'raises the error' do
        allow(config_class).to receive(:langsmith_request).and_raise(StandardError, 'Test error')

        expect { add_examples }.to raise_error(StandardError, 'Test error')
      end
    end

    context 'when making requests with correct parameters' do
      it 'sends the correct request body for each example' do
        # rubocop:disable RSpec/VerifiedDoubles -- Net::HTTPResponse is not easily verifiable
        response = double(success?: true, code: '201', message: 'Created')
        # rubocop:enable RSpec/VerifiedDoubles

        expect(config_class).to receive(:langsmith_request).with(
          method: :post,
          path: '/api/v1/examples',
          body: {
            dataset_id: dataset_id,
            inputs: issue_data[0][:inputs],
            outputs: issue_data[0][:outputs]
          },
          api_key: api_key
        ).and_return(response)

        expect(config_class).to receive(:langsmith_request).with(
          method: :post,
          path: '/api/v1/examples',
          body: {
            dataset_id: dataset_id,
            inputs: issue_data[1][:inputs],
            outputs: issue_data[1][:outputs]
          },
          api_key: api_key
        ).and_return(response)

        add_examples
      end
    end
  end
end
