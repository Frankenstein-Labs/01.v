# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::DevelopmentType, feature_category: :team_planning do
  let(:fields) do
    %i[type feature_flags closing_merge_requests related_merge_requests will_auto_close_by_merge_request
      related_branches]
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetDevelopment') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end
