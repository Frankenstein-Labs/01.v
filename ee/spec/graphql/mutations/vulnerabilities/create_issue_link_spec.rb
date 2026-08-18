# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Vulnerabilities::CreateIssueLink, feature_category: :vulnerability_management do
  include GraphqlHelpers
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:current_user) { create(:user) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project) }

    let(:issue_global_id) { GitlabSchema.id_from_object(issue) }
    let(:vulnerability_global_id) { GitlabSchema.id_from_object(vulnerability) }

    context 'for issue link' do
      subject(:create_issue_link) do
        mutation.resolve(vulnerability_ids: [vulnerability_global_id], issue_id: issue_global_id)
      end

      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when user does not have access to the project' do
        it 'raises an error' do
          expect { create_issue_link }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when user has access to the project' do
        before do
          vulnerability.project.add_maintainer(current_user)
          allow_next_instance_of(::VulnerabilityIssueLinks::BulkCreateService) do |create_service|
            allow(create_service).to receive(:execute).and_return(result)
          end
        end

        context 'when issue creation succeeds' do
          let_it_be(:issue_link) { build(:vulnerabilities_issue_link, vulnerability: vulnerability) }

          let(:issue_links_collection) do
            class_double(Vulnerabilities::IssueLink, with_associations: [issue_link])
          end

          let(:result) do
            instance_double(ServiceResponse, success?: true, payload: { issue_links: issue_links_collection },
              errors: [])
          end

          it 'returns the issue link' do
            expect(create_issue_link[:issue_links]).to eq([issue_link])
          end

          it 'returns empty error collection' do
            expect(create_issue_link[:errors]).to be_empty
          end
        end
      end
    end
  end

  describe '.authorization_scopes' do
    it 'includes api, ai_workflows scope' do
      expect(described_class.authorization_scopes).to match_array([:api, :ai_workflows])
    end
  end
end
