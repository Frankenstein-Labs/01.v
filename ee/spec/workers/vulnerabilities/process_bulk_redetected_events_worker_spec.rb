# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ProcessBulkRedetectedEventsWorker, feature_category: :vulnerability_management, type: :job do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:vulnerabilities) do
    create_list(:vulnerability, 3, :with_findings, :with_pipeline, :resolved, :high_severity, project: project)
  end

  let(:bulk_redetected_event) do
    ::Vulnerabilities::BulkRedetectedEvent.new(data: {
      vulnerabilities: vulnerabilities.map do |vulnerability|
        {
          vulnerability_id: vulnerability.id,
          pipeline_id: pipeline.id,
          timestamp: vulnerability.detected_at.iso8601
        }
      end
    })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always
  it_behaves_like 'subscribes to event' do
    let(:event) { bulk_redetected_event }
  end

  subject(:use_event) { consume_event(subscriber: described_class, event: bulk_redetected_event) }

  it 'invokes Vulnerabilities::BulkCreateRedetectedNotesService' do
    expect_next_instance_of(Vulnerabilities::BulkCreateRedetectedNotesService,
      bulk_redetected_event.data[:vulnerabilities]) do |instance|
      expect(instance).to receive(:execute)
    end

    use_event
  end
end
