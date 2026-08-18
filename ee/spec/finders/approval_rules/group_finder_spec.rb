# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::GroupFinder, feature_category: :source_code_management do
  let_it_be_with_reload(:rule) { create(:approval_project_rule) }
  let_it_be(:user) { create(:user) }
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:public_group) { create(:group, name: 'public_group', organization: organization) }
  let_it_be(:private_inaccessible_group) do
    create(:group, :private, name: 'private_inaccessible_group', organization: organization)
  end

  let_it_be(:private_accessible_group) do
    create(:group, :private, name: 'private_accessible_group', owners: user, organization: organization)
  end

  let_it_be(:private_accessible_subgroup) do
    create(:group, :private, parent: private_accessible_group, name: 'private_accessible_subgroup',
      organization: organization)
  end

  let_it_be(:private_shared_group) do
    create(:group, :private, name: 'private_shared_group', organization: organization)
  end

  let_it_be(:private_shared_group_link) do
    create(:project_group_link, project: rule.project, group: private_shared_group)
  end

  let_it_be(:public_shared_group) { create(:group, name: 'public_shared_group', organization: organization) }
  let_it_be(:public_shared_group_link) do
    create(:project_group_link, project: rule.project, group: public_shared_group)
  end

  subject(:finder) { described_class.new(rule, user) }

  context 'when with inaccessible groups' do
    before do
      rule.groups = [public_group, private_inaccessible_group, private_accessible_group, private_accessible_subgroup,
        private_shared_group]
    end

    it 'returns groups' do
      expect(finder.visible_groups).to contain_exactly(
        public_group, private_accessible_group, private_accessible_subgroup
      )
      expect(finder.hidden_groups).to contain_exactly(private_inaccessible_group, private_shared_group)
      expect(finder.contains_hidden_groups?).to be(true)
    end

    context 'when user is a member of the project' do
      let_it_be(:project_user) { create(:user, organization: organization) }

      before_all do
        rule.project.add_developer(project_user)
        private_accessible_group.add_developer(project_user)
      end

      describe '#hidden_groups' do
        subject(:hidden_groups) { described_class.new(rule, project_user).hidden_groups }

        it 'returns rule groups that the user cannot access except shared groups' do
          expect(hidden_groups).to contain_exactly(private_inaccessible_group)
        end

        context 'when the show_private_groups_as_approvers flag is disabled' do
          before do
            stub_feature_flags(show_private_groups_as_approvers: false)
          end

          it 'returns rule groups that the user cannot access' do
            expect(hidden_groups).to contain_exactly(private_inaccessible_group, private_shared_group)
          end
        end
      end
    end

    context 'when user is an admin', :enable_admin_mode do
      subject(:finder) { described_class.new(rule, create(:admin)) }

      it 'returns groups' do
        expect(finder.visible_groups).to contain_exactly(
          public_group,
          private_accessible_group,
          private_accessible_subgroup,
          private_inaccessible_group,
          private_shared_group
        )
        expect(finder.hidden_groups).to be_empty
        expect(finder.contains_hidden_groups?).to be(false)
      end
    end

    context 'when user is not authorized' do
      subject(:finder) { described_class.new(rule, nil) }

      it 'returns only public groups' do
        expect(finder.visible_groups).to contain_exactly(
          public_group
        )
        expect(finder.hidden_groups).to contain_exactly(
          private_accessible_group, private_accessible_subgroup, private_inaccessible_group, private_shared_group
        )
        expect(finder.contains_hidden_groups?).to be(true)
      end
    end

    context 'when avoiding N+1 queries', :request_store do
      it 'avoids N+1 database queries' do
        rule.reload

        control = ActiveRecord::QueryRecorder.new { finder.visible_groups }

        # Clear cached association and request cache
        rule.reload
        RequestStore.clear!

        rule.groups << create(
          :group,
          :private,
          parent: private_accessible_group,
          name: 'private_accessible_subgroup2',
          organization: organization
        )

        expect { described_class.new(rule, user).visible_groups }.not_to exceed_query_limit(control)
      end
    end
  end

  context 'when without inaccessible groups' do
    before do
      rule.groups = [public_group, private_accessible_group, private_accessible_subgroup]
    end

    it 'returns groups' do
      expect(finder.visible_groups).to contain_exactly(
        public_group, private_accessible_group, private_accessible_subgroup
      )
      expect(finder.hidden_groups).to be_empty
      expect(finder.contains_hidden_groups?).to be(false)
    end
  end
end
