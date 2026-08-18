# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::Widgets::StatusFilterInputType, feature_category: :team_planning do
  it { expect(described_class.graphql_name).to eq('WorkItemWidgetStatusFilterInput') }

  it { expect(described_class.arguments.keys).to match_array(%w[id name]) }
end
