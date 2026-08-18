# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Projects::ComplianceStandards::AdherencePolicy, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:adherence) { create(:compliance_standards_adherence, project: project) }

  subject(:policy) { described_class.new(user, adherence) }

  before do
    stub_licensed_features(
      group_level_compliance_adherence_report: true,
      project_level_compliance_adherence_report: true
    )
  end

  context 'when user does not have owner access to group' do
    context 'when user does not have access to the project directly' do
      it { is_expected.to be_disallowed(:read_compliance_adherence_report) }
    end

    context 'when user has access to the project directly' do
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
  end

  context 'when user does have access to group' do
    before_all do
      group.add_owner(user)
    end

    it { is_expected.to be_allowed(:read_compliance_adherence_report) }
  end
end
