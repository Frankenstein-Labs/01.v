# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::DuoWorkflows::WorkflowNoteLinkType, feature_category: :duo_agent_platform do
  it_behaves_like 'a duo workflow link type'

  it { expect(described_class.graphql_name).to eq('DuoWorkflowNoteLink') }

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(:link_type, :note, :workflow, :created_at)
  end

  describe 'note link fields' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name) do
      %w[linkType note]
    end

    with_them do
      it "includes the AI token scopes for the #{params[:field_name]} field" do
        expect(described_class.fields[field_name].instance_variable_get(:@scopes))
          .to include(:api, :read_api, :ai_features, :ai_workflows)
      end
    end
  end
end
