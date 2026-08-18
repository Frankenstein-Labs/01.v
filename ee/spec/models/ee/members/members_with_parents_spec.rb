# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::MembersWithParents, feature_category: :groups_and_projects do
  describe '#members' do
    let_it_be(:group) { create(:group) }
    let_it_be(:maintainer) { group.add_maintainer(create(:user)) }
    let_it_be(:developer) { group.add_developer(create(:user)) }
    let_it_be(:pending_maintainer) { create(:group_member, :awaiting, :maintainer, group: group) }
    let_it_be(:pending_developer) { create(:group_member, :awaiting, :developer, group: group) }
    let_it_be(:invited_member) { create(:group_member, :invited, group: group) }
    let_it_be(:inactive_developer) { group.add_developer(create(:user, :deactivated)) }
    let_it_be(:minimal_access) { create(:group_member, :minimal_access, group: group) }

    let(:arguments) { {} }

    subject(:members) { described_class.new(group).members(**arguments) }

    before do
      stub_licensed_features(minimal_access_role: true)
      group.minimal_access_role_allowed?
    end

    using Rspec::Parameterized::TableSyntax

    where(:arguments, :expected_members) do
      [
        [
          {},
          lazy { [developer, maintainer, inactive_developer] }
        ],
        [
          { minimal_access: true },
          lazy do
            [
              developer, maintainer, inactive_developer, minimal_access
            ]
          end
        ],
        [
          { active_users: true },
          lazy { [developer, maintainer] }
        ]
      ]
    end

    with_them do
      it 'returns expected members' do
        expect(members).to contain_exactly(*expected_members)
        expect(members).not_to include(*(group.members - expected_members))
      end
    end
  end
end
