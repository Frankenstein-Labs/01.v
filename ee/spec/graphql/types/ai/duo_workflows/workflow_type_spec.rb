# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::DuoWorkflows::WorkflowType, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  it { expect(described_class).to have_graphql_field(:user) }
  it { expect(described_class).to have_graphql_field(:work_item_links) }
  it { expect(described_class).to have_graphql_field(:merge_request_links) }
  it { expect(described_class).to have_graphql_field(:note_links) }
  it { expect(described_class).to have_graphql_field(:flow_metadata_version) }
  it { expect(described_class).to have_graphql_field(:flow_metadata_id) }
  it { expect(described_class).to have_graphql_field(:flow_metadata_schema_version) }
  it { expect(described_class).to have_graphql_field(:web_url) }

  describe 'field scopes' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name) do
      %w[archived stalled resourceIid resourceWebUrl webUrl user workItem workItemLinks mergeRequestLinks noteLinks
        mergeRequest summary title]
    end

    with_them do
      it "includes the correct scopes for the #{params[:field_name]} field" do
        expect(described_class.fields[field_name].instance_variable_get(:@scopes)).to include(:api, :read_api,
          :ai_features, :ai_workflows)
      end
    end
  end

  describe 'auditEvents field' do
    subject(:field) { described_class.fields['auditEvents'] }

    it { expect(described_class).to have_graphql_field(:audit_events) }

    it 'returns an AiAuditEvent connection type' do
      expect(field.type.unwrap.graphql_name).to eq('AiAuditEventConnection')
    end

    it 'requires :read_agent_artifacts authorization' do
      expect(field.instance_variable_get(:@authorize)).to contain_exactly(:read_agent_artifacts)
    end
  end
end
