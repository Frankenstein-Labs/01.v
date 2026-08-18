# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::AiSessionType, feature_category: :duo_agent_platform do
  let(:fields) do
    %i[type duo_workflows]
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetAiSession') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end
