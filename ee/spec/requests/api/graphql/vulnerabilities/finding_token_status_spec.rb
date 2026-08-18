# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.vulnerability.findingTokenStatus', feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:vulnerability) { create(:vulnerability, project: project) }

  let(:vuln_gid) { vulnerability.to_global_id.to_s }
  let(:current_user) { user }
  let(:query) do
    <<~GQL
      query($id: VulnerabilityID!) {
        vulnerability(id: $id) {
          findingTokenStatus {
            id
            status
            createdAt
            updatedAt
            lastVerifiedAt
          }
        }
      }
    GQL
  end

  before_all do
    project.add_developer(user)
  end

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: { id: vuln_gid })
  end

  before do
    stub_licensed_features(security_dashboard: true, secret_detection_validity_checks: true)
  end

  shared_examples 'returns no token status' do
    it_behaves_like 'a working graphql query that returns data'

    it 'has a nil findingTokenStatus' do
      expect(graphql_data.dig('vulnerability', 'findingTokenStatus')).to be_nil
    end
  end

  context 'when report_type is not secret_detection' do
    before do
      vulnerability.update!(report_type: 'sast')
      post_query
    end

    it_behaves_like 'returns no token status'
  end

  context 'when report_type is secret_detection' do
    before do
      vulnerability.update!(report_type: 'secret_detection')
    end

    context 'when secret_detection_validity_checks is not licensed' do
      before do
        stub_licensed_features(security_dashboard: true, secret_detection_validity_checks: false)
        post_query
      end

      it_behaves_like 'returns no token status'
    end

    context 'when secret_detection_validity_checks is licensed' do
      before do
        stub_licensed_features(security_dashboard: true, secret_detection_validity_checks: true)
      end

      context 'when validity_checks_enabled is false' do
        before do
          project.security_setting.update!(validity_checks_enabled: false)
          post_query
        end

        it_behaves_like 'returns no token status'
      end

      context 'when validity_checks_enabled is true' do
        before do
          project.security_setting.update!(validity_checks_enabled: true)
        end

        context 'when the vulnerability has no finding' do
          before do
            post_query
          end

          it_behaves_like 'returns no token status'
        end

        context 'when there is a finding but no token status record' do
          before do
            create(:vulnerabilities_finding, vulnerability: vulnerability)
            post_query
          end

          it_behaves_like 'returns no token status'
        end

        context 'and there is a token status record' do
          let!(:finding) do
            create(
              :vulnerabilities_finding,
              :with_token_status,
              token_status: :active,
              vulnerability: vulnerability
            )
          end

          before do
            post_query
          end

          it_behaves_like 'a working graphql query that returns data'

          it 'returns the correct token status object' do
            expect(graphql_data.dig('vulnerability', 'findingTokenStatus', 'status')).to eq('ACTIVE')
          end
        end
      end
    end
  end
end
