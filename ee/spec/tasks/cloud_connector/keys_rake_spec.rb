# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'cloud_connector:keys', :silence_stdout, feature_category: :system_access do
  include RakeHelpers

  let(:key) { build(:cloud_connector_keys) }

  before do
    Rake.application.rake_require('ee/lib/tasks/cloud_connector/keys', [Rails.root.to_s])
  end

  shared_examples 'handles errors' do
    it { expect { task }.to raise_error(SystemExit) }
  end

  describe 'list' do
    subject(:task) { run_rake_task('cloud_connector:keys:list', args) }

    let(:args) { [] }

    before do
      allow(CloudConnector::Keys).to receive(:valid).and_return([key])
    end

    context 'without arguments' do
      it 'lists PEM private keys in truncated form' do
        expect(key).to receive(:truncated_pem).and_return('ABC...')

        expect { task }.to output(/ABC.../).to_stdout
      end
    end

    context 'with truncate: false' do
      let(:args) { ['false'] }

      it 'lists full PEM private keys' do
        expect(key).to receive(:secret_key).and_return('ABCDEF')

        expect { task }.to output(/ABCDEF/).to_stdout
      end
    end

    context 'when an error occurs' do
      before do
        allow(CloudConnector::Keys).to receive(:valid).and_raise(StandardError)
      end

      include_examples 'handles errors'
    end
  end

  describe 'create' do
    subject(:task) { run_rake_task('cloud_connector:keys:create') }

    it 'creates a new key' do
      expect(CloudConnector::Keys).to receive(:create_new_key!).and_return(key)
      expect(key).to receive(:truncated_pem).and_return('ABCDEF')

      expect { task }.to output(/Key created: ABCDEF/).to_stdout
    end

    context 'when an error occurs' do
      before do
        allow(CloudConnector::Keys).to receive(:create_new_key!).and_raise(StandardError)
      end

      include_examples 'handles errors'
    end
  end

  describe 'rotate' do
    subject(:task) { run_rake_task('cloud_connector:keys:rotate') }

    it 'rotates keys' do
      expect(CloudConnector::Keys).to receive(:rotate!)

      expect { task }.to output(/Keys swapped successfully/).to_stdout
    end

    context 'when an error occurs' do
      before do
        allow(CloudConnector::Keys).to receive(:rotate!).and_raise(StandardError)
      end

      include_examples 'handles errors'
    end
  end

  describe 'trim' do
    subject(:task) { run_rake_task('cloud_connector:keys:trim') }

    it 'trims keys' do
      expect(CloudConnector::Keys).to receive(:trim!).and_return(key)
      expect(key).to receive(:truncated_pem).and_return('ABCDEF')

      expect { task }.to output(/Key removed: ABCDEF/).to_stdout
    end

    context 'when an error occurs' do
      before do
        allow(CloudConnector::Keys).to receive(:trim!).and_raise(StandardError)
      end

      include_examples 'handles errors'
    end
  end
end
