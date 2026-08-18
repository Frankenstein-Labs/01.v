# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::LogsIssuesConnection, feature_category: :observability do
  describe 'associations' do
    it { is_expected.to belong_to(:issue).inverse_of(:observability_logs) }
  end

  describe 'scopes' do
    describe '.with_params' do
      let_it_be(:issue) { create(:issue) }
      let_it_be(:project) { issue.project }
      let_it_be(:timestamp) { Time.current }
      let_it_be(:service_name) { 'test_service' }
      let_it_be(:severity_number) { 5 }
      let_it_be(:trace_identifier) { 'test_trace_123' }
      let_it_be(:log_fingerprint) { 'test_fingerprint_456' }

      let_it_be(:matching_connection) do
        create(:observability_logs_issues_connection,
          issue: issue,
          project: project,
          log_timestamp: timestamp,
          service_name: service_name,
          severity_number: severity_number,
          trace_identifier: trace_identifier,
          log_fingerprint: log_fingerprint
        )
      end

      let_it_be(:non_matching_connection) do
        create(:observability_logs_issues_connection,
          issue: issue,
          project: project,
          log_timestamp: 1.day.ago,
          service_name: 'other_service',
          severity_number: 10,
          trace_identifier: 'other_trace',
          log_fingerprint: 'other_fingerprint'
        )
      end

      it 'returns connections matching all provided parameters' do
        params = {
          timestamp: timestamp,
          service_name: service_name,
          severity_number: severity_number,
          trace_identifier: trace_identifier,
          fingerprint: log_fingerprint
        }

        result = described_class.with_params(params)

        expect(result).to include(matching_connection)
        expect(result).not_to include(non_matching_connection)
      end

      it 'returns no connections when no parameters match' do
        params = {
          timestamp: 2.days.ago,
          service_name: 'non_existent_service',
          severity_number: 20,
          trace_identifier: 'non_existent_trace',
          fingerprint: 'non_existent_fingerprint'
        }

        result = described_class.with_params(params)

        expect(result).to be_empty
      end
    end
  end

  describe '#populate_sharding_key' do
    it 'populating the project_id on save' do
      connection = create(:observability_logs_issues_connection, project_id: nil)

      expect(connection.project_id).to eq(connection.issue.project_id)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:issue_id) }

    it { is_expected.to validate_presence_of(:service_name) }
    it { is_expected.to validate_length_of(:service_name).is_at_most(500) }

    it { is_expected.to validate_presence_of(:severity_number) }

    it 'validates the value of severity_number is within 1..24' do
      is_expected.to validate_numericality_of(:severity_number)
        .only_integer
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(24)
    end

    it { is_expected.to validate_presence_of(:log_timestamp) }

    it { is_expected.to validate_presence_of(:trace_identifier) }
    it { is_expected.to validate_length_of(:trace_identifier).is_at_most(128) }

    it { is_expected.to validate_presence_of(:log_fingerprint) }
    it { is_expected.to validate_length_of(:log_fingerprint).is_at_most(128) }
  end

  it 'validates service_name cannot be empty when creating connection' do
    issue = create(:issue)
    connection = build(:observability_logs_issues_connection,
      service_name: '', # empty service name
      issue: issue
    )
    expect(connection).not_to be_valid
  end

  it 'validates connection associated to the linked issue' do
    connection = build(:observability_logs_issues_connection)
    expect(connection).not_to be_valid
    expect(connection.errors[:issue_id]).to eq(["can't be blank"])
  end
end
