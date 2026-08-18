# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Entry::AwsSecretsManager::Secret, feature_category: :secrets_management do
  let(:entry) { described_class.new(config) }

  describe 'validation' do
    before do
      entry.compose!
    end

    context 'when entry config value is correct' do
      let(:hash_config) do
        {
          secret_id: 'production/db/password',
          version_id: 'version_id',
          version_stage: 'AWSCURRENT',
          field: 'some_field',
          region: 'us-east-1',
          role_arn: 'arn:aws:iam::123456789012:role/role-name',
          role_session_name: 'session-name'
        }
      end

      let(:hash_config_minimal) do
        {
          secret_id: 'production/db/password'
        }
      end

      context 'when config is a hash' do
        let(:config) { hash_config }

        describe '#value' do
          it 'returns AWS SecretsManager configuration' do
            expect(entry.value).to eq(hash_config)
          end
        end

        describe '#valid?' do
          it 'is valid' do
            expect(entry).to be_valid
          end
        end
      end

      context 'when config is a string' do
        let(:config) { 'production/db/password' }

        describe '#value' do
          it 'returns AWS SecretsManager secret configuration' do
            expect(entry.value).to eq(hash_config_minimal)
          end
        end

        describe '#valid?' do
          it 'is valid' do
            expect(entry).to be_valid
          end
        end
      end

      context 'when config is a string with field' do
        let(:config) { 'production/db/password#field' }

        describe '#value' do
          it 'returns AWS SecretsManager secret configuration' do
            expect(entry.value).to eq({
              secret_id: 'production/db/password',
              field: 'field'
            })
          end
        end

        describe '#valid?' do
          it 'is valid' do
            expect(entry).to be_valid
          end
        end
      end
    end
  end

  context 'when entry value is not correct' do
    describe '#errors' do
      context 'when there is an unknown key present' do
        let(:config) { { foo: :bar } }

        it 'reports error' do
          expect(entry.errors)
            .to include 'hash strategy config contains unknown keys: foo'
        end
      end

      context 'when config is a string and contains more than one #' do
        let(:config) { 'production/db/password#field#foo' }

        it 'reports error' do
          expect(entry.errors)
            .to include "string strategy config must contain at most one '#'"
        end
      end

      context 'when name is not present' do
        let(:config) { {} }

        it 'reports error' do
          expect(entry.errors)
            .to include 'hash strategy secret can\'t be blank'
        end
      end

      context 'when secret_id is is blank' do
        let(:config) { { secret_id: '' } }

        it 'reports error' do
          expect(entry.errors)
            .to include "hash strategy secret can't be blank"
        end
      end

      context 'when fields are not string' do
        let(:config) do
          {
            secret_id: 1,
            version_id: 2.0,
            version_stage: true,
            field: false,
            region: {},
            role_arn: [],
            role_session_name: nil
          }
        end

        it 'reports error' do
          [
            "hash strategy secret should be a string", # _id ist stripped by rails
            "hash strategy region should be a string",
            "hash strategy version should be a string", # _id ist stripped by rails
            "hash strategy version stage should be a string",
            "hash strategy role arn should be a string",
            "hash strategy field should be a string"
          ].each do |error_message|
            expect(entry.errors).to include(error_message)
          end
        end
      end
    end
  end
end
