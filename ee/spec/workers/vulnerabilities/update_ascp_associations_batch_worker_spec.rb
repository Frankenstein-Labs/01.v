# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::UpdateAscpAssociationsBatchWorker, feature_category: :static_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }
  let_it_be(:component_app) { create(:security_ascp_component, project: project, scan: scan, sub_directory: 'app') }
  let_it_be(:component_services) do
    create(:security_ascp_component, project: project, scan: scan, sub_directory: 'app/services')
  end

  let_it_be(:finding_services) do
    create(:vulnerabilities_finding, project: project, location: { 'file' => 'app/services/auth.rb' })
  end

  let_it_be(:finding_app) do
    create(:vulnerabilities_finding, project: project, location: { 'file' => 'app/models/user.rb' })
  end

  let_it_be(:finding_unmatched) do
    create(:vulnerabilities_finding, project: project, location: { 'file' => 'lib/other.rb' })
  end

  let(:finding_ids) { [finding_services.id, finding_app.id, finding_unmatched.id] }
  let(:job_args) { [project.id, finding_ids] }

  it_behaves_like 'an idempotent worker'

  it 'delegates to the service and logs the stats it returns' do
    response = ServiceResponse.success(payload: { matched: 2, unmatched: 1, removed: 0 })
    service = instance_double(Security::Ascp::BulkSetComponentService, execute: response)
    worker = described_class.new

    expect(Security::Ascp::BulkSetComponentService).to receive(:new)
      .with(project: project, finding_ids: finding_ids).and_return(service)
    expect(worker).to receive(:log_extra_metadata_on_done)
      .with(:stats, { matched: 2, unmatched: 1, removed: 0, batch_size: 3 })

    worker.perform(project.id, finding_ids)
  end

  context 'when the project does not exist' do
    it 'does nothing' do
      expect(Security::Ascp::BulkSetComponentService).not_to receive(:new)

      described_class.new.perform(non_existing_record_id, finding_ids)
    end
  end
end
