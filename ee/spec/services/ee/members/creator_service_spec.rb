# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::CreatorService, feature_category: :groups_and_projects do
  describe '.add_member' do
    let_it_be_with_reload(:user) { create(:user) }

    context 'when user is a security_policy_bot' do
      let_it_be(:user) { create(:user, :security_policy_bot) }
      let_it_be(:project) { create(:project) }

      subject { described_class.add_member(project, user, :guest) }

      it 'adds a member' do
        expect { subject }.to change { Member.count }.by(1)
      end

      context 'when the user is already a member of another project' do
        let_it_be(:other_project) { create(:project) }
        let_it_be(:membership) { create(:project_member, :guest, source: other_project, user: user) }

        it 'does not add a member' do
          expect { subject }.not_to change { Member.count }
        end

        it 'adds an error message to the member' do
          expect(subject.errors.messages).to include(
            base: ['security policy bot users cannot be added to other projects']
          )
        end
      end
    end

    context 'when assigning a member role' do
      let_it_be(:group) { create(:group) }
      let_it_be(:member_role) { create(:member_role, :guest, namespace: group) }

      subject(:add_member) do
        described_class.add_member(group, user, :guest, member_role_id: member_role.id)
      end

      context 'with custom_roles feature' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'adds a user to members with custom role assigned' do
          expect { add_member }.to change { group.members.count }.by(1)

          member = Member.last

          expect(member.member_role).to eq(member_role)
          expect(member.access_level).to eq(Member::GUEST)
        end
      end

      context 'without custom_roles feature' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'adds a user to members without custom role assigned' do
          expect { add_member }.to change { group.members.count }.by(1)

          member = Member.last

          expect(member.member_role).to be_nil
          expect(member.access_level).to eq(Member::GUEST)
        end
      end
    end

    context 'when inviting or promoting a member to a billable role' do
      let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
      let(:access_level) { :developer }
      let(:source) { create(:group) }
      let(:actor) { nil }

      before do
        stub_application_setting(enable_member_promotion_management: true)
        allow(License).to receive(:current).and_return(license)
      end

      subject(:add_member) do
        described_class.add_member(source, user, access_level, current_user: actor)
      end

      context 'with no actor' do
        it 'adds the member' do
          expect { add_member }.to change { Member.count }.by(1)
        end
      end
    end
  end
end
