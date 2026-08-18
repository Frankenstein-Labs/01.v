# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AllBranchesRulePolicy, feature_category: :source_code_management do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project) }

  let(:branch_rule) { Projects::AllBranchesRule.new(project) }

  subject { described_class.new(user, branch_rule) }

  context 'as a maintainer' do
    before_all do
      project.add_maintainer(user)
    end

    it_behaves_like 'allows branch rule crud'
  end

  context 'as a developer' do
    before_all do
      project.add_developer(user)
    end

    it_behaves_like 'disallows branch rule crud'
  end

  context 'as a guest' do
    before_all do
      project.add_guest(user)
    end

    it_behaves_like 'disallows branch rule crud'
  end

  context 'as a guest with admin_protected_branch custom role' do
    let_it_be(:group, freeze: false) { create(:group) }
    let_it_be(:project, freeze: false) { create(:project, group: group) }
    let_it_be(:project_member, freeze: false) { create(:project_member, :guest, user: user, project: project) }

    let(:branch_rule) { Projects::AllBranchesRule.new(project) }

    before do
      stub_licensed_features(custom_roles: true)
      create(:member_role, :guest, admin_protected_branch: true, namespace: group, members: [project_member])
    end

    it { expect_disallowed(:read_branch_rule) }
  end
end
