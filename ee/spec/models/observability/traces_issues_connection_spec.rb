# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::TracesIssuesConnection, feature_category: :observability do
  let_it_be(:issue) { create(:issue) }
  let_it_be(:connection) { create(:observability_traces_issues_connection) }

  describe 'associations' do
    it { is_expected.to belong_to(:issue).inverse_of(:observability_traces) }
  end

  describe '#populate_sharding_key' do
    it 'populating the project_id on save' do
      connection = create(:observability_traces_issues_connection, project_id: nil)

      expect(connection.project_id).to eq(connection.issue.project_id)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:issue_id) }
    it { is_expected.to validate_presence_of(:trace_identifier) }
    it { is_expected.to validate_length_of(:trace_identifier).is_at_most(128) }
  end

  it 'validates trace_identifier cannot be empty when creating connection' do
    connection = build(:observability_traces_issues_connection,
      issue: issue,
      trace_identifier: '' # empty trace identifier
    )
    expect(connection).not_to be_valid
  end

  it 'validates connection associated to the linked issue' do
    connection = build(:observability_traces_issues_connection)
    expect(connection).not_to be_valid
    expect(connection.errors[:issue_id]).to eq(["can't be blank"])
  end
end
