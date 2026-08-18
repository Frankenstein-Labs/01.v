# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::StartAndDueDateType, feature_category: :team_planning do
  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :type,
      :due_date,
      :start_date,
      :roll_up,
      :is_fixed,
      :start_date_sourcing_work_item,
      :start_date_sourcing_milestone,
      :due_date_sourcing_work_item,
      :due_date_sourcing_milestone
    )
  end
end
