# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Finding::RefreshSecurityFindingTokenStatus, feature_category: :secret_detection do
  include GraphqlHelpers

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }
  let_it_be_with_reload(:project) { create(:project) }

  shared_examples 'raises ResourceNotAvailable error' do
    it 'raises ResourceNotAvailable error' do
      expect { execute }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end

  describe '#resolve' do
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
    let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
    let_it_be(:security_scan) do
      create(:security_scan, project: project, build: build, scan_type: :secret_detection)
    end

    let_it_be_with_reload(:pat_token) { create(:personal_access_token) }
    let_it_be(:security_finding) do
      create(:security_finding,
        scan: security_scan,
        uuid: SecureRandom.uuid,
        finding_data: {
          'name' => 'GitLab personal access token',
          'identifiers' => [
            {
              'external_type' => 'gitleaks_rule_id',
              'external_id' => 'gitlab_personal_access_token',
              'name' => 'Gitleaks rule ID gitlab_personal_access_token'
            }
          ],
          'raw_source_code_extract' => pat_token.token
        }
      )
    end

    subject(:execute) { mutation.resolve(security_finding_uuid: security_finding.uuid) }

    context 'when a user is not logged in' do
      let(:current_user) { nil }

      it_behaves_like 'raises ResourceNotAvailable error'
    end

    context 'when the user does not have access to the project' do
      let_it_be(:current_user) { create(:user) }

      it_behaves_like 'raises ResourceNotAvailable error'
    end

    context 'when the user does not have the required permission' do
      let_it_be(:current_user) { create(:user) }

      before_all do
        project.add_guest(current_user)
      end

      it_behaves_like 'raises ResourceNotAvailable error'
    end

    context 'when the user has permission to refresh the status' do
      let_it_be(:current_user) { create(:user) }

      before_all do
        project.add_developer(current_user)
      end

      context 'when the project is not licensed to use validity checks' do
        before do
          stub_licensed_features(secret_detection_validity_checks: false)
        end

        it_behaves_like 'raises ResourceNotAvailable error'
      end

      context 'when validity checks is disabled for the project' do
        before do
          project.security_setting.update!(validity_checks_enabled: false)
        end

        it_behaves_like 'raises ResourceNotAvailable error'
      end

      context 'when license is available' do
        before do
          stub_licensed_features(secret_detection_validity_checks: true)
          project.security_setting.reload.update!(validity_checks_enabled: true)
        end

        context 'when the security finding does not exist' do
          it 'raises ResourceNotAvailable' do
            expect do
              mutation.resolve(security_finding_uuid: 'fake-uuid')
            end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end

        context 'when no token status record was created' do
          let(:finding_without_token) do
            create(:security_finding,
              scan: security_scan,
              finding_data: {
                'name' => 'Unsupported secret type',
                'identifiers' => [
                  {
                    'external_type' => 'gitleaks_rule_id',
                    'external_id' => 'unsupported_secret_type',
                    'name' => 'Unsupported'
                  }
                ],
                'raw_source_code_extract' => 'some-value'
              }
            )
          end

          subject(:execute) { mutation.resolve(security_finding_uuid: finding_without_token.uuid) }

          it 'returns status not found message' do
            result = execute

            finding_without_token.reload
            expect(finding_without_token.token_status).to be_nil
            expect(result[:errors]).to eq(["Token status not found."])
            expect(result[:finding_token_status]).to be_nil
          end
        end

        context 'when the security finding has a token status' do
          let_it_be(:token_status) do
            create(:security_finding_token_status, security_finding: security_finding, status: 'active')
          end

          it 'calls the update service with security finding id' do
            result = execute

            expect(result[:errors]).to be_empty
            expect(result[:finding_token_status]).to eq(token_status)
          end

          context 'when the token is revoked' do
            before do
              pat_token.revoke!
            end

            it 'updates the token status to inactive' do
              result = execute

              token_status.reload
              expect(token_status.status).to eq('inactive')
              expect(result[:errors]).to be_empty
              expect(result[:finding_token_status]).to eq(token_status)
            end
          end
        end

        context 'when multiple security findings have the same UUID' do
          let_it_be(:shared_uuid) { SecureRandom.uuid }
          let_it_be_with_reload(:shared_pat_token) { create(:personal_access_token) }
          let_it_be(:finding_data) do
            {
              'name' => 'GitLab personal access token',
              'identifiers' => [
                {
                  'external_type' => 'gitleaks_rule_id',
                  'external_id' => 'gitlab_personal_access_token',
                  'name' => 'Gitleaks rule ID gitlab_personal_access_token'
                }
              ],
              'raw_source_code_extract' => shared_pat_token.token
            }
          end

          let_it_be(:security_finding_1) do
            create(:security_finding,
              scan: security_scan,
              uuid: shared_uuid,
              finding_data: finding_data
            )
          end

          let_it_be(:another_build) { create(:ci_build, pipeline: pipeline) }
          let_it_be(:another_scan) do
            create(:security_scan, project: project, build: another_build, scan_type: :secret_detection)
          end

          let_it_be(:security_finding_2) do
            create(:security_finding,
              scan: another_scan,
              uuid: shared_uuid,
              finding_data: finding_data
            )
          end

          subject(:execute) { mutation.resolve(security_finding_uuid: security_finding_1.uuid) }

          it 'creates token statuses for security findings with the same UUID' do
            expect(security_finding_1.token_status).to be_nil
            expect(security_finding_2.token_status).to be_nil

            result = execute

            security_finding_1.reload
            security_finding_2.reload

            expect(security_finding_1.token_status).to be_present
            expect(security_finding_1.token_status.status).to eq('active')

            expect(security_finding_2.token_status).to be_present
            expect(security_finding_2.token_status.status).to eq('active')

            expect(result[:errors]).to be_empty
            expect(result[:finding_token_status]).to eq(security_finding_1.token_status)
          end

          context 'when the token is revoked' do
            before do
              shared_pat_token.revoke!
            end

            it 'marks all findings as inactive' do
              execute

              security_finding_1.reload
              security_finding_2.reload

              expect(security_finding_1.token_status.status).to eq('inactive')
              expect(security_finding_2.token_status.status).to eq('inactive')
            end
          end
        end
      end
    end
  end

  describe 'validation checks' do
    it 'requires update_secret_detection_validity_check_status permission' do
      expect(described_class).to require_graphql_authorizations(:update_secret_detection_validity_check_status)
    end
  end
end
