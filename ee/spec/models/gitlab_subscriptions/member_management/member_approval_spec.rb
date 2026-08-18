# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::MemberApproval, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  describe 'associations' do
    it { is_expected.to belong_to(:member) }
    it { is_expected.to belong_to(:member_namespace) }
    it { is_expected.to belong_to(:member_role).optional }
    it { is_expected.to belong_to(:reviewed_by) }
    it { is_expected.to belong_to(:requested_by) }
    it { is_expected.to belong_to(:user) }
  end

  describe '.create_or_update_approval' do
    let_it_be(:requested_user) { create(:user) }
    let_it_be(:member_role) { create(:member_role, :non_billable) }
    let(:attributes) do
      {
        new_access_level: Gitlab::Access::MAINTAINER,
        requested_by: requested_user,
        member_role_id: member_role.id,
        old_access_level: Gitlab::Access::GUEST
      }
    end

    subject(:create_or_update_pending_approval) do
      described_class.create_or_update_pending_approval(user, group, attributes)
    end

    context 'when pending record does not exists' do
      it 'creates a new record' do
        approval = nil
        expect do
          approval = create_or_update_pending_approval
        end.to change { described_class.count }.by(1)

        expect(described_class.last).to eq(approval)
        expect(described_class.last).to be_pending
        expect(described_class.last.requested_by).to eq(requested_user)
        expect(described_class.last.new_access_level).to eq(Gitlab::Access::MAINTAINER)
        expect(described_class.last.old_access_level).to eq(Gitlab::Access::GUEST)
        expect(described_class.last.member_role_id).to eq(member_role.id)
      end
    end

    context 'when pending record exists' do
      let!(:member_approval) do
        create(:gitlab_subscription_member_management_member_approval, user: user, member_namespace: group,
          status: :pending)
      end

      shared_examples 'pending record was updated' do
        it 'updates the record with passed fields' do
          approval = nil
          expect(described_class.last.new_access_level).to eq(Gitlab::Access::DEVELOPER)

          expect do
            approval = create_or_update_pending_approval
          end.not_to change { described_class.count }

          expect(described_class.last).to eq(approval)
          expect(described_class.last).to be_pending
          expect(described_class.last.requested_by).to eq(requested_user)
          expect(described_class.last.new_access_level).to eq(Gitlab::Access::MAINTAINER)
          expect(described_class.last.old_access_level).to eq(Gitlab::Access::GUEST)
          expect(described_class.last.member_role_id).to eq(member_role.id)
        end
      end

      it_behaves_like 'pending record was updated'

      context 'when status is passed in attribute' do
        before do
          attributes.merge!(status: :denied)
        end

        it_behaves_like 'pending record was updated'
      end

      context 'when RecordNotUnique error is raised' do
        it 'retries and raises if not successful' do
          allow(described_class).to receive(:find_or_initialize_by).and_return(member_approval)
          allow(member_approval).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
          expect(member_approval).to receive(:save!).exactly(3).times

          expect do
            create_or_update_pending_approval
          end.to raise_error(ActiveRecord::RecordNotUnique)
        end
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:new_access_level) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:member_namespace) }

    context 'with metadata' do
      subject { build(:gitlab_subscription_member_management_member_approval, metadata: attribute_mapping) }

      context 'with valid JSON schemas' do
        let(:attribute_mapping) do
          {
            expires_at: expiry,
            member_role_id: nil
          }
        end

        context 'with empty metadata' do
          let(:attribute_mapping) { {} }

          it { is_expected.to be_valid }
        end

        context 'with date expiry' do
          let(:expiry) { "1970-01-01" }

          it { is_expected.to be_valid }
        end

        context 'with empty expiry' do
          let(:expiry) { "" }

          it { is_expected.to be_valid }
        end

        context 'with nil expiry' do
          let(:expiry) { nil }

          it { is_expected.to be_valid }
        end

        context 'with not null member_role_id' do
          let(:attribute_mapping) do
            {
              member_role_id: 3
            }
          end

          it { is_expected.to be_valid }
        end

        context 'when property has extra attributes' do
          let(:attribute_mapping) do
            { access_level: 20 }
          end

          it { is_expected.to be_valid }
        end
      end

      context 'with invalid JSON schemas' do
        shared_examples 'is invalid record' do
          it 'returns an error message' do
            expect(subject).to be_invalid
            expect(subject.errors.messages[:metadata]).to eq(['must be a valid json schema'])
          end
        end

        context 'when property is not an object' do
          let(:attribute_mapping) do
            "That is not a valid schema"
          end

          it_behaves_like 'is invalid record'
        end

        context 'with invalid expiry' do
          let(:attribute_mapping) do
            {
              expires_at: "1242"
            }
          end

          it_behaves_like 'is invalid record'
        end

        context 'with member_role_id' do
          let(:attribute_mapping) do
            {
              member_role_id: "some role"
            }
          end

          it_behaves_like 'is invalid record'
        end
      end
    end

    context 'when uniqness is enforced' do
      let!(:member_approval) do
        create(:gitlab_subscription_member_management_member_approval, user: user, member_namespace: group,
          status: :pending, member: nil)
      end

      context 'with same user, namespace' do
        let(:message) { 'A pending approval for the same user and namespace already exists.' }

        context 'when creating a new approval' do
          context 'with pending status' do
            let(:status) { :pending }

            it 'is not valid' do
              duplicate_approval = build(:gitlab_subscription_member_management_member_approval, user: user,
                member_namespace: group, status: status)

              expect(duplicate_approval).not_to be_valid
              expect(duplicate_approval.errors[:base]).to include(message)
            end
          end

          context 'with approved status' do
            let(:status) { :approved }

            it 'is valid' do
              duplicate_approval = build(:gitlab_subscription_member_management_member_approval, user: user,
                member_namespace: group, status: :approved)

              expect(duplicate_approval).to be_valid
            end
          end

          context 'with denied status' do
            let(:status) { :denied }

            it 'is valid' do
              duplicate_approval = build(:gitlab_subscription_member_management_member_approval, user: user,
                member_namespace: group, status: :denied)

              expect(duplicate_approval).to be_valid
            end
          end
        end

        context 'when updating existing approval' do
          context 'when updating member_role' do
            let(:member_role) { create(:member_role, :billable, :instance) }

            it 'updates member role' do
              member_approval.member_role_id = member_role.id

              expect(member_approval).to be_valid
            end
          end

          context 'when updating member_id' do
            let(:group_member) { create(:group_member, :guest, user: user, source: group) }

            it 'updates member_id' do
              member_approval.member = group_member

              expect(member_approval).to be_valid
            end
          end

          context 'when updating access_level' do
            it 'updates access_level' do
              member_approval.new_access_level = Gitlab::Access::MAINTAINER

              expect(member_approval).to be_valid
            end
          end

          context 'when updating status' do
            context 'when updating from pending to other' do
              it 'is allowed' do
                member_approval.status = :approved

                expect(member_approval).to be_valid
              end
            end

            context 'when updating from others to pending' do
              let!(:approved_member_approval) do
                build(:gitlab_subscription_member_management_member_approval, user: user, member_namespace: group,
                  status: :approved)
              end

              it 'is not allowed' do
                approved_member_approval.status = :pending

                expect(approved_member_approval).not_to be_valid
              end
            end
          end
        end
      end
    end
  end

  describe '#pending_member_approvals_with_max_new_access_level' do
    let_it_be(:project_member_pending_dev) do
      create(:gitlab_subscription_member_management_member_approval, :for_project_member)
    end

    let_it_be(:project_member_pending_maintainer) do
      create(:gitlab_subscription_member_management_member_approval, user: project_member_pending_dev.user,
        new_access_level: Gitlab::Access::MAINTAINER)
    end

    let_it_be(:group_member_pending_dev) do
      create(:gitlab_subscription_member_management_member_approval, :for_group_member)
    end

    let_it_be(:group_member_pending_owner) do
      create(:gitlab_subscription_member_management_member_approval,
        :for_group_member,
        user: group_member_pending_dev.user,
        new_access_level: Gitlab::Access::OWNER
      )
    end

    let_it_be(:denied_approval_dev) do
      create(:gitlab_subscription_member_management_member_approval, :for_group_member, status: :denied)
    end

    it 'returns records corresponding to pending users with max new_access_level' do
      expect(described_class.pending_member_approvals_with_max_new_access_level).to contain_exactly(
        project_member_pending_maintainer, group_member_pending_owner
      )
    end
  end

  describe '#pending_member_approvals_for_user' do
    let_it_be(:user) { create(:user) }
    let_it_be(:another_user) { create(:user) }

    let_it_be(:group_approval) do
      create(:gitlab_subscription_member_management_member_approval, :for_group_member, user: user)
    end

    let_it_be(:project_approval) do
      create(:gitlab_subscription_member_management_member_approval, :for_project_member, user: user)
    end

    before do
      create(:gitlab_subscription_member_management_member_approval, :for_group_member, user: user, status: :denied)
      create(:gitlab_subscription_member_management_member_approval, user: another_user, status: :pending)
    end

    it 'returns pending approvals for the given user' do
      approvals = described_class.pending_member_approvals_for_user(user.id)

      expect(approvals.count).to eq(2)
      expect(approvals.first.user).to eq(user)
      expect(approvals.first.status).to eq('pending')
    end

    it 'does not return non-pending approvals for the given user' do
      approvals = described_class.pending_member_approvals_for_user(user.id)

      expect(approvals.count).to eq(2)
      expect(approvals.map(&:status).uniq).to eq(['pending'])
    end

    it 'does not return approvals for other users' do
      approvals = described_class.pending_member_approvals_for_user(user.id)

      expect(approvals.map(&:user)).not_to include(another_user)
    end

    it 'orders the approvals by id in ascending order' do
      approvals = described_class.pending_member_approvals_for_user(user.id)

      expect(approvals.map(&:id)).to eq([group_approval.id, project_approval.id])
    end
  end

  describe '#hook_attrs' do
    let(:group_member) { build_stubbed(:group_member, :guest, user: user, source: group) }

    let(:member_approval) do
      build_stubbed(:gitlab_subscription_member_management_member_approval,
        new_access_level: 30,
        old_access_level: 10,
        member: group_member
      )
    end

    it 'returns a hash with the correct attributes' do
      expect(member_approval.hook_attrs).to eq({
        new_access_level: 30,
        old_access_level: 10,
        existing_member_id: group_member.id
      })
    end

    context 'when some attributes are nil' do
      let(:member_approval) do
        build_stubbed(:gitlab_subscription_member_management_member_approval,
          new_access_level: 30,
          old_access_level: nil,
          member_id: nil
        )
      end

      it 'returns a hash with specific nil values' do
        expect(member_approval.hook_attrs).to eq({
          new_access_level: 30,
          old_access_level: nil,
          existing_member_id: nil
        })
      end
    end
  end
end
