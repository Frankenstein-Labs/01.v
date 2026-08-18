# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Entry::Secret, feature_category: :secrets_management do
  let(:entry) { described_class.new(config) }

  describe 'validation' do
    before do
      entry.compose!
    end

    context 'when entry config value is correct' do
      shared_examples 'configures secrets' do
        describe '#value' do
          it 'returns secret configuration' do
            expect(entry.value).to eq(config)
          end
        end

        describe '#valid?' do
          it 'is valid' do
            expect(entry).to be_valid
          end
        end
      end

      context 'for Hashicorp Vault' do
        context 'when file setting is not defined' do
          let(:config) do
            {
              vault: {
                engine: { name: 'kv-v2', path: 'kv-v2' },
                path: 'production/db',
                field: 'password'
              }
            }
          end

          it_behaves_like 'configures secrets'
        end

        context 'when file setting is defined' do
          let(:config) do
            {
              vault: {
                engine: { name: 'kv-v2', path: 'kv-v2' },
                path: 'production/db',
                field: 'password'
              },
              file: true
            }
          end

          it_behaves_like 'configures secrets'
        end

        context 'when `token` is defined' do
          let(:config) do
            {
              vault: {
                engine: { name: 'kv-v2', path: 'kv-v2' },
                path: 'production/db',
                field: 'password'
              },
              token: '$TEST_ID_TOKEN'
            }
          end

          describe '#value' do
            it 'returns secret configuration' do
              expect(entry.value).to eq(
                {
                  vault: {
                    engine: { name: 'kv-v2', path: 'kv-v2' },
                    path: 'production/db',
                    field: 'password'
                  },
                  token: '$TEST_ID_TOKEN'
                }
              )
            end
          end

          describe '#valid?' do
            it 'is valid' do
              expect(entry).to be_valid
            end
          end
        end
      end

      context 'for AWS Secrets Manager' do
        context 'when `token` is defined' do
          let(:config) do
            {
              aws_secrets_manager: {
                secret_id: 'name'
              },
              token: '$TEST_ID_TOKEN'
            }
          end

          describe '#value' do
            it 'returns secret configuration with token' do
              expect(entry.value).to eq(
                {
                  aws_secrets_manager: {
                    secret_id: 'name',
                    version_id: nil,
                    version_stage: nil,
                    region: nil,
                    role_arn: nil,
                    field: nil,
                    role_session_name: nil
                  },
                  token: '$TEST_ID_TOKEN'
                }
              )
            end
          end

          describe '#valid?' do
            it 'is valid' do
              expect(entry).to be_valid
            end
          end
        end

        context 'with optional fields' do
          let(:config) do
            {
              aws_secrets_manager: {
                secret_id: 'db-password',
                region: 'us-east-1',
                version_id: 'abcdef1234567890',
                version_stage: 'AWSCURRENT',
                role_arn: 'arn:aws:iam::123456789012:role/role-name',
                field: 'password',
                role_session_name: 'session-name'
              }
            }
          end

          it 'is valid' do
            expect(entry).to be_valid
          end
        end

        context 'with invalid configuration' do
          context 'when secret_id is missing' do
            let(:config) do
              {
                aws_secrets_manager: {}
              }
            end

            it 'is not valid' do
              expect(entry).not_to be_valid
              expect(entry.errors).to include(/aws_secrets_manager secret can't be blank/)
            end
          end
        end

        context 'when config is not a hash' do
          let(:config) { 123 }

          it 'is not valid' do
            expect(entry).not_to be_valid
          end
        end

        context 'when `token` is not defined' do
          let(:config) do
            {
              aws_secrets_manager: {
                secret_id: 'name',
                region: 'eu-central-1'
              }
            }
          end

          describe '#value' do
            it 'returns secret configuration' do
              expect(entry.value).to eq(
                {
                  aws_secrets_manager: {
                    secret_id: 'name',
                    region: 'eu-central-1',
                    version_id: nil,
                    version_stage: nil,
                    role_arn: nil,
                    field: nil,
                    role_session_name: nil
                  }
                }
              )
            end
          end

          describe '#valid?' do
            it 'is valid' do
              expect(entry).to be_valid
            end
          end
        end
      end

      context 'for Azure Key Vault' do
        context 'when `token` is defined' do
          let(:config) do
            {
              azure_key_vault: {
                name: 'name',
                version: '1'
              },
              token: '$TEST_ID_TOKEN'
            }
          end

          describe '#value' do
            it 'returns secret configuration' do
              expect(entry.value).to eq(
                {
                  azure_key_vault: {
                    name: 'name',
                    version: '1'
                  },
                  token: '$TEST_ID_TOKEN'
                }
              )
            end
          end

          describe '#valid?' do
            it 'is valid' do
              expect(entry).to be_valid
            end
          end
        end

        context 'when `token` is not defined' do
          let(:config) do
            {
              azure_key_vault: {
                name: 'name',
                version: '1'
              }
            }
          end

          describe '#value' do
            it 'returns secret configuration' do
              expect(entry.value).to eq(
                {
                  azure_key_vault: {
                    name: 'name',
                    version: '1'
                  }
                }
              )
            end
          end

          describe '#valid?' do
            it 'is valid' do
              expect(entry).to be_valid
            end
          end
        end
      end

      context 'for GCP Secrets Manager' do
        context 'when `token` is defined' do
          let(:config) do
            {
              gcp_secret_manager: {
                name: 'name',
                version: '1'
              },
              token: '$TEST_ID_TOKEN'
            }
          end

          describe '#value' do
            it 'returns secret configuration' do
              expected_result = {
                gcp_secret_manager: {
                  name: 'name',
                  version: '1'
                },
                token: '$TEST_ID_TOKEN'
              }

              expect(entry.value).to eq(expected_result)
            end
          end

          describe '#valid?' do
            it 'is valid' do
              expect(entry).to be_valid
            end
          end
        end

        context 'when `token` is not defined' do
          let(:config) do
            {
              gcp_secret_manager: {
                name: 'name',
                version: '1'
              }
            }
          end

          describe '#valid?' do
            it 'is not valid' do
              expect(entry).not_to be_valid
            end
          end

          describe '#errors' do
            it 'reports error' do
              expect(entry.errors)
                .to include 'secret token is required with gcp secrets manager'
            end
          end
        end
      end

      context 'for Gitlab Secrets Manager' do
        context 'when config is valid' do
          let(:config) do
            {
              gitlab_secrets_manager: {
                name: 'name'
              }
            }
          end

          describe '#value' do
            it 'returns secret configuration' do
              expected_result = {
                gitlab_secrets_manager: {
                  name: 'name'
                }
              }

              expect(entry.value).to eq(expected_result)
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
  end

  context 'when entry value is not correct' do
    describe '#errors' do
      context 'when there is an unknown key present' do
        let(:config) { { foo: {} } }

        it 'reports error' do
          expect(entry.errors)
            .to include 'secret config contains unknown keys: foo'
        end
      end

      context 'when there is no vault entry' do
        let(:config) { {} }

        it 'reports error' do
          expect(entry.errors)
            .to include 'secret config must use exactly one of these keys: ' \
              'vault, azure_key_vault, gcp_secret_manager, gitlab_secrets_manager, aws_secrets_manager'
        end
      end

      Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS.permutation(2).each do |permutation|
        context "when there are multiple entries #{permutation}" do
          let(:config) { permutation.index_with({}) }

          it 'reports error' do
            expect(entry.errors)
              .to include "secret config must use exactly one of these keys: " \
                "#{Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS.join(', ')}"
          end
        end
      end
    end
  end

  context 'when config is nil' do
    let(:config) { nil }

    it 'is not valid' do
      expect(entry).not_to be_valid
    end
  end

  context 'when config is not a hash' do
    let(:config) { 123 }

    it 'is not valid' do
      expect(entry).not_to be_valid
    end
  end
end
