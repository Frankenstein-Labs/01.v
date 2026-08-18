# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::Widgets::ColorInputType, feature_category: :team_planning do
  it { expect(described_class.graphql_name).to eq('WorkItemWidgetColorInput') }

  it { expect(described_class.arguments.keys).to contain_exactly('color') }
end
