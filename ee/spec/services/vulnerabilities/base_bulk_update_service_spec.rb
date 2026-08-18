# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BaseBulkUpdateService, feature_category: :vulnerability_management do
  let(:current_user) { create(:user) }
  let(:vulnerability_ids) { [1, 2, 3, 4, 5] }
  let(:comment) { 'Test comment' }
  let(:service) { described_class.new(current_user, vulnerability_ids, comment) }
  let!(:vulnerabilities) { create_list(:vulnerability, 5) }

  before do
    allow(service).to receive(:authorized_and_ff_enabled_for_all_projects?).and_return(true)
  end

  describe '#execute' do
    context 'when authorized' do
      it 'calls update with vulnerabilities ids' do
        expect(service).to receive(:update).with(vulnerability_ids).once
        service.execute
      end

      it 'returns a successful service response' do
        allow(service).to receive(:update).and_return(nil)

        response = service.execute
        expect(response).to be_success
        expect(response.payload[:vulnerabilities]).to eq(Vulnerability.id_in(vulnerability_ids))
      end

      it 'refreshes statistics when project ids are present' do
        allow(service).to receive(:update).and_return(nil)
        allow(service).to receive(:refresh_statistics)

        service.execute
        expect(service).to have_received(:refresh_statistics).once
      end

      context 'when an error occurs' do
        before do
          allow(service).to receive(:update).and_raise(ActiveRecord::ActiveRecordError)
        end

        it 'returns an error response' do
          response = service.execute
          expect(response).to be_error
          expect(response.message).to eq('Could not modify vulnerabilities')
        end
      end

      describe '#refresh_statistics' do
        let(:project_ids) { vulnerabilities.map(&:project_id) }

        before do
          allow(Vulnerabilities::Statistics::AdjustmentWorker).to receive(:perform_async)
        end

        it 'calls statistics adjustment worker for affected projects' do
          allow(service).to receive_messages(update: nil, project_ids: project_ids)
          service.execute

          expect(Vulnerabilities::Statistics::AdjustmentWorker)
            .to have_received(:perform_async)
                  .with(project_ids)
        end

        it 'doesnt call statistics adjustment worker when no project are affected' do
          allow(service).to receive_messages(update: nil, project_ids: [])
          service.execute

          expect(Vulnerabilities::Statistics::AdjustmentWorker).not_to have_received(:perform_async)
        end
      end
    end

    context 'when not authorized' do
      before do
        allow(service).to receive(:authorized_and_ff_enabled_for_all_projects?).and_return(false)
      end

      it 'raises an AccessDeniedError' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end
  end

  describe '#authorized_and_ff_enabled_for_all_projects?' do
    it 'checks if user is authorized for each project' do
      allow(Project).to receive(:id_in).and_return([instance_double(Project, project_id: 1)])
      allow(service).to receive(:can?).and_return(true)

      expect(service.send(:authorized_for_project, nil)).to be_truthy
      expect(service.send(:authorized_and_ff_enabled_for_all_projects?)).to be_truthy
    end
  end

  describe '#now' do
    it 'memoizes the current time' do
      time1 = service.send(:now)
      time2 = service.send(:now)
      expect(time1).to eq(time2)
    end
  end

  describe '#update' do
    it 'requires a subclass overrides it' do
      expect { service.send(:update, {}) }.to raise_error(NotImplementedError)
    end
  end
end
