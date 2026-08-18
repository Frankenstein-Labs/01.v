# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::LimitedDataService, feature_category: :groups_and_projects do
  let(:group) { create(:group) }
  let(:owner_member) { create(:group_member, :owner, group: group) }
  let(:current_user) { owner_member.user }
  let(:service) { described_class.new(container: group, current_user: current_user) }

  shared_examples 'not available' do
    it 'returns a failed response' do
      response = service.execute

      expect(response.success?).to be false
      expect(response.message).to eq('Not available')
    end
  end

  describe '#execute' do
    context 'when unlicensed' do
      before do
        stub_licensed_features(export_user_permissions: false)
      end

      it_behaves_like 'not available'
    end

    context 'when licensed' do
      before do
        stub_licensed_features(export_user_permissions: true)
        group.add_member(current_user, Gitlab::Access::OWNER)
      end

      it 'is successful' do
        response = service.execute

        expect(response.success?).to be true
      end

      context 'when current_user is not a member of this group' do
        let(:service) { described_class.new(container: group, current_user: create(:user)) }

        it_behaves_like 'not available'
      end

      context 'when current_user is a group developer' do
        let(:current_user) { create(:user) }

        before do
          group.add_developer(current_user)
        end

        it_behaves_like 'not available'
      end

      context 'when current_user is a group maintainer' do
        let(:current_user) { create(:user) }

        before do
          group.add_maintainer(current_user)
        end

        it_behaves_like 'not available'
      end

      context 'when current_user is a guest' do
        let(:current_user) { create(:user) }

        before do
          group.add_guest(current_user)
        end

        it_behaves_like 'not available'
      end

      context 'when current user is a group owner' do
        let(:expiry_date) { Date.today + 1.month }
        let(:csv) { CSV.parse(service.execute.payload, headers: true) }

        before do
          create_list(:group_member, 4, group: group)
          create(:group_member, group: group,
            created_at: '2021-02-01', expires_at: expiry_date,
            user: create(:user, username: 'mwoolf', name: 'Max Woolf'))
          create(:group_member, :invited, group: group)
          create(:group_member, :ldap, group: group)
          create(:group_member, :blocked, group: group)
          create(:group_member, :minimal_access, group: group)
        end

        it 'has the correct headers' do
          expect(csv.headers).to contain_exactly(
            'Username', 'Name', 'Access granted', 'Access expires', 'Max role', 'Source'
          )
        end

        it 'has the correct number of rows' do
          expect(csv.size).to eq(9)
        end

        describe 'checking data' do
          # `freeze: false` is required in this spec: one or more `let_it_be` subjects
          # cannot be frozen by default (deep_freeze traversal failure, a non-AR
          # subject, or an in-memory mutation that survives reload/refind). Do not
          # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
          # (see gitlab-org/gitlab#602925).
          let_it_be(:group, freeze: false) { create(:group) }
          let_it_be(:sub_group) { create(:group, parent: group) }
          let_it_be(:descendant_group) { create(:group, parent: sub_group) }

          let_it_be(:direct_user) { create(:user, username: 'Alice', name: 'Alice') }
          let_it_be(:inherited_user) { create(:user, username: 'Bob', name: 'Bob') }
          let_it_be(:descendant_user) { create(:user, username: 'John', name: 'John') }

          let_it_be(:member_role) { create(:member_role, :developer, name: 'Incident Manager') }

          # `freeze: false` is required in this spec: one or more `let_it_be` subjects
          # cannot be frozen by default (deep_freeze traversal failure, a non-AR
          # subject, or an in-memory mutation that survives reload/refind). Do not
          # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
          # (see gitlab-org/gitlab#602925).
          let_it_be(:subgroup_service, freeze: false) do
            described_class.new(container: sub_group, current_user: direct_user)
          end

          before_all do
            create(:group_member, :owner, group: group, user: direct_user)
            create(:group_member, :developer, group: sub_group, user: inherited_user)
            create(:group_member,
              :developer, group: descendant_group, user: descendant_user, member_role: member_role)
          end

          subject(:csv) { CSV.parse(subgroup_service.execute.payload, headers: true) }

          it 'has correct data for direct member', :aggregate_failures do
            row = csv.find { |row| row['Username'] == 'Alice' }

            expect(row[0]).to eq('Alice')
            expect(row[1]).to eq('Alice')
            expect(row[4]).to eq('Owner')
            expect(row[5]).to eq('Inherited member')
          end

          it 'has correct data for inherited member', :aggregate_failures do
            row = csv.find { |row| row['Username'] == 'Bob' }

            expect(row[0]).to eq('Bob')
            expect(row[1]).to eq('Bob')
            expect(row[4]).to eq('Developer')
            expect(row[5]).to eq('Direct member')
          end

          it 'has correct data for descendant member', :aggregate_failures do
            row = csv.find { |row| row['Username'] == 'John' }

            expect(row[0]).to eq('John')
            expect(row[1]).to eq('John')
            expect(row[4]).to eq('Incident Manager (Custom role)')
            expect(row[5]).to eq('Descendant member')
          end
        end
      end
    end
  end
end
