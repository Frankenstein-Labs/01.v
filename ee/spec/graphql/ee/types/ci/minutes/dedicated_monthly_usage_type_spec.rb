# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiDedicatedHostedRunnerUsage'], feature_category: :hosted_runners do
  include GraphqlHelpers
  include AdminModeHelper

  subject(:type) { described_class }

  let_it_be(:fields) do
    %i[
      billing_month billing_month_iso8601 compute_minutes duration_seconds
      compute_minutes_usage duration_minutes root_namespace
    ]
  end

  before do
    stub_application_setting(gitlab_dedicated_instance: true)
  end

  it { is_expected.to have_graphql_fields(fields) }

  describe 'root_namespace field' do
    let(:field) { described_class.fields['rootNamespace'] }

    it 'has the correct type and nullability' do
      expect(field.type.to_type_signature).to eq('NamespaceUnion')
      expect(field.type.non_null?).to be false
    end

    it 'has the correct description' do
      expect(field.description).to eq('Namespace associated with the usage data. Null for instance aggregate data.')
    end
  end

  describe 'compute_minutes_usage field' do
    let(:field) { described_class.fields['computeMinutesUsage'] }

    it 'has the correct type and nullability' do
      expect(field.type.to_type_signature).to eq('Float!')
      expect(field.type.non_null?).to be true
    end
  end

  describe 'duration_minutes field' do
    let(:field) { described_class.fields['durationMinutes'] }

    it 'has the correct type and nullability' do
      expect(field.type.to_type_signature).to eq('Float!')
      expect(field.type.non_null?).to be true
    end
  end

  describe 'executed query' do
    subject(:execute_query) { GitlabSchema.execute(query, context: { current_user: admin }).as_json }

    let_it_be(:admin) { create(:user, :admin) }
    let_it_be(:namespace) { create(:namespace, owner: admin) }

    let!(:billing_month) { Date.new(2025, 1, 1) }
    let!(:billing_month_arg) { billing_month.iso8601 }
    let!(:usage_with_namespace) do
      record = create(
        :ci_hosted_runner_monthly_usage,
        root_namespace: namespace,
        compute_minutes_used: 120,
        runner_duration_seconds: 7200,
        billing_month: billing_month
      )

      record
    end

    let(:query) do
      <<~GRAPHQL
        query {
          ciDedicatedHostedRunnerUsage(
            grouping: PER_ROOT_NAMESPACE,#{' '}
            billingMonth: "#{billing_month_arg}",
            runnerId: "#{usage_with_namespace.runner.to_global_id}"
          ) {
            nodes {
              billingMonth
              billingMonthIso8601
              computeMinutes
              durationSeconds
              computeMinutesUsage
              durationMinutes
              rootNamespace {
                __typename
                ... on Namespace {
                  id
                  avatarUrl
                  name
                }
                ... on CiDeletedNamespace {
                  id
                }
              }
            }
          }
        }
      GRAPHQL
    end

    before do
      enable_admin_mode!(admin)
    end

    context 'with an associated namespace' do
      it 'returns namespace data for records with valid namespaces' do
        result = execute_query

        nodes = result.dig('data', 'ciDedicatedHostedRunnerUsage', 'nodes')

        expect(nodes).not_to be_nil
        expect(nodes[0]['rootNamespace']).not_to be_nil
        expect(nodes[0]['rootNamespace']).to include('id', 'name')
      end

      it 'returns both integer and float field values' do
        result = execute_query

        nodes = result.dig('data', 'ciDedicatedHostedRunnerUsage', 'nodes')
        node = nodes[0]

        # Integer fields (rounded down)
        expect(node['computeMinutes']).to eq(120)
        expect(node['durationSeconds']).to eq(7200)

        # Float fields (precise values)
        expect(node['computeMinutesUsage']).to eq(120.0)
        expect(node['durationMinutes']).to eq(120.0) # 7200 seconds = 120 minutes
      end
    end

    context 'with a deleted namespace' do
      before do
        namespace.destroy!
      end

      it 'returns namespace data for records with valid namespaces' do
        result = execute_query

        nodes = result.dig('data', 'ciDedicatedHostedRunnerUsage', 'nodes')

        expect(nodes).not_to be_nil
        expect(nodes[0]['rootNamespace']).not_to be_nil
        expect(nodes[0]['rootNamespace']).to include('id')
        expect(nodes[0]['rootNamespace']).not_to include('name', 'avatarUrl')
      end
    end
  end
end
