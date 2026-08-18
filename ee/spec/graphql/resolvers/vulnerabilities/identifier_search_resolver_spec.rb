# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Vulnerabilities::IdentifierSearchResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project_2) { create(:project, namespace: group) }
  let_it_be(:other_project) { create(:project, namespace: create(:group)) }

  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  before_all do
    group.add_maintainer(user)

    create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-23')
    create(:vulnerabilities_identifier, project: project_2, external_type: 'cwe', name: 'CWE-24')
    create(:vulnerabilities_identifier, project: project, external_type: 'cwe', name: 'CWE-25')
    create(:vulnerabilities_identifier, project: other_project, external_type: 'cwe', name: 'CWE-26')

    create(:vulnerability_statistic, project: project)
    create(:vulnerability_statistic, project: project_2)
    create(:vulnerability_statistic, project: project)
    create(:vulnerability_statistic, project: other_project)
  end

  describe '#resolve' do
    subject(:search_results) { resolve(described_class, obj: obj, args: args, ctx: { current_user: current_user }) }

    shared_examples 'handles invalid search input' do
      context 'when the name argumentis less than 3 characters' do
        let(:args) { { name: 'ab' } }
        let(:error_msg) { 'Name should be greater than 3 characters.' }

        it 'raises an error for insufficient name length' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, error_msg) do
            search_results
          end
        end
      end
    end

    shared_examples 'when the current user has access' do
      let(:current_user) { user }

      context 'with a group' do
        let(:obj) { group }

        it 'fetches matching identifier names' do
          expect(search_results).to contain_exactly('CWE-23', 'CWE-24', 'CWE-25')
        end

        it_behaves_like 'handles invalid search input'
      end

      context 'with a project' do
        let(:obj) { project }

        it 'fetches matching identifier names' do
          expect(search_results).to contain_exactly('CWE-23', 'CWE-25')
        end

        it_behaves_like 'handles invalid search input'
      end
    end

    shared_examples 'when the current user does not have access' do
      let(:current_user) { other_user }

      context 'with a group' do
        let(:obj) { group }

        it 'returns resource not available' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
            search_results
          end
        end
      end
    end

    context 'when filtering records from postgres' do
      let!(:args) { { name: 'cwe' } }

      it_behaves_like 'when the current user has access'
      it_behaves_like 'when the current user does not have access'
    end

    context 'when filtering records from Elasticsearch', :elastic do
      let_it_be(:vulnerability_read_1) do
        create(:vulnerability_read, identifier_names: ['CWE-23'], project: project)
      end

      let_it_be(:vulnerability_read_2) do
        create(:vulnerability_read, identifier_names: ['CWE-25'], project: project)
      end

      let_it_be(:vulnerability_read_3) do
        create(:vulnerability_read, identifier_names: %w[CWE-24 test], project: project_2)
      end

      let_it_be(:vulnerability_read_4) do
        create(:vulnerability_read, identifier_names: ['CWE-26'], project: other_project)
      end

      let!(:args) { { name: 'cwe' } }
      let(:current_user) { user }
      let(:obj) { group }
      let(:vulnerable) { obj }

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

        Elastic::ProcessBookkeepingService.track!(
          vulnerability_read_1, vulnerability_read_2, vulnerability_read_3, vulnerability_read_4
        )
        ensure_elasticsearch_index!

        allow(::Search::Elastic::VulnerabilityIndexHelper)
          .to receive(:indexing_allowed?).and_return(true)
      end

      it_behaves_like 'when the current user has access'
      it_behaves_like 'when the current user does not have access'

      context 'when not on self-managed with Elasticsearch' do
        let(:current_user) { user }
        let(:obj) { group }

        before do
          # Stubbing advanced_vulnerability_management_allowed? as the policy internally uses it.
          # Otherwise the other stub on self_managed_with_es? causes the policy to return false.
          allow(::Search::Elastic::VulnerabilityIndexHelper)
            .to receive_messages(
              advanced_vulnerability_management_allowed?: true,
              self_managed_with_es?: false
            )
        end

        it 'does not validate self-managed first backfill', :aggregate_failures do
          expect(::Search::Elastic::VulnerabilityIndexHelper)
            .not_to receive(:self_managed_and_first_backfill_completed?)

          expect(search_results).to contain_exactly('CWE-23', 'CWE-24', 'CWE-25')
        end
      end
    end
  end
end
