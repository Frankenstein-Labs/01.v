# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranchPolicy, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }

  subject { described_class.new(user, protected_branch) }

  context 'when the protected branch belongs to a project' do
    let_it_be_with_reload(:protected_branch) { create(:protected_branch, name: 'feature') }
    let_it_be(:project) { protected_branch.project }
    let_it_be(:allowed_group) { create(:group) }

    before_all do
      project.add_maintainer(user)
      project.project_group_links.create!(group: allowed_group)
    end

    context 'and an unprotect access level for a group is configured' do
      before_all do
        protected_branch.unprotect_access_levels.create!(group: allowed_group)
      end

      context 'but unprotection restriction feature is unlicensed' do
        it_behaves_like 'allows protected branch crud'
      end

      context 'and unprotection restriction feature is licensed' do
        before do
          stub_licensed_features(unprotection_restrictions: true)
        end

        it_behaves_like 'disallows protected branch changes'

        context 'and the user is a developer of the group' do
          before_all do
            allowed_group.add_developer(user)
          end

          it_behaves_like 'allows protected branch crud'
        end
      end
    end
  end

  context 'when the protected branch belongs to a group' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:protected_branch) do
      create(:protected_branch, name: 'feature', project: nil, group: group)
    end

    context 'as a maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'allows protected branch crud'
    end

    context 'as a developer' do
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_developer(user)
      end

      it_behaves_like 'disallows protected branch crud'
    end

    context 'as a guest' do
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_guest(user)
      end

      it_behaves_like 'disallows protected branch crud'
    end
  end
end
