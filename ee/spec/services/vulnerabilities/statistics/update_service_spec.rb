# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Statistics::UpdateService, feature_category: :vulnerability_management do
  describe '.update_for' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }
    let(:vulnerability) { instance_double(Vulnerability) }

    subject(:update_stats) { described_class.update_for(vulnerability) }

    before do
      allow(described_class).to receive(:new).with(vulnerability).and_return(mock_service_object)
    end

    it 'instantiates an instance of service class and calls execute on it' do
      update_stats

      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be_with_refind(:project) { create(:project) }
    let(:statistic) { create(:vulnerability_statistic, project: project) }
    let(:vulnerability) { create(:vulnerability, severity: :high, project: project) }

    subject(:update_stats) { described_class.new(vulnerability).execute }

    context 'when the vulnerability is updated, but the severity is not changed' do
      before do
        vulnerability.update_attribute(:detected_at, Time.current)
      end

      context 'and there is an existing vulnerability_statistics record in the database' do
        it 'does not change the existing vulnerability_statistics record' do
          expect { update_stats }.not_to change { statistic.reload.attributes }
        end
      end

      context 'and there is no existing vulnerability_statistics record in the database' do
        it 'does not create a new vulnerability_statistics record in the database' do
          expect { update_stats }.not_to change { Vulnerabilities::Statistic.count }.from(0)
        end
      end
    end

    context 'when the vulnerability severity is updated' do
      before do
        vulnerability.update_attribute(:severity, :critical)
      end

      context 'and there is an existing vulnerability_statistics record in the database' do
        it 'increments the severity value count matching the new severity level of the vulnerability' do
          expect { update_stats }.to change { statistic.reload.critical }.from(0).to(1)
        end

        context 'and the severity value count matching the existing severity value of the vulnerability is 0' do
          it 'does not decrement the severity value count matching the existing severity value' do
            expect { update_stats }.not_to change { statistic.reload.high }.from(0)
          end
        end

        context 'and the severity value count matching the existing severity value of the vuln is greater than 0' do
          let(:statistic) { create(:vulnerability_statistic, project: project, high: 2) }

          it 'decrements the severity value count matching the existing severity value' do
            expect { update_stats }.to change { statistic.reload.high }.from(2).to(1)
          end
        end
      end

      context 'and there is no existing vulnerability_statistics record in the database' do
        let_it_be_with_refind(:project) { create(:project, archived: true) }

        it 'creates a new record in the database with the expected values', :aggregate_failures do
          expect { update_stats }.to change { Vulnerabilities::Statistic.count }.from(0).to(1)

          expect(Vulnerabilities::Statistic.all).to contain_exactly(have_attributes(
            {
              critical: 1,
              high: 0,
              total: 1,
              project_id: project.id,
              archived: project.archived,
              traversal_ids: project.namespace.traversal_ids,
              letter_grade: 'f',
              created_at: be_a_kind_of(Time),
              updated_at: be_a_kind_of(Time)
            }))
        end
      end
    end
  end
end
