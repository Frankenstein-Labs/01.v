# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatTypeCalculator,
  feature_category: :seat_cost_management do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:root_namespace) { create(:group) }

    subject(:seat_type) { described_class.execute(user, root_namespace) }

    context 'when on saas', :saas do
      context 'with a namespace on a free plan' do
        before do
          create(:gitlab_subscription, :free, namespace: root_namespace)
        end

        context 'when an active user has a group membership' do
          before do
            create(:group_member, group: root_namespace, user: user, access_level: highest_access_level)
          end

          where(:highest_access_level, :expected_seat_type) do
            ::Gitlab::Access::GUEST      | :base
            ::Gitlab::Access::PLANNER    | :base
            ::Gitlab::Access::REPORTER   | :base
            ::Gitlab::Access::DEVELOPER  | :base
            ::Gitlab::Access::MAINTAINER | :base
            ::Gitlab::Access::OWNER      | :base
          end

          with_them do
            it 'returns the expected seat type' do
              expect(seat_type).to eq(expected_seat_type)
            end
          end
        end

        context 'when a user has subgroup memberships' do
          let(:subgroup) { create(:group, parent: root_namespace) }

          before do
            create(:group_member, group: root_namespace, user: user, access_level: ::Gitlab::Access::GUEST)
            create(:group_member, group: subgroup, user: user, access_level: ::Gitlab::Access::MAINTAINER)
          end

          it 'returns the seat type for the highest access level in the hierarchy' do
            expect(seat_type).to eq(:base)
          end
        end
      end

      context 'with a namespace on a premium plan' do
        before do
          create(:gitlab_subscription, :premium, namespace: root_namespace)
        end

        context 'when an active user has a group membership' do
          before do
            create(:group_member, group: root_namespace, user: user, access_level: highest_access_level)
          end

          where(:highest_access_level, :expected_seat_type) do
            ::Gitlab::Access::GUEST      | :base
            ::Gitlab::Access::PLANNER    | :base
            ::Gitlab::Access::REPORTER   | :base
            ::Gitlab::Access::DEVELOPER  | :base
            ::Gitlab::Access::MAINTAINER | :base
            ::Gitlab::Access::OWNER      | :base
          end

          with_them do
            it 'returns the expected seat type' do
              expect(seat_type).to eq(expected_seat_type)
            end
          end
        end

        context 'when a user has subgroup memberships' do
          let(:subgroup) { create(:group, parent: root_namespace) }

          before do
            create(:group_member, :minimal_access, group: root_namespace, user: user)
            create(:group_member, group: subgroup, user: user, access_level: ::Gitlab::Access::MAINTAINER)
          end

          it 'returns the seat type for the highest access level in the hierarchy' do
            expect(seat_type).to eq(:base)
          end
        end

        context "when a user's max role is minimal access" do
          let(:user) { create(:user) }

          before do
            create(:group_member, :minimal_access, group: root_namespace, user: user)
          end

          it 'returns free seat type' do
            expect(seat_type).to eq(:free)
          end
        end

        context 'when the namespace is downgraded from Ultimate tier' do
          context 'with a membership that retained a pre-existing custom role association' do
            # After the downgrade, members retain their member_role_id but custom permissions are ignored
            let(:billable_role) { create(:member_role, :minimal_access, :read_runners, namespace: root_namespace) }

            before do
              create(:group_member, :minimal_access, group: root_namespace, user: user, member_role: billable_role)
            end

            it 'ignores the custom role and returns the seat type based on the highest access level' do
              expect(seat_type).to eq(:free)
            end
          end
        end
      end

      context 'with a namespace on an ultimate plan' do
        before_all do
          create(:gitlab_subscription, :ultimate, namespace: root_namespace)
        end

        context 'when an active user has a group membership' do
          before do
            create(:group_member, group: root_namespace, user: user, access_level: highest_access_level)
          end

          where(:highest_access_level, :expected_seat_type) do
            ::Gitlab::Access::GUEST      | :free
            ::Gitlab::Access::PLANNER    | :plan
            ::Gitlab::Access::REPORTER   | :base
            ::Gitlab::Access::DEVELOPER  | :base
            ::Gitlab::Access::MAINTAINER | :base
            ::Gitlab::Access::OWNER      | :base
          end

          with_them do
            it 'returns the expected seat type' do
              expect(seat_type).to eq(expected_seat_type)
            end
          end
        end

        context 'when a user has subgroup memberships' do
          let(:subgroup) { create(:group, parent: root_namespace) }

          before do
            create(:group_member, group: root_namespace, user: user, access_level: ::Gitlab::Access::GUEST)
            create(:group_member, group: subgroup, user: user, access_level: ::Gitlab::Access::MAINTAINER)
          end

          it 'returns the seat type for the highest access level in the hierarchy' do
            expect(seat_type).to eq(:base)
          end
        end

        context "when a user's max role is minimal access" do
          let(:user) { create(:user) }

          before do
            create(:group_member, :minimal_access, group: root_namespace, user: user)
          end

          it 'returns free seat type' do
            expect(seat_type).to eq(:free)
          end
        end

        context 'when a user has a custom role membership' do
          before do
            create(:group_member, base_role, group: root_namespace, user: user, member_role: custom_role)
          end

          context 'with a permission that does not consume a seat' do
            where(:base_role) do
              [
                :minimal_access,
                :guest
              ]
            end

            with_them do
              let(:custom_role) { create(:member_role, base_role, :read_code, namespace: root_namespace) }

              it 'returns free seat type' do
                expect(seat_type).to eq(:free)
              end
            end
          end

          context 'with a permission that consumes a seat' do
            where(:base_role) do
              [
                :minimal_access,
                :guest,
                :planner,
                :reporter,
                :developer,
                :maintainer
              ]
            end

            with_them do
              let(:custom_role) { create(:member_role, base_role, :read_runners, namespace: root_namespace) }

              it 'returns base seat type' do
                expect(seat_type).to eq(:base)
              end
            end
          end
        end

        context 'when the user has standard and custom role memberships' do
          let(:sub_group) { create(:group, parent: root_namespace) }

          context 'with non-billable standard role and billable custom role memberships' do
            let(:billable_role) { create(:member_role, :minimal_access, :read_runners, namespace: root_namespace) }

            before do
              create(:group_member, :minimal_access, group: root_namespace, user: user, member_role: billable_role)
              create(:group_member, :guest, group: sub_group, user: user)
            end

            it 'returns the seat type for the custom role' do
              expect(seat_type).to eq(:base)
            end
          end

          context 'with billable standard role and non-billable custom role memberships' do
            let(:non_billable_role) { create(:member_role, :guest, :read_code, namespace: root_namespace) }

            before do
              create(:group_member, :guest, group: root_namespace, user: user, member_role: non_billable_role)
              create(:group_member, :planner, group: sub_group, user: user)
            end

            it 'returns the seat type for the highest access level' do
              expect(seat_type).to eq(:plan)
            end
          end

          context 'with non-billable standard role and custom role memberships' do
            let(:non_billable_role) { create(:member_role, :guest, :read_code, namespace: root_namespace) }

            before do
              create(:group_member, :guest, group: root_namespace, user: user, member_role: non_billable_role)
              create(:group_member, :guest, group: sub_group, user: user)
            end

            it 'returns free seat type' do
              expect(seat_type).to eq(:free)
            end
          end
        end
      end

      context 'with a bot user' do
        let_it_be(:user) { create(:user, :bot) }

        before_all do
          create(:group_member, group: root_namespace, user: user)
        end

        it 'returns system seat type' do
          expect(seat_type).to eq(:system)
        end
      end

      context 'with user ID' do
        subject(:seat_type) { described_class.execute(user.id, root_namespace) }

        before_all do
          create(:group_member, group: root_namespace, user: user)
        end

        it 'returns base seat type' do
          expect(seat_type).to eq(:base)
        end
      end

      context 'when the user has no memberships' do
        it 'returns nil' do
          expect(seat_type).to be_nil
        end
      end
    end

    context 'when on Self-Managed' do
      it 'returns nil' do
        expect(seat_type).to be_nil
      end
    end
  end

  describe '#bulk_execute' do
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }
    let_it_be(:root_namespace) { create(:group) }

    subject(:seat_types) { described_class.bulk_execute([user1, user2], root_namespace) }

    context 'when on Self-Managed' do
      it 'returns an empty hash' do
        expect(seat_types).to eq({})
      end
    end

    context 'when on saas', :saas do
      before do
        create(:gitlab_subscription, :ultimate, namespace: root_namespace)
      end

      context 'with memberships' do
        before_all do
          root_namespace.add_guest(user1)
          root_namespace.add_developer(user2)
        end

        it 'returns seat types for multiple users' do
          expect(seat_types).to eq({ user1.id => :free, user2.id => :base })
        end

        context 'with active record scope' do
          subject(:seat_types) { described_class.bulk_execute(User.all, root_namespace) }

          it 'returns seat types for multiple users' do
            expect(seat_types).to eq({ user1.id => :free, user2.id => :base })
          end
        end

        context 'with user IDs' do
          subject(:seat_types) { described_class.bulk_execute([user1.id, user2.id], root_namespace) }

          it 'returns seat types for multiple users' do
            expect(seat_types).to eq({ user1.id => :free, user2.id => :base })
          end
        end
      end

      context 'with memberships in other groups' do
        subject(:seat_types) { described_class.bulk_execute([user1], root_namespace) }

        before_all do
          root_namespace.add_guest(user1)

          group = create(:group)
          group.add_maintainer(user1)
        end

        it 'only considers specified namespace' do
          expect(seat_types).to eq({ user1.id => :free })
        end
      end

      context 'without memberships' do
        it 'returns nil seat types' do
          expect(seat_types).to eq({ user1.id => nil, user2.id => nil })
        end
      end

      context 'with array with mixed values' do
        subject(:seat_types) { described_class.bulk_execute([user1, nil, user2], root_namespace) }

        it 'filters out nil values' do
          expect(seat_types).to eq({ user1.id => nil, user2.id => nil })
        end
      end

      context 'with custom role memberships' do
        let(:sub_group) { create(:group, parent: root_namespace) }
        let(:billable_role) { create(:member_role, :guest, :read_runners, namespace: root_namespace) }
        let(:non_billable_role) { create(:member_role, :guest, :read_code, namespace: root_namespace) }

        before do
          create(:group_member, :guest, group: root_namespace, user: user1)
          create(:group_member, :guest, group: sub_group, user: user1, member_role: billable_role)
          create(:group_member, :minimal_access, group: root_namespace, user: user2)
          create(:group_member, :guest, group: sub_group, user: user2, member_role: non_billable_role)
        end

        it 'returns seat types for multiple users' do
          expect(seat_types).to eq({ user1.id => :base, user2.id => :free })
        end
      end
    end
  end
end
