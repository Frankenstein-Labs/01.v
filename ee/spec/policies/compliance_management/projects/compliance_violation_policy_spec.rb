# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::ComplianceManagement::Projects::ComplianceViolationPolicy, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }

  let_it_be(:violation) do
    create(:project_compliance_violation, namespace: group, project: project,
      audit_event_id: audit_event.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: control,
      status: 0
    )
  end

  subject(:policy) { described_class.new(user, violation) }

  context 'when user does have access to group' do
    before_all do
      group.add_owner(user)
    end

    context 'when group is licensed' do
      before do
        stub_licensed_features(
          group_level_compliance_violations_report: true
        )
      end

      it { is_expected.to be_allowed(:read_compliance_violations_report) }
      it { is_expected.to be_allowed(:update_compliance_violations_report) }
      it { is_expected.to be_allowed(:create_note) }
    end

    context 'when group is not licensed' do
      before do
        stub_licensed_features(
          group_level_compliance_violations_report: false
        )
      end

      it { is_expected.not_to be_allowed(:read_compliance_violations_report) }
      it { is_expected.not_to be_allowed(:update_compliance_violations_report) }
      it { is_expected.not_to be_allowed(:create_note) }
    end
  end

  shared_examples 'project compliance violations access' do
    context 'when project is licensed' do
      before do
        stub_licensed_features(project_level_compliance_violations_report: true)
      end

      it { is_expected.to be_allowed(:read_compliance_violations_report) }
      it { is_expected.to be_allowed(:update_compliance_violations_report) }
      it { is_expected.to be_allowed(:create_note) }
    end

    context 'when project is not licensed' do
      before do
        stub_licensed_features(project_level_compliance_violations_report: false)
      end

      it { is_expected.not_to be_allowed(:read_compliance_violations_report) }
      it { is_expected.not_to be_allowed(:update_compliance_violations_report) }
      it { is_expected.not_to be_allowed(:create_note) }
    end
  end

  context 'when user does have access to project' do
    before_all do
      project.add_owner(user)
    end

    it_behaves_like 'project compliance violations access'
  end

  context 'when user is a security manager of the project' do
    before_all do
      project.add_security_manager(user)
    end

    it_behaves_like 'project compliance violations access'
  end

  context 'when user is an auditor' do
    let_it_be(:auditor_user) { create(:user, :auditor) }

    subject(:policy) { described_class.new(auditor_user, violation) }

    context 'when project is licensed' do
      before do
        stub_licensed_features(project_level_compliance_violations_report: true)
      end

      it { is_expected.to be_allowed(:read_compliance_violations_report) }
      it { is_expected.not_to be_allowed(:update_compliance_violations_report) }
      it { is_expected.not_to be_allowed(:create_note) }
    end
  end
end
