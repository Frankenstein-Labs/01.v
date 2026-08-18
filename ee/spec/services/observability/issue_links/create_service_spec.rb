# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::IssueLinks::CreateService, feature_category: :observability do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let(:links) { {} }
  let(:service) { described_class.new(project, user, issue: issue, links: links) }
  let(:execute) { service.execute }

  describe '#execute' do
    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(observability: true)
    end

    context 'when gitlab observability is not allowed' do
      before do
        stub_licensed_features(observability: false)
      end

      it 'errors with no permission' do
        expect(execute.status).to eq(:error)
        expect(execute.message).to include('No permission')
      end
    end

    context 'when links are not present altogether' do
      it 'creates no observability connections' do
        expect { execute }.not_to change { ::Observability::MetricsIssuesConnection.count }
        expect { execute }.not_to change { ::Observability::LogsIssuesConnection.count }

        expect(execute.status).to eq(:success)
      end
    end

    context 'when insufficient link params are present' do
      let(:links) do
        { foo: "bar" }
      end

      it 'errors with insufficient link params' do
        expect(execute.status).to eq(:error)
        expect(execute.message).to include('Insufficient link params')
      end
    end

    context 'when persisting observability metrics links' do
      let(:links) do
        {
          metric_details_name: "test_name",
          metric_details_type: "sum_type"
        }
      end

      it 'creates a metric connection' do
        expect { execute }.to change { ::Observability::MetricsIssuesConnection.count }.by(1)
        expect(execute.status).to eq(:success)
      end

      context 'when invalid link-params are passed' do
        before do
          links[:metric_details_name] = "*" * 501 # can be 500 characters long only
        end

        it 'creates no metric connection' do
          expect { execute }.not_to change { ::Observability::MetricsIssuesConnection.count }
          expect(execute.status).to eq(:error)
          expect(execute.message).to include("Validation failed")
        end
      end
    end

    context 'when persisting observability logs links' do
      let(:links) do
        {
          log_service_name: "test_name",
          log_severity_number: 9,
          log_fingerprint: "03fe551c28e5c64b",
          log_timestamp: Time.current,
          log_trace_id: "fa12d360-54cd-c4db-5241-ccf7841d3e72"
        }
      end

      it 'creates a log connection' do
        expect { execute }.to change { ::Observability::LogsIssuesConnection.count }.by(1)
        expect(execute.status).to eq(:success)
      end

      context 'when invalid link-params are passed' do
        before do
          links[:log_severity_number] = 100 # can be 1 .. 24 only
        end

        it 'creates no log connection' do
          expect { execute }.not_to change { ::Observability::LogsIssuesConnection.count }
          expect(execute.status).to eq(:error)
          expect(execute.message).to include("Validation failed")
        end
      end
    end

    context 'when persisting observability trace links' do
      let(:links) do
        {
          trace_id: "fa12d360-54cd-c4db-5241-ccf7841d3e72"
        }
      end

      it 'creates a trace connection' do
        expect { execute }.to change { ::Observability::TracesIssuesConnection.count }.by(1)
        expect(execute.status).to eq(:success)
      end

      context 'when invalid link-params are passed' do
        before do
          links[:trace_id] = "*" * 129 # can be 128 characters only
        end

        it 'creates no trace connection' do
          expect { execute }.not_to change { ::Observability::TracesIssuesConnection.count }
          expect(execute.status).to eq(:error)
          expect(execute.message).to include("Validation failed")
        end
      end
    end
  end
end
