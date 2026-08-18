# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::DetectionTransitions::InsertService, feature_category: :vulnerability_management do
  subject(:service) { described_class.new(findings_list, detected: detected) }

  let_it_be(:project) { create(:project) }
  let_it_be(:detected) { true }
  let_it_be(:findings_list) { [] }

  describe '#execute' do
    context "when vulnerabilities exist" do
      let_it_be(:vulnerability_list) { create_list(:vulnerability, 2, project: project) }

      let_it_be(:findings_list) do
        [
          create(:vulnerabilities_finding, vulnerability: vulnerability_list[0], project: project),
          create(:vulnerabilities_finding, vulnerability: vulnerability_list[1], project: project)
        ]
      end

      let(:vulnerability_ids) { vulnerability_list.map(&:id) }

      it "inserts the corresponding detection transitions", :freeze_time do
        expect(Vulnerabilities::DetectionTransition).to receive(:bulk_insert!)

        service.execute
      end

      it "syncs to elasticsearch" do
        expect(Vulnerabilities::EsHelper).to receive(:sync_elasticsearch)
          .with(vulnerability_ids)

        service.execute
      end
    end

    context "when vulnerability findings list is empty" do
      let(:findings_list) { [] }

      it "does not insert any records" do
        expect(Vulnerabilities::DetectionTransition).not_to receive(:bulk_insert!)

        service.execute
      end
    end

    context "when detected is empty" do
      let(:detected) { nil }

      it "does not insert any records" do
        expect(Vulnerabilities::DetectionTransition).not_to receive(:bulk_insert!)

        service.execute
      end
    end

    context "when batch size exceeds MAX_BATCH_SIZE" do
      let_it_be(:vulnerability_list) { create_list(:vulnerability, 4, project: project) }
      let_it_be(:findings_list) do
        vulnerability_list.map do |vulnerability|
          create(:vulnerabilities_finding, vulnerability: vulnerability, project: project)
        end
      end

      it "processes records in batches" do
        stub_const("#{described_class}::MAX_BATCH_SIZE", 2)
        expect(Vulnerabilities::DetectionTransition).to receive(:bulk_insert!).twice

        service.execute
      end
    end

    context "when an error occurs" do
      let(:vulnerability_finding_ids) { findings_list.map(&:id) }

      let_it_be(:findings_list) { [create(:vulnerabilities_finding, project: project)] }

      before do
        allow(::Vulnerabilities::DetectionTransition).to receive(:bulk_insert!)
          .and_raise(StandardError, "Database error")
      end

      it "tracks the exception" do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(StandardError), vulnerability_finding_ids: vulnerability_finding_ids)

        service.execute
      end

      it "returns an error response" do
        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result.error?).to be(true)
        expect(result.message).to eq("Database error")
      end
    end
  end
end
