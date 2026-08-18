# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Groups::ComplianceViolationsExportMailerWorker,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when user and group exist' do
      before_all do
        group.add_owner(user)
      end

      it 'calls the export service and sends email' do
        export_service = instance_double(ComplianceManagement::Groups::ComplianceViolations::ExportService)
        allow(ComplianceManagement::Groups::ComplianceViolations::ExportService)
          .to receive(:new).with(user: user, group: group).and_return(export_service)
        allow(export_service).to receive(:execute).and_return(ServiceResponse.success(payload: 'csv_data'))

        expect(Notify).to receive(:compliance_violations_csv_email).with(
          user: user,
          group: group,
          attachment: 'csv_data',
          filename: "#{Date.current.iso8601}-group_compliance_violations_export-#{group.id}.csv"
        ).and_call_original

        worker.perform(user.id, group.id)
      end

      context 'when export service fails' do
        it 'raises ExportFailedError' do
          export_service = instance_double(ComplianceManagement::Groups::ComplianceViolations::ExportService)
          allow(ComplianceManagement::Groups::ComplianceViolations::ExportService)
            .to receive(:new).with(user: user, group: group).and_return(export_service)
          allow(export_service).to receive(:execute).and_return(ServiceResponse.error(message: 'Export failed'))

          expect { worker.perform(user.id, group.id) }
            .to raise_error(described_class::ExportFailedError, 'Export failed')
        end
      end
    end

    context 'when user does not exist' do
      it 'does not send email' do
        expect(Notify).not_to receive(:compliance_violations_csv_email)

        worker.perform(non_existing_record_id, group.id)
      end
    end

    context 'when group does not exist' do
      it 'does not send email' do
        expect(Notify).not_to receive(:compliance_violations_csv_email)

        worker.perform(user.id, non_existing_record_id)
      end
    end
  end
end
