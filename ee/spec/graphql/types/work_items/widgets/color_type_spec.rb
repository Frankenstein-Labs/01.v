# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::Widgets::ColorType, feature_category: :portfolio_management do
  let(:fields) do
    %i[type color text_color]
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetColor') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end
