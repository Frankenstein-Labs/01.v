# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Standards::ExportService, feature_category: :compliance_management do
  subject(:service) { described_class.new user: user, group: group }

  let_it_be(:user) { create(:user, name: 'Foo Bar') }
  let_it_be(:group) { create(:group, name: 'parent') }
  let_it_be(:project) do
    create :project, :repository, namespace: group, name: 'Parent Project', path: 'parent_project'
  end

  let(:executed) { service.execute }
  let(:payload) { CSV.parse(executed.payload) }
  let(:expected_header) { ["Status", "Project ID", "Check", "Standard", "Date since last status change"] }

  describe '#execute' do
    context 'without visibility to user' do
      it { expect(service.execute).to be_error }

      it 'exports a CSV payload with just the header' do
        expect(service.execute.message).to eq "Access to group denied for user with ID: #{user.id}"
      end
    end

    context 'with a authorized user' do
      before_all do
        group.add_owner(user)
      end

      before do
        stub_licensed_features(group_level_compliance_adherence_report: true)
      end

      context 'with no standards adherences' do
        it 'exports a CSV payload without standards adherences' do
          expect(executed).to be_success
          expect(payload).to match_array [expected_header]
        end
      end

      context 'with a standards adherence' do
        let_it_be(:adherence) { create(:compliance_standards_adherence, project: project) }
        let(:expected_row) do
          ["success", project.id.to_s, "prevent_approval_by_merge_request_author", "gitlab", adherence.updated_at.to_s]
        end

        it 'exports a CSV payload' do
          expect(payload).to match_array [expected_header, expected_row]
        end

        context 'when a subgroup has adherences available' do
          let_it_be(:subgroup) { create(:group, parent: group) }
          let_it_be(:subgroup_project) do
            create :project, :repository, namespace: subgroup, name: 'Child Project', path: 'child_project'
          end

          let_it_be(:subgroup_adherence) { create(:compliance_standards_adherence, project: subgroup_project) }
          let(:additional_row) do
            ["success", subgroup_project.id.to_s, "prevent_approval_by_merge_request_author", "gitlab",
              subgroup_adherence.updated_at.to_s]
          end

          it 'includes the subgroup in the payload' do
            expect(payload).to match_array [expected_header, expected_row, additional_row]
          end
        end

        it "avoids N+1 when exporting" do
          service.execute # warm up cache

          build :compliance_standards_adherence

          control = ActiveRecord::QueryRecorder.new(query_recorder_debug: true) { service.execute }

          build :compliance_standards_adherence

          expect { service.execute }.not_to exceed_query_limit(control)
        end
      end
    end
  end

  describe '#email_export' do
    let(:worker) { ComplianceManagement::StandardsAdherenceExportMailerWorker }

    it 'enqueues a worker' do
      expect(worker).to receive(:perform_async).with(user.id, group.id)

      expect(service.email_export).to be_success
    end
  end
end
