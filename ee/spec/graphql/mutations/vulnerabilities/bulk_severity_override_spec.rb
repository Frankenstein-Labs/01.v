# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Vulnerabilities::BulkSeverityOverride, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:vulnerabilities) { create_list(:vulnerability, 2, project: project) }

  let(:vulnerability_ids) { vulnerabilities.map(&:to_global_id) }
  let(:include_comment) { true }
  let(:comment) { 'This is a comment' }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'vulnerability_ids validations' do
    let(:mutation) do
      <<~GQL
        mutation($vulnerabilityIds: [VulnerabilityID!]!, $comment: String!) {
          vulnerabilitiesSeverityOverride(input: {
            severity: LOW,
            vulnerabilityIds: $vulnerabilityIds
            #{include_comment ? ',comment: $comment' : ''}
          }) {
            errors
          }
        }
      GQL
    end

    def execute_mutation(variables: {})
      GraphQL::Query.new(GitlabSchema, mutation, variables: variables, context: {}).result
    end

    context 'when the number of vulnerability_ids exceeds the maximum allowed' do
      let(:vulnerability_ids) do
        Array.new(::Vulnerabilities::BulkSeverityOverrideService::MAX_BATCH + 1) do
          'gid://gitlab/Vulnerability/1'
        end
      end

      it 'returns a vulnerabilityIds validation error' do
        result = execute_mutation(variables: { vulnerabilityIds: vulnerability_ids, comment: comment })

        expect(result['errors'].first['message']).to include(
          "vulnerabilityIds is too long (maximum is #{::Vulnerabilities::BulkSeverityOverrideService::MAX_BATCH})")
      end

      context 'when comment input is missing' do
        let(:include_comment) { false }

        it 'returns a comment validation error' do
          result = execute_mutation(variables: { vulnerabilityIds: ['gid://gitlab/Vulnerability/1'] })

          expect(result['errors'].first['message']).to include(
            "Argument 'comment' on InputObject 'vulnerabilitiesSeverityOverrideInput' is required")
        end
      end
    end

    context 'when no vulnerability_ids are provided' do
      let(:vulnerability_ids) { [] }

      it 'returns a validation error' do
        result = execute_mutation(variables: { vulnerabilityIds: vulnerability_ids, comment: comment })

        expect(result['errors'].first['message']).to include('vulnerabilityIds is too short (minimum is 1)')
      end
    end

    context 'when vulnerability_ids are within valid range' do
      it 'executes successfully without validation errors' do
        result = execute_mutation(variables: { vulnerabilityIds: vulnerability_ids })

        expect(result['errors'].first['message']).not_to include('vulnerabilityIds')
      end
    end
  end

  describe '#resolve' do
    let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

    subject(:mutation_result) do
      mutation.resolve(
        vulnerability_ids: vulnerability_ids,
        comment: comment,
        severity: :critical
      )
    end

    it 'executes BulkSeverityOverrideService with the correct parameters' do
      service_double = instance_double(::Vulnerabilities::BulkSeverityOverrideService)
      allow(::Vulnerabilities::BulkSeverityOverrideService).to receive(:new).with(
        current_user,
        vulnerability_ids.map(&:model_id),
        comment,
        :critical
      ).and_return(service_double)

      allow(service_double).to receive(:execute).and_return(
        ServiceResponse.success(payload: { vulnerabilities: vulnerabilities })
      )

      expect(service_double).to receive(:execute)
      mutation_result
    end

    it 'handles service errors' do
      allow_next_instance_of(::Vulnerabilities::BulkSeverityOverrideService) do |service|
        allow(service).to receive(:execute)
          .and_return(ServiceResponse.error(message: "Could not modify vulnerabilities"))
      end

      expect(mutation_result[:errors]).to include('Could not modify vulnerabilities')
      expect(mutation_result[:vulnerabilities]).to eq([])
    end

    it 'handles access denied error' do
      allow_next_instance_of(::Vulnerabilities::BulkSeverityOverrideService) do |service|
        allow(service).to receive(:execute).and_raise(Gitlab::Access::AccessDeniedError)
      end

      expect { mutation_result }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end

  describe '.authorization_scopes' do
    it 'includes api, ai_workflows scope' do
      expect(described_class.authorization_scopes).to match_array([:api, :ai_workflows])
    end
  end

  describe 'field scopes' do
    it 'includes api, read_api, ai_workflows scope for vulnerabilities field' do
      vulnerabilities_field = described_class.fields['vulnerabilities']
      scopes = vulnerabilities_field.instance_variable_get(:@scopes)
      expect(scopes).to include(:api, :read_api, :ai_workflows)
    end
  end
end
