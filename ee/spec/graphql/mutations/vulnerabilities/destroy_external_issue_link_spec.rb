# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Vulnerabilities::DestroyExternalIssueLink, feature_category: :vulnerability_management do
  include GraphqlHelpers
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:vulnerability_external_issue_link) { create(:vulnerabilities_external_issue_link) }
    let_it_be(:current_user) { create(:user) }

    subject(:mutation_response) { mutation.resolve(id: GitlabSchema.id_from_object(vulnerability_external_issue_link)) }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when user does not have permissions to destroy external issue link' do
      it { expect { mutation_response }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable) }
    end

    context 'when user has permission to destroy external issue link' do
      before do
        vulnerability_external_issue_link.vulnerability.project.add_developer(current_user)
      end

      context 'when destroy succeeds' do
        before do
          allow_next_instance_of(::VulnerabilityExternalIssueLinks::DestroyService) do |destroy_service|
            allow(destroy_service).to receive(:execute).and_return(double(destroyed?: true))
          end
        end

        it { is_expected.to eq(errors: []) }
      end

      context 'when destroy fails' do
        before do
          allow_next_instance_of(::VulnerabilityExternalIssueLinks::DestroyService) do |destroy_service|
            allow(destroy_service).to receive(:execute).and_return(double(destroyed?: false))
          end
        end

        it { is_expected.to eq(errors: ['Error deleting the vulnerability external issue link']) }
      end
    end
  end
end
