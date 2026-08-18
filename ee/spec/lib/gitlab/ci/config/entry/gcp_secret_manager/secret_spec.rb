# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Entry::GcpSecretManager::Secret, feature_category: :secrets_management do
  let(:entry) { described_class.new(config) }

  before do
    entry.compose!
  end

  describe 'validations' do
    context 'when all config value is correct' do
      let(:config) do
        {
          name: 'name',
          version: '2'
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when name is nil' do
      let(:config) do
        {
          name: nil,
          version: '2'
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret name can\'t be blank'
      end
    end

    context 'when version is not defined' do
      let(:config) do
        {
          name: 'name',
          version: nil
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when version is an integer' do
      let(:config) do
        {
          name: 'name',
          version: 1
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when there is an unknown key present' do
      let(:config) { { foo: :bar } }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret config contains unknown keys: foo'
      end
    end

    context 'when config is not a hash' do
      let(:config) { "" }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret config should be a hash'
      end
    end
  end

  describe '#value' do
    context 'when config is valid' do
      let(:config) do
        {
          name: 'name',
          version: '2'
        }
      end

      it 'returns config' do
        expect(entry.value).to eq(config)
      end
    end

    context 'when version is not defined' do
      let(:config) do
        {
          name: 'name',
          version: nil
        }
      end

      it 'defaults to latest version' do
        expect(entry.value[:version]).to eq(described_class::DEFAULT_VERSION)
      end
    end

    context 'when version is an integer' do
      let(:config) do
        {
          name: 'name',
          version: 1
        }
      end

      it 'coerces version to string' do
        expect(entry.value[:version]).to eq('1')
      end
    end
  end
end
