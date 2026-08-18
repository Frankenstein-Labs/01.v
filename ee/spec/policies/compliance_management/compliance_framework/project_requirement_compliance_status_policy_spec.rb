# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatusPolicy,
  feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:requirement_status) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement, project: project)
  end

  subject(:policy) { described_class.new(user, requirement_status) }

  before do
    stub_licensed_features(
      group_level_compliance_adherence_report: true,
      project_level_compliance_adherence_report: true
    )
  end

  context 'when user does have access to group' do
    before_all do
      group.add_owner(user)
    end

    it { is_expected.to be_allowed(:read_compliance_adherence_report) }
  end

  context 'when user is a security manager' do
    before_all do
      group.add_security_manager(user)
    end

    it { is_expected.to be_allowed(:read_compliance_adherence_report) }
  end
end
