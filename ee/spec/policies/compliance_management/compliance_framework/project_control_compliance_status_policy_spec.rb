# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatusPolicy,
  feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: subgroup) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:control_status) do
    create(:project_control_compliance_status, compliance_requirement: requirement, project: project,
      compliance_requirements_control: control)
  end

  subject(:policy) { described_class.new(user, control_status) }

  before do
    stub_licensed_features(
      group_level_compliance_adherence_report: true,
      project_level_compliance_adherence_report: true
    )
  end

  context 'when user is owner of top level group' do
    before_all do
      group.add_owner(user)
    end

    it { is_expected.to be_allowed(:read_compliance_adherence_report) }
  end

  context 'when user is owner of group of project' do
    before_all do
      subgroup.add_owner(user)
    end

    it { is_expected.to be_allowed(:read_compliance_adherence_report) }
  end

  context 'when user is owner of project' do
    before_all do
      project.add_owner(user)
    end

    it { is_expected.to be_allowed(:read_compliance_adherence_report) }
  end

  context 'when user is a security manager of the project' do
    before_all do
      project.add_security_manager(user)
    end

    it { is_expected.to be_allowed(:read_compliance_adherence_report) }
  end

  context 'when user is not owner of project' do
    it { is_expected.to be_disallowed(:read_compliance_adherence_report) }
  end
end
