# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::UpdateAscpAssociationsWorker, feature_category: :static_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:finding_1) { create(:vulnerabilities_finding, project: project) }
  let_it_be(:finding_2) { create(:vulnerabilities_finding, project: project) }

  let(:job_args) { [project.id] }

  subject(:perform) { described_class.new.perform(project.id) }

  it_behaves_like 'an idempotent worker' do
    it 'enqueues a batch worker with the project findings' do
      expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).to receive(:perform_in)
        .with(described_class::DELAY_INTERVAL, project.id, match_array([finding_1.id, finding_2.id]))

      perform
    end
  end

  it 'logs the number of scheduled batches' do
    worker = described_class.new

    expect(worker).to receive(:log_extra_metadata_on_done).with(:batches_scheduled, 1)

    worker.perform(project.id)
  end

  context 'when the project does not exist' do
    it 'does not enqueue any batch worker' do
      expect(Vulnerabilities::UpdateAscpAssociationsBatchWorker).not_to receive(:perform_in)

      described_class.new.perform(non_existing_record_id)
    end
  end
end
