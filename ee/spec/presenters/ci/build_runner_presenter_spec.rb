# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildRunnerPresenter, feature_category: :secrets_management do
  subject(:presenter) { described_class.new(ci_build) }

  describe '#secrets_configuration' do
    let!(:ci_build) { create(:ee_ci_build, secrets: secrets, id_tokens: id_tokens) }
    let(:jwt_token) { "TESTING" }
    let(:id_tokens) { nil }

    context 'build has no secrets' do
      let(:secrets) { {} }

      it 'returns empty hash' do
        expect(presenter.secrets_configuration).to eq({})
      end
    end

    context 'build has secrets' do
      context 'with Hashicorp vault' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              file: true,
              vault: {
                engine: { name: 'kv-v2', path: 'kv-v2' },
                path: 'production/db',
                field: 'password'
              }
            }
          }
        end

        before do
          create(:ci_variable, project: ci_build.project, key: 'VAULT_SERVER_URL', value: 'https://vault.example.com')
        end

        context 'Vault server URL' do
          let(:vault_server) { presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server') }

          context 'VAULT_SERVER_URL CI variable is present' do
            it 'returns the URL' do
              expect(vault_server.fetch('url')).to eq('https://vault.example.com')
            end
          end
        end

        context 'Vault auth role' do
          let(:vault_auth_data) do
            presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth', 'data')
          end

          context 'VAULT_AUTH_ROLE CI variable is present' do
            it 'contains the auth role' do
              create(:ci_variable, project: ci_build.project, key: 'VAULT_AUTH_ROLE', value: 'production')

              expect(vault_auth_data.fetch('role')).to eq('production')
            end
          end

          context 'VAULT_AUTH_ROLE CI variable is not present' do
            it 'skips the auth role' do
              expect(vault_auth_data).not_to have_key('role')
            end
          end
        end

        context 'Vault auth path' do
          let(:vault_auth) { presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth') }

          context 'VAULT_AUTH_PATH CI variable is present' do
            it 'contains user defined auth path' do
              create(:ci_variable, project: ci_build.project, key: 'VAULT_AUTH_PATH', value: 'custom/path')

              expect(vault_auth.fetch('path')).to eq('custom/path')
            end
          end

          context 'VAULT_AUTH_PATH CI variable is not present' do
            it 'contains the default auth path' do
              expect(vault_auth.fetch('path')).to eq('jwt')
            end
          end
        end

        context 'Vault namespace' do
          let(:vault_server) { presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server') }

          context 'VAULT_NAMESPACE CI variable is present' do
            it 'contains user defined namespace' do
              create(:ci_variable, project: ci_build.project, key: 'VAULT_NAMESPACE', value: 'custom_namespace')

              expect(vault_server.fetch('namespace')).to eq('custom_namespace')
            end
          end

          context 'VAULT_NAMESPACE CI variable is not present' do
            it 'returns nil' do
              expect(vault_server.fetch('namespace')).to be_nil
            end
          end
        end

        context 'File variable configuration' do
          subject { presenter.secrets_configuration['DATABASE_PASSWORD'] }

          it 'contains the file configuration directive' do
            expect(subject.fetch('file')).to be_truthy
          end
        end

        context 'when there are ID tokens available' do
          let(:id_tokens) do
            {
              'VAULT_ID_TOKEN_1' => { aud: 'https://gitlab.test' },
              'VAULT_ID_TOKEN_2' => { aud: 'https://gitlab.link' }
            }
          end

          before do
            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'adds the first ID token to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth', 'data', 'jwt')

            expect(jwt).to eq('$VAULT_ID_TOKEN_1')
          end

          context 'when the token variable is specified for the vault secret' do
            let(:secrets) do
              {
                DATABASE_PASSWORD: {
                  file: true,
                  token: '$VAULT_ID_TOKEN_2',
                  vault: {
                    engine: { name: 'kv-v2', path: 'kv-v2' },
                    path: 'production/db',
                    field: 'password'
                  }
                }
              }
            end

            it 'uses the specified token variable' do
              jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'vault', 'server', 'auth', 'data', 'jwt')

              expect(jwt).to eq('$VAULT_ID_TOKEN_2')
            end
          end
        end
      end

      context 'with Azure key vault' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              azure_key_vault: {
                name: 'key',
                version: 'version'
              }
            }
          }
        end

        let(:azure_key_vault_server) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server')
        end

        context 'Vault azure key vault server url' do
          context 'AZURE_KEY_VAULT_SERVER_URL CI variable is present' do
            it 'returns the URL' do
              create(:ci_variable, project: ci_build.project, key: 'AZURE_KEY_VAULT_SERVER_URL', value: 'test')

              expect(azure_key_vault_server.fetch('url')).to eq('test')
            end
          end

          context 'AZURE_KEY_VAULT_SERVER_URL CI variable is not present' do
            it 'returns the nil' do
              expect(azure_key_vault_server.fetch('url')).to be_nil
            end
          end
        end

        context 'Vault client id' do
          context 'AZURE_CLIENT_ID CI variable is present' do
            it 'returns the URL' do
              create(:ci_variable, project: ci_build.project, key: 'AZURE_CLIENT_ID', value: 'test')

              expect(azure_key_vault_server.fetch('client_id')).to eq('test')
            end
          end

          context 'AZURE_CLIENT_ID CI variable is not present' do
            it 'returns the nil' do
              expect(azure_key_vault_server.fetch('client_id')).to be_nil
            end
          end
        end

        context 'Vault tenant id' do
          context 'AZURE_TENANT_ID CI variable is present' do
            it 'returns the URL' do
              create(:ci_variable, project: ci_build.project, key: 'AZURE_TENANT_ID', value: 'test')

              expect(azure_key_vault_server.fetch('tenant_id')).to eq('test')
            end
          end

          context 'AZURE_TENANT_ID CI variable is not present' do
            it 'returns the nil' do
              expect(azure_key_vault_server.fetch('tenant_id')).to be_nil
            end
          end
        end

        context 'when there are ID tokens available' do
          let(:id_tokens) do
            {
              'VAULT_ID_TOKEN_1' => { aud: 'https://gitlab.test' },
              'VAULT_ID_TOKEN_2' => { aud: 'https://gitlab.link' }
            }
          end

          before do
            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'adds the first ID token to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server', 'jwt')
            expect(jwt).to eq('$VAULT_ID_TOKEN_1')
          end

          context 'when the token variable is specified for the vault secret' do
            let(:secrets) do
              {
                DATABASE_PASSWORD: {
                  token: '$VAULT_ID_TOKEN_2',
                  azure_key_vault: {
                    name: 'key',
                    version: 'version'
                  }
                }
              }
            end

            it 'uses the specified token variable' do
              jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server', 'jwt')

              expect(jwt).to eq('$VAULT_ID_TOKEN_2')
            end
          end
        end

        context 'when there are no ID tokens available' do
          it 'adds CI_JOB_JWT_V2 to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'azure_key_vault', 'server', 'jwt')

            expect(jwt).to eq('${CI_JOB_JWT_V2}')
          end
        end
      end

      context 'with AWS Secrets Manager' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              aws_secrets_manager: {
                secret_id: 'key',
                version_id: 'version'
              }
            }
          }
        end

        let(:aws_secrets_manager_server) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server')
        end

        context 'Secrets Manager Region' do
          context 'AWS_REGION CI variable is present' do
            it 'returns the Region' do
              create(:ci_variable, project: ci_build.project, key: 'AWS_REGION', value: 'test')

              expect(aws_secrets_manager_server.fetch('region')).to eq('test')
            end
          end

          context 'AWS_REGION CI variable is not present' do
            it 'returns the nil' do
              expect(aws_secrets_manager_server.fetch('region')).to be_nil
            end
          end
        end

        context 'AWS Role ARN' do
          context 'AWS_ROLE_ARN CI variable is present' do
            it 'returns the Arn' do
              create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_ARN', value: 'test')

              expect(aws_secrets_manager_server.fetch('role_arn')).to eq('test')
            end
          end

          context 'AWS_ROLE_ARN CI variable is not present' do
            it 'returns the nil' do
              expect(aws_secrets_manager_server.fetch('role_arn')).to be_nil
            end
          end
        end

        context 'AWS Role Session Name' do
          context 'AWS_ROLE_SESSION_NAME CI variable is present' do
            it 'returns the Role Session Name' do
              create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_SESSION_NAME', value: 'test')

              expect(aws_secrets_manager_server.fetch('role_session_name')).to eq('test')
            end
          end

          context 'AWS_ROLE_SESSION_NAME CI variable is not present' do
            it 'returns the nil' do
              expect(aws_secrets_manager_server.fetch('role_session_name')).to be_nil
            end
          end
        end

        context 'when there are ID tokens available' do
          let(:id_tokens) do
            {
              'VAULT_ID_TOKEN_2' => { aud: 'https://gitlab.link' },
              'AWS_ID_TOKEN' => { aud: 'https://gitlab.test' }
            }
          end

          before do
            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'adds the AWS_ID_TOKEN to the Vault server payload' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server', 'jwt')

            expect(jwt).to eq('$AWS_ID_TOKEN')
          end

          context 'when the token variable is specified for the vault secret' do
            let(:secrets) do
              {
                DATABASE_PASSWORD: {
                  token: '$VAULT_ID_TOKEN_2',
                  aws_secrets_manager: {
                    secret_id: 'key',
                    version_id: 'version'
                  }
                }
              }
            end

            it 'uses the specified token variable' do
              jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server', 'jwt')

              expect(jwt).to eq('$VAULT_ID_TOKEN_2')
            end
          end
        end

        context 'when there are no ID tokens available' do
          it 'returns AWS_ID_TOKEN so runner handles the empty variable' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'aws_secrets_manager', 'server', 'jwt')

            expect(jwt).to eq('$AWS_ID_TOKEN')
          end
        end

        context 'with all AWS configuration variables present' do
          let(:id_tokens) { { 'AWS_ID_TOKEN' => { aud: 'https://aws.example.com' } } }

          before do
            create(:ci_variable, project: ci_build.project, key: 'AWS_REGION', value: 'us-west-2')
            create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_ARN',
              value: 'arn:aws:iam::123456789012:role/test-role')
            create(:ci_variable, project: ci_build.project, key: 'AWS_ROLE_SESSION_NAME', value: 'gitlab-ci-session')

            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)
            ci_build.runner = build_stubbed(:ci_runner)
          end

          it 'returns a complete server configuration' do
            expect(aws_secrets_manager_server).to eq({
              'region' => 'us-west-2',
              'role_arn' => 'arn:aws:iam::123456789012:role/test-role',
              'role_session_name' => 'gitlab-ci-session',
              'jwt' => '$AWS_ID_TOKEN'
            })
          end
        end
      end

      context 'with GCP Secret Manager' do
        let(:secrets) do
          {
            DATABASE_PASSWORD: {
              gcp_secret_manager: {
                name: 'key',
                version: '2'
              },
              token: '$GCP_SM_ID_TOKEN'
            }
          }
        end

        let(:gcp_secret_manager_server) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'gcp_secret_manager', 'server')
        end

        context 'GCP project number' do
          context 'GCP_PROJECT_NUMBER CI variable is present' do
            it 'returns the value' do
              create(:ci_variable, project: ci_build.project, key: 'GCP_PROJECT_NUMBER', value: '1234')

              expect(gcp_secret_manager_server.fetch('project_number')).to eq('1234')
            end
          end

          context 'GCP_PROJECT_NUMBER CI variable is not present' do
            it 'returns nil' do
              expect(gcp_secret_manager_server.fetch('project_number')).to be_nil
            end
          end
        end

        context 'GCP workload federation pool id' do
          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID CI variable is present' do
            it 'returns the pool id' do
              create(:ci_variable, project: ci_build.project, key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID',
                value: 'pool')

              expect(gcp_secret_manager_server.fetch('workload_identity_federation_pool_id')).to eq('pool')
            end
          end

          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_POOL_ID CI variable is not present' do
            it 'returns nil' do
              expect(gcp_secret_manager_server.fetch('workload_identity_federation_pool_id')).to be_nil
            end
          end
        end

        context 'GCP workload federation provider id' do
          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID CI variable is present' do
            it 'returns the provider id' do
              create(:ci_variable, project: ci_build.project, key: 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID',
                value: 'provider')

              expect(gcp_secret_manager_server.fetch('workload_identity_federation_provider_id')).to eq('provider')
            end
          end

          context 'GCP_WORKLOAD_IDENTITY_FEDERATION_PROVIDER_ID CI variable is not present' do
            it 'returns nil' do
              expect(gcp_secret_manager_server.fetch('workload_identity_federation_provider_id')).to be_nil
            end
          end
        end

        context 'JWT token' do
          it 'uses the specified token variable' do
            jwt = presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'gcp_secret_manager', 'server', 'jwt')

            expect(jwt).to eq('$GCP_SM_ID_TOKEN')
          end
        end
      end

      context 'with Gitlab Secrets Manager' do
        let(:gitlab_secrets_manager_payload) do
          presenter.secrets_configuration.dig('DATABASE_PASSWORD', 'gitlab_secrets_manager')
        end

        let(:gitlab_secrets_manager_server) do
          gitlab_secrets_manager_payload['server']
        end

        before do
          # The presenter delegates SM availability to `Availability`. Stub it
          # here at the abstraction boundary; the AND-composition of license/FF/
          # enrollment is covered in `availability_spec.rb`. Negative-path tests
          # below override per-context to return `false`.
          allow(::SecretsManagement::Availability)
            .to receive_messages(for_project?: true, for_group?: true)

          # Default happy-path entitlement so existing contexts (which predate the
          # entitlement check) keep exercising the `ci_jwt` path. Overridden below.
          entitlement = instance_double(SecretsManagement::Entitlement, permits_direct_read?: true)
          allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
        end

        context 'when project level secret' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          let(:project_secrets_manager) do
            SecretsManagement::ProjectSecretsManager.find_by(project: ci_build.project)
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            allow_any_instance_of(SecretsManagement::ProjectSecretsManager).to receive(:ci_jwt).and_return(jwt_token) # rubocop:disable RSpec/AnyInstanceOf -- It's not the next instance
          end

          it 'sets the correct values for the payload' do
            expect(gitlab_secrets_manager_payload).to include(
              'path' => project_secrets_manager.ci_data_path('password'),
              'field' => 'value',
              'engine' => {
                'name' => 'kv-v2',
                'path' => project_secrets_manager.ci_secrets_mount_full_path
              }
            )
          end

          it 'sets the correct values for the server configuration' do
            expect(gitlab_secrets_manager_server).to include(
              'url' => SecretsManagement::ProjectSecretsManager.server_url,
              'inline_auth' => {
                'jwt' => jwt_token,
                'role' => "all_pipelines",
                'path' => project_secrets_manager.ci_auth_path
              }
            )
            expect(gitlab_secrets_manager_server.dig('inline_auth', 'path')).to include('/cel/')
          end
        end

        context 'when secret name contains path traversal characters' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "secret/../other"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
          end

          it 'raises ArgumentError from sanitized_ci_data_path' do
            expect { presenter.secrets_configuration }.to raise_error(ArgumentError, /Invalid secret key/)
          end
        end

        context 'when project level secret but no project secrets manager exists' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when project level secret but project secrets manager is not active' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :provisioning, project: ci_build.project)
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when project level secret but SM availability is not satisfied' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            # SM-availability AND combinations are covered in availability_spec.rb.
            # Here we only verify the runner gates on `Availability.for_project?`.
            allow(::SecretsManagement::Availability)
              .to receive(:for_project?).with(ci_build.project).and_return(false)
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when project level secret but entitlement is ineligible' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            entitlement = ::SecretsManagement::Entitlement.new(state: :ineligible)
            allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when project level secret but entitlement is blocked in the grace window' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            allow_next_found_instance_of(SecretsManagement::ProjectSecretsManager) do |sm|
              allow(sm).to receive(:ci_jwt).and_return(jwt_token)
            end
            entitlement = ::SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :grace)
            allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
          end

          it 'still returns the payload (read-only carve-out)' do
            expect(gitlab_secrets_manager_payload).not_to eq({})
          end

          it 'does not emit denial telemetry' do
            expect(::SecretsManagement::Entitlement::DenialTelemetry).not_to receive(:track)

            gitlab_secrets_manager_payload
          end
        end

        context 'when project level secret but entitlement is blocked for a non-grace reason' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            entitlement = ::SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :trial_expired)
            allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end

          it 'emits denial telemetry for the ci_runner_payload surface' do
            expect(::SecretsManagement::Entitlement::DenialTelemetry)
              .to receive(:track).with(hash_including(surface: :ci_runner_payload))

            gitlab_secrets_manager_payload
          end
        end

        context 'when project level secret but entitlement is trial_eligible after the beta cutoff' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            entitlement = ::SecretsManagement::Entitlement.new(state: :trial_eligible, beta_program_ended: true)
            allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end

          it 'emits denial telemetry for the ci_runner_payload surface' do
            expect(::SecretsManagement::Entitlement::DenialTelemetry)
              .to receive(:track).with(hash_including(surface: :ci_runner_payload))

            gitlab_secrets_manager_payload
          end
        end

        context 'when project level secret and entitlement is trial_eligible before the beta cutoff' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            allow_next_found_instance_of(SecretsManagement::ProjectSecretsManager) do |sm|
              allow(sm).to receive(:ci_jwt).and_return(jwt_token)
            end
            entitlement = ::SecretsManagement::Entitlement.new(state: :trial_eligible, beta_program_ended: false)
            allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
          end

          it 'still returns the payload (free beta access)' do
            expect(gitlab_secrets_manager_payload).not_to eq({})
          end

          it 'does not emit denial telemetry' do
            expect(::SecretsManagement::Entitlement::DenialTelemetry).not_to receive(:track)

            gitlab_secrets_manager_payload
          end
        end

        context 'when project level secret and entitlement is not paid-experience-aware' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password"
                }
              }
            }
          end

          before do
            create(:project_secrets_manager, :active, project: ci_build.project)
            allow_next_found_instance_of(SecretsManagement::ProjectSecretsManager) do |sm|
              allow(sm).to receive(:ci_jwt).and_return(jwt_token)
            end
            stub_feature_flags(secrets_manager_paid_experience: false)
          end

          it 'still returns the payload, ignoring entitlement' do
            expect(gitlab_secrets_manager_payload).not_to eq({})
          end
        end

        context 'when group level secret for a root group' do
          let_it_be_with_reload(:group) { create(:group) }

          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password",
                  source: "group/#{group.full_path}"
                }
              }
            }
          end

          let(:group_secrets_manager) do
            SecretsManagement::GroupSecretsManager.find_by(group: group)
          end

          before do
            create(:group_secrets_manager, :active, group: group)
            allow_next_found_instance_of(SecretsManagement::GroupSecretsManager) do |sm|
              allow(sm).to receive(:ci_jwt).and_return(jwt_token)
            end
            allow(ci_build.project).to receive(:group) { group }
          end

          it 'sets the correct values for the server configuration' do
            expect(gitlab_secrets_manager_server).to include(
              'url' => SecretsManagement::GroupSecretsManager.server_url,
              'inline_auth' => {
                'jwt' => jwt_token,
                'role' => "all_pipelines",
                'path' => group_secrets_manager.ci_auth_path
              }
            )
          end

          it 'sets the correct values for the payload' do
            expect(gitlab_secrets_manager_payload).to include(
              'path' => group_secrets_manager.ci_data_path('password'),
              'field' => 'value',
              'engine' => {
                'name' => 'kv-v2',
                'path' => group_secrets_manager.ci_secrets_mount_full_path
              }
            )
          end

          context 'when group SM availability is not satisfied' do
            before do
              # SM-availability AND combinations are covered in availability_spec.rb.
              # Here we only verify the runner gates on `Availability.for_group?`.
              allow(::SecretsManagement::Availability)
                .to receive(:for_group?).with(group).and_return(false)
            end

            it 'returns empty hash for the payload' do
              expect(gitlab_secrets_manager_payload).to eq({})
            end
          end

          context 'when group entitlement is ineligible' do
            before do
              entitlement = ::SecretsManagement::Entitlement.new(state: :ineligible)
              allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
            end

            it 'returns empty hash for the payload' do
              expect(gitlab_secrets_manager_payload).to eq({})
            end
          end

          context 'when group entitlement is blocked in the grace window' do
            before do
              entitlement = ::SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :grace)
              allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
            end

            it 'still returns the payload (read-only carve-out)' do
              expect(gitlab_secrets_manager_payload).not_to eq({})
            end
          end

          context 'when group entitlement is blocked for a non-grace reason' do
            before do
              entitlement = ::SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :credits_exhausted)
              allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
            end

            it 'returns empty hash for the payload' do
              expect(gitlab_secrets_manager_payload).to eq({})
            end

            it 'emits denial telemetry for the ci_runner_payload surface' do
              expect(::SecretsManagement::Entitlement::DenialTelemetry)
                .to receive(:track).with(hash_including(surface: :ci_runner_payload))

              gitlab_secrets_manager_payload
            end
          end

          context 'when the paid experience feature flag is disabled' do
            before do
              stub_feature_flags(secrets_manager_paid_experience: false)
            end

            it 'still returns the payload, ignoring entitlement' do
              expect(gitlab_secrets_manager_payload).not_to eq({})
            end
          end
        end

        context 'when group level secret for a nested subgroup' do
          let_it_be_with_reload(:root_group) { create(:group) }
          let_it_be_with_reload(:child_group) { create(:group, parent: root_group) }

          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password",
                  source: "group/#{child_group.full_path}"
                }
              }
            }
          end

          let(:group_secrets_manager) do
            SecretsManagement::GroupSecretsManager.find_by(group: child_group)
          end

          before do
            create(:group_secrets_manager, :active, group: child_group)
            allow_next_found_instance_of(SecretsManagement::GroupSecretsManager) do |sm|
              allow(sm).to receive(:ci_jwt).and_return(jwt_token)
            end
            allow(ci_build.project).to receive(:group) { child_group }
          end

          it 'sets the correct values for the server configuration' do
            expect(gitlab_secrets_manager_server).to include(
              'url' => SecretsManagement::GroupSecretsManager.server_url,
              'inline_auth' => {
                'jwt' => jwt_token,
                'role' => "all_pipelines",
                'path' => group_secrets_manager.ci_auth_path
              }
            )
          end

          it 'sets the correct values for the payload' do
            expect(gitlab_secrets_manager_payload).to include(
              'path' => group_secrets_manager.ci_data_path('password'),
              'field' => 'value',
              'engine' => {
                'name' => 'kv-v2',
                'path' => group_secrets_manager.ci_secrets_mount_full_path
              }
            )
          end
        end

        context 'when project in nested subgroup accesses ancestor group secrets' do
          let_it_be_with_reload(:root_group) { create(:group) }
          let_it_be_with_reload(:child_group) { create(:group, parent: root_group) }

          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password",
                  source: "group/#{root_group.full_path}"
                }
              }
            }
          end

          let(:group_secrets_manager) do
            SecretsManagement::GroupSecretsManager.find_by(group: root_group)
          end

          before do
            create(:group_secrets_manager, :active, group: root_group)
            allow_next_found_instance_of(SecretsManagement::GroupSecretsManager) do |sm|
              allow(sm).to receive(:ci_jwt).and_return(jwt_token)
            end
            allow(ci_build.project).to receive(:group) { child_group }
          end

          it 'sets the correct values for the server configuration using the ancestor group' do
            expect(gitlab_secrets_manager_server).to include(
              'url' => SecretsManagement::GroupSecretsManager.server_url,
              'inline_auth' => {
                'jwt' => jwt_token,
                'role' => "all_pipelines",
                'path' => group_secrets_manager.ci_auth_path
              }
            )
          end

          it 'sets the correct values for the payload using the ancestor group secrets manager' do
            expect(gitlab_secrets_manager_payload).to include(
              'path' => group_secrets_manager.ci_data_path('password'),
              'field' => 'value',
              'engine' => {
                'name' => 'kv-v2',
                'path' => group_secrets_manager.ci_secrets_mount_full_path
              }
            )
          end
        end

        context 'when project does not belong to a group' do
          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password",
                  source: "group/some_group"
                }
              }
            }
          end

          before do
            allow(ci_build.project).to receive(:group).and_return(nil)
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when group is not an ancestor of the project' do
          let_it_be(:project_group) { create(:group) }
          let_it_be(:unrelated_group) { create(:group) }

          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password",
                  source: "group/#{unrelated_group.full_path}"
                }
              }
            }
          end

          before do
            allow(ci_build.project).to receive(:group) { project_group }
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when group secrets manager does not exist for the group' do
          let_it_be_with_reload(:group) { create(:group) }

          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password",
                  source: "group/#{group.full_path}"
                }
              }
            }
          end

          before do
            allow(ci_build.project).to receive(:group) { group }
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when group secrets manager exists but is not active' do
          let_it_be_with_reload(:group) { create(:group) }

          let(:secrets) do
            {
              DATABASE_PASSWORD: {
                gitlab_secrets_manager: {
                  name: "password",
                  source: "group/#{group.full_path}"
                }
              }
            }
          end

          before do
            create(:group_secrets_manager, :provisioning, group: group)
            allow(ci_build.project).to receive(:group) { group }
          end

          it 'returns empty hash for the payload' do
            expect(gitlab_secrets_manager_payload).to eq({})
          end
        end

        context 'when multiple secrets reference the same group' do
          let_it_be_with_reload(:group) { create(:group) }

          let(:secrets) do
            {
              SECRET_ONE: {
                gitlab_secrets_manager: { name: "secret_one", source: "group/#{group.full_path}" }
              },
              SECRET_TWO: {
                gitlab_secrets_manager: { name: "secret_two", source: "group/#{group.full_path}" }
              }
            }
          end

          before do
            create(:group_secrets_manager, :active, group: group)
            allow_next_found_instance_of(SecretsManagement::GroupSecretsManager) do |sm|
              allow(sm).to receive(:ci_jwt).and_return(jwt_token)
            end
            allow(ci_build.project).to receive(:group) { group }
          end

          it 'only queries the database once for the group secrets manager' do
            expect(SecretsManagement::GroupSecretsManager).to receive(:find_by_group_id).once.and_call_original

            presenter.secrets_configuration
          end

          it 'only queries self_and_ancestors once' do
            ancestors_relation = group.self_and_ancestors
            allow(group).to receive(:self_and_ancestors).and_return(ancestors_relation)
            allow(ci_build.project).to receive(:group).and_return(group)

            expect(ancestors_relation).to receive(:find_by_full_path).once.and_call_original

            presenter.secrets_configuration
          end
        end
      end
    end
  end

  describe '#policy_options' do
    subject(:policy_options) { presenter.policy_options }

    let(:ci_build) { build(:ee_ci_build) }

    context 'when not an execution policy job' do
      it { is_expected.to be_nil }
    end

    context 'when an execution policy job' do
      let(:ci_build) { build(:ee_ci_build, :execution_policy_job) }

      it 'includes policy-specific options' do
        expect(policy_options).to eq(
          execution_policy_job: true,
          policy_name: 'My policy'
        )
      end
    end

    context 'when an execution policy job with variables override' do
      let(:ci_build) { build(:ee_ci_build, :execution_policy_job_with_variables_override) }

      it 'includes policy-specific options' do
        expect(policy_options).to eq(
          execution_policy_job: true,
          policy_name: 'My policy',
          policy_variables_override_allowed: false,
          policy_variables_override_exceptions: ['TEST_VAR']
        )
      end

      context 'when exceptions are empty array' do
        let(:ci_build) do
          build(:ee_ci_build, :execution_policy_job_with_variables_override, variables_override_exceptions: [])
        end

        it 'does not include them in the response' do
          expect(policy_options).to eq(
            execution_policy_job: true,
            policy_name: 'My policy',
            policy_variables_override_allowed: false
          )
        end
      end
    end

    # TODO: Remove with https://gitlab.com/gitlab-org/gitlab/-/issues/577272
    context 'when policy options use an old format' do
      let(:ci_build) do
        build(:ee_ci_build, options: { execution_policy_job: true, execution_policy_name: 'My policy',
                                       execution_policy_variables_override: { allowed: false, exceptions: %w[TEST_VAR] } })
      end

      it 'includes policy-specific options' do
        expect(policy_options).to eq(
          execution_policy_job: true,
          policy_name: 'My policy',
          policy_variables_override_allowed: false,
          policy_variables_override_exceptions: ['TEST_VAR']
        )
      end
    end
  end
end
