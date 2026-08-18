# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalService,
  feature_category: :compliance_management do
  let_it_be_with_reload(:project) { create(:project, :in_group) }
  let(:params) { {} }

  let(:service) { described_class.new(project: project, params: params) }

  describe '#execute' do
    context 'when project belongs to user namespace' do
      let_it_be(:project) { create(:project) }

      it 'returns unavailable for user namespace error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Compliance standards adherence is not available for user namespace')
      end
    end

    context 'when group_level_compliance_dashboard feature is not available' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: false)
      end

      it 'returns feature not available error' do
        response = service.execute

        expect(response.status).to eq(:error)
        expect(response.message).to eq('Compliance standards adherence feature not available')
      end
    end

    context 'when group_level_compliance_dashboard feature is available' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: true)
      end

      context 'when approval rules are not defined' do
        it 'sets the check as fail' do
          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'at_least_one_non_author_approval',
              standard: 'soc2'
            )
        end
      end

      context 'with valid rules it sets the check as pass' do
        using RSpec::Parameterized::TableSyntax

        where(:approvals_required, :prevent_approval_by_committer, :merge_requests_author_approval, :status) do
          0  | false  | false | 'fail'
          0  | false  | true  | 'fail'
          0  | true   | false | 'fail'
          0  | true   | true  | 'fail'
          1  | false  | false | 'fail'
          1  | false  | true  | 'fail'
          1  | true   | false | 'success'
          1  | true   | true  | 'fail'
        end

        with_them do
          before do
            create(:approval_project_rule, project: project, approvals_required: approvals_required)
          end

          it do
            expect(project).to receive(:merge_requests_author_approval?).and_return(merge_requests_author_approval)
            expect(project).to receive(:merge_requests_disable_committers_approval?)
              .and_return(prevent_approval_by_committer)

            response = service.execute

            expect(response.status).to eq(:success)
            expect(project.compliance_standards_adherence.last)
              .to have_attributes(
                project_id: project.id,
                namespace_id: project.namespace_id,
                status: status,
                check_name: 'at_least_one_non_author_approval',
                standard: 'soc2'
              )
          end
        end
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        it 'retries in case of race conditions' do
          record_invalid_error = ActiveRecord::RecordInvalid.new(
            create(:compliance_standards_adherence).tap do |project_adherence|
              project_adherence.errors.add(:project, :taken,
                message: "already has this check defined for this standard")
            end
          )

          expect_next_instance_of(::Projects::ComplianceStandards::Adherence) do |project_adherence|
            expect(project_adherence).to receive(:update!).and_raise(record_invalid_error)
          end

          allow_next_instance_of(::Projects::ComplianceStandards::Adherence) do |project_adherence|
            allow(project_adherence).to receive(:update!).and_call_original
          end

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'at_least_one_non_author_approval',
              standard: 'soc2'
            )
        end

        it 'does not retry for other scenarios' do
          record_invalid_error = ActiveRecord::RecordInvalid.new(
            create(:compliance_standards_adherence).tap { |adherence| adherence.errors.add(:standard, :blank) }
          )

          expect_next_instance_of(::Projects::ComplianceStandards::Adherence) do |project_adherence|
            expect(project_adherence).to receive(:update!).and_raise(record_invalid_error)
          end

          response = service.execute

          expect(response.status).to eq(:error)
          expect(response.message).to eq("Standard can't be blank")
        end
      end

      context 'when track progress param is set' do
        let(:params) { { 'track_progress' => true } }

        it 'updates progress via StandardsAdherenceChecksTracker' do
          expect_next_instance_of(::ComplianceManagement::StandardsAdherenceChecksTracker,
            project.root_namespace.id) do |tracker|
            expect(tracker).to receive(:update_progress).and_call_original
          end

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'at_least_one_non_author_approval',
              standard: 'soc2'
            )
        end
      end

      context 'when track progress param is not set' do
        let(:params) { { 'track_progress' => false } }

        it 'does not update progress via StandardsAdherenceChecksTracker' do
          expect(::ComplianceManagement::StandardsAdherenceChecksTracker).not_to receive(:new)

          response = service.execute

          expect(response.status).to eq(:success)
          expect(project.compliance_standards_adherence.last)
            .to have_attributes(
              project_id: project.id,
              namespace_id: project.namespace_id,
              status: 'fail',
              check_name: 'at_least_one_non_author_approval',
              standard: 'soc2'
            )
        end
      end
    end
  end
end
