# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::LogsIssuesHelper, feature_category: :observability do
  describe '#observability_logs_issues_params' do
    let(:params) do
      {
        'service' => 'UserService',
        'timestamp' => '2024-08-14T12:34:56Z',
        'fullUrl' => 'http://example.com/log/123',
        'traceId' => 'abc123',
        'fingerprint' => 'def456',
        'severityNumber' => '5',
        'body' => 'An error occurred'
      }
    end

    context 'when params are blank' do
      it 'returns an empty hash' do
        expect(helper.observability_logs_issues_params({})).to eq({})
        expect(helper.observability_logs_issues_params(nil)).to eq({})
      end
    end

    context 'when params are present' do
      it 'returns the correct hash' do
        result = helper.observability_logs_issues_params(params)

        expect(result[:title]).to eq("Issue created from log of 'UserService' service at 2024-08-14T12:34:56Z")
        expect(result[:description]).to eq(
          <<~TEXT
            [Log details](http://example.com/log/123) \\
            Service: `UserService` \\
            Trace ID: `abc123` \\
            Log Fingerprint: `def456` \\
            Severity Number: `5` \\
            Timestamp: `2024-08-14T12:34:56Z` \\
            Message:
            ```
            An error occurred
            ```
          TEXT
        )
      end
    end
  end
end
