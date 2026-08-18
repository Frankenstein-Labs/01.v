# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectRequirementStatusesExportMailerWorker,
  feature_category: :compliance_management,
  type: :worker do
  describe '#perform', time_travel_to: '2023-09-22' do
    let_it_be(:user) { create :user }
    let_it_be(:group) { create :group, :private }

    before_all do
      group.add_owner user
    end

    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    subject(:worker) { described_class.new.perform user.id, group.id }

    context 'with successful export' do
      let(:success_response) do
        ServiceResponse.success(payload: "test,csv,data")
      end

      let(:filename) { "2023-09-22-group_compliance_status_export-#{group.id}.csv" }

      before do
        allow_next_instance_of(ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::ExportService) do
        |export_service|
          allow(export_service).to receive(:execute).and_return(success_response)
        end
      end

      it 'schedules mail for delivery' do
        expect { worker }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sends the correct filename' do
        worker

        email = ActionMailer::Base.deliveries.last
        expect(email.attachments.first.filename).to eq(filename)
      end
    end

    context 'with failing export' do
      let(:error_response) { ServiceResponse.error(message: 'Custom error message') }

      before do
        allow_next_instance_of(ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::ExportService) do
        |export_service|
          allow(export_service).to receive(:execute).and_return(error_response)
        end
      end

      it 'raises an error with the custom error message' do
        expect { worker }.to raise_error(described_class::ExportFailedError, 'Custom error message')
      end

      it 'raises an error and does not schedule mail for delivery' do
        delivery_count = ActionMailer::Base.deliveries.count

        expect { worker }.to raise_error(described_class::ExportFailedError)

        expect(ActionMailer::Base.deliveries.count).to eq(delivery_count)
      end
    end

    context 'with unknown user' do
      it 'silently returns without sending email' do
        expect { described_class.new.perform(non_existing_record_id, group.id) }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'with unknown group' do
      it 'silently returns without sending email' do
        expect { described_class.new.perform(user.id, non_existing_record_id) }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end
end
