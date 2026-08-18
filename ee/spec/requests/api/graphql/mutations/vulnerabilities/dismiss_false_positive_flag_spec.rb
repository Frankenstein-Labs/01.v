# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'VulnerabilityDismissFalsePositiveFlag', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:finding) { vulnerability.findings.first }

  let(:mutation) do
    graphql_mutation(
      :vulnerability_dismiss_false_positive_flag,
      id: vulnerability.to_global_id.to_s
    )
  end

  let(:mutation_response) { graphql_mutation_response(:vulnerability_dismiss_false_positive_flag) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  shared_examples 'returns an error' do |error_message|
    it 'returns an error' do
      expect(mutation_response['errors']).to contain_exactly(error_message)
      expect(mutation_response['vulnerability']).to be_nil
    end
  end

  shared_examples 'denies access' do
    it 'denies access' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(
        a_hash_including(
          'message' => 'The resource that you are attempting to access does not exist ' \
            'or you don\'t have permission to perform this action'
        )
      )
    end
  end

  describe 'resolve' do
    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it_behaves_like 'denies access'
    end

    context 'when user does not have admin_vulnerability permission' do
      let(:current_user) { user }

      it_behaves_like 'denies access'
    end

    context 'when user has admin_vulnerability permission' do
      let(:current_user) { user }

      before_all do
        project.add_maintainer(user)
      end

      context 'when vulnerability exists' do
        let!(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detected as false positive'
          )
        end

        it 'creates a new vulnerability flag with dismissed attributes' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty

          vulnerability_response = mutation_response['vulnerability']
          expect(vulnerability_response).not_to be_nil
          expect(vulnerability_response['id']).to eq(vulnerability.to_global_id.to_s)
          expect(vulnerability_response['uuid']).to eq(vulnerability.finding_uuid)

          # Verify the flag was actually created in the database
          latest_flag = vulnerability.finding.vulnerability_flags.last
          expect(latest_flag.finding).to eq(finding)
          expect(latest_flag.flag_type).to eq('false_positive')
          expect(latest_flag.confidence_score).to eq(0.0)
          expect(latest_flag.origin).to start_with('manual_')
        end

        it_behaves_like 'authorizing granular token permissions for GraphQL', :update_vulnerability_flag do
          let(:boundary_object) { project }
          let(:authz_mutation) do
            graphql_mutation(
              :vulnerability_dismiss_false_positive_flag,
              { id: vulnerability.to_global_id.to_s },
              'errors'
            )
          end

          let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
        end

        context 'when manual flags already exist for the vulnerability' do
          let!(:existing_manual_flag) do
            create(
              :vulnerabilities_flag,
              finding: finding,
              flag_type: :false_positive,
              origin: 'manual',
              confidence_score: 0.0,
              description: 'Previous manual dismissal'
            )
          end

          let!(:ai_flag) do
            create(
              :vulnerabilities_flag,
              finding: finding,
              flag_type: :false_positive,
              origin: 'ai_sast_fp_detection_v2',
              confidence_score: 0.8,
              status: :detected_as_fp,
              description: 'AI detection'
            )
          end

          it 'creates a new manual flag instead of updating existing one' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to be_empty

            vulnerability_response = mutation_response['vulnerability']
            expect(vulnerability_response).not_to be_nil
            expect(vulnerability_response['id']).to eq(vulnerability.to_global_id.to_s)
            expect(vulnerability_response['uuid']).to eq(vulnerability.finding_uuid)

            # Verify a new flag was created
            new_flag = vulnerability.finding.vulnerability_flags.last
            expect(new_flag).not_to eq(existing_manual_flag)
            expect(new_flag.finding).to eq(finding)
            expect(new_flag.flag_type).to eq('false_positive')
            expect(new_flag.confidence_score).to eq(0.0)
            expect(new_flag.origin).to start_with('manual_')

            # Verify existing flag is unchanged
            existing_manual_flag.reload
            expect(existing_manual_flag.description).to eq('Previous manual dismissal')
          end
        end
      end

      context 'when vulnerability does not exist' do
        let(:mutation) do
          graphql_mutation(
            :vulnerability_dismiss_false_positive_flag,
            id: "gid://gitlab/Vulnerability/#{non_existing_record_id}"
          )
        end

        it_behaves_like 'denies access'
      end

      context 'when vulnerability has no finding' do
        let!(:vulnerability_without_finding) { create(:vulnerability, project: project) }
        let(:mutation) do
          graphql_mutation(
            :vulnerability_dismiss_false_positive_flag,
            id: vulnerability_without_finding.to_global_id.to_s
          )
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to contain_exactly('No current finding available')
          expect(mutation_response['vulnerability']).to be_nil
        end
      end

      context 'when vulnerability has no flags' do
        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to contain_exactly('No vulnerability flag available to dismiss')
          expect(mutation_response['vulnerability']).to be_nil
        end
      end

      context 'when latest vulnerability flag has confidence score of 0.0' do
        let!(:existing_flag_with_zero_confidence) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.0,
            description: 'Already dismissed'
          )
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to contain_exactly('No vulnerability flag available to dismiss')
          expect(mutation_response['vulnerability']).to be_nil
        end
      end

      context 'when latest vulnerability flag has confidence score greater than 0.0' do
        let!(:existing_flag_with_positive_confidence) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detected as false positive'
          )
        end

        it 'creates a new vulnerability flag with dismissed attributes' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty

          vulnerability_response = mutation_response['vulnerability']
          expect(vulnerability_response).not_to be_nil
          expect(vulnerability_response['id']).to eq(vulnerability.to_global_id.to_s)
          expect(vulnerability_response['uuid']).to eq(vulnerability.finding_uuid)

          # Verify the flag was actually created in the database
          latest_flag = vulnerability.finding.vulnerability_flags.last
          expect(latest_flag.finding).to eq(finding)
          expect(latest_flag.flag_type).to eq('false_positive')
          expect(latest_flag.confidence_score).to eq(0.0)
          expect(latest_flag.origin).to start_with('manual_')
        end
      end

      context 'when service returns an error' do
        let!(:existing_ai_flag) do
          create(
            :vulnerabilities_flag,
            finding: finding,
            flag_type: :false_positive,
            origin: 'ai_sast_fp_detection',
            confidence_score: 0.8,
            status: :detected_as_fp,
            description: 'AI detected as false positive'
          )
        end

        before do
          allow_next_instance_of(Vulnerabilities::Flags::DismissFalsePositiveService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Service error')
            )
          end
        end

        it 'returns the service error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to contain_exactly('Service error')
          expect(mutation_response['vulnerability']).to be_nil
        end
      end
    end
  end

  describe 'authorization' do
    let(:current_user) { user }

    context 'when security_dashboard feature is not available' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      before_all do
        project.add_maintainer(user)
      end

      it_behaves_like 'denies access'
    end

    context 'when user has different permission levels' do
      using RSpec::Parameterized::TableSyntax

      where(:role, :can_access) do
        :guest      | false
        :reporter   | false
        :developer  | false
        :maintainer | true
        :owner      | true
      end

      with_them do
        before do
          project.add_member(user, role)
        end

        if params[:can_access]
          it 'allows access' do
            create(
              :vulnerabilities_flag,
              finding: finding,
              flag_type: :false_positive,
              origin: 'ai_sast_fp_detection',
              confidence_score: 0.8,
              status: :detected_as_fp,
              description: 'AI detected as false positive'
            )

            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response).to have_key('vulnerability')
          end
        else
          it_behaves_like 'denies access'
        end
      end
    end
  end
end
