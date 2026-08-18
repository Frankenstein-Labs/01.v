# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DeleteServiceAccountMembersFromHierarchyWorker, feature_category: :ai_abstraction_layer do
  let_it_be(:triggering_user) { create(:user) }

  let_it_be(:group) { create(:group, owners: triggering_user) }

  let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }

  let_it_be(:subgroup) { create(:group, parent: group, developers: service_account) }
  let_it_be(:project) { create(:project, group: group, developers: service_account) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup, developers: service_account) }

  let(:members_destroy_service_options) { {} }

  before_all do
    group.add_developer(service_account)
  end

  shared_examples 'does not remove memberships or call destroy service' do
    it 'does not remove any memberships' do
      expect { perform }.not_to change { Member.count }
    end

    it 'does not call Members::DestroyService' do
      expect(Members::DestroyService).not_to receive(:new)

      perform
    end
  end

  describe 'worker attributes' do
    it 'has the correct feature category' do
      expect(described_class.get_feature_category).to eq(:ai_abstraction_layer)
    end

    it 'has the correct urgency' do
      expect(described_class.get_urgency).to eq(:low)
    end

    it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

    it 'is idempotent' do
      expect(described_class.idempotent?).to be(true)
    end
  end

  describe '#perform' do
    subject(:perform) do
      described_class.new.perform(
        triggering_user.id,
        service_account.id,
        group.id,
        members_destroy_service_options
      )
    end

    it 'does not remove group membership' do
      expect { perform }
        .not_to change { group.members.with_user(service_account).count }
    end

    it 'does not remove subgroup membership' do
      expect { perform }
        .not_to change { subgroup.members.with_user(service_account).count }
    end

    it 'removes project membership' do
      expect { perform }
        .to change { project.members.with_user(service_account).count }.from(1).to(0)
    end

    it 'removes subgroup project membership' do
      expect { perform }.to change {
        subgroup_project.members.with_user(service_account).count
      }.from(1).to(0)
    end

    it 'passes skip_subresources: true to destroy service' do
      expect(Members::DestroyService).to receive(:new).with(
        an_instance_of(ProjectMember),
        hash_including(skip_subresources: true)
      ).twice.and_call_original

      perform
    end

    context 'with additional members_destroy_service_options' do
      let(:members_destroy_service_options) { { unassign_issuables: true } }

      it 'merges options with skip_subresources: true' do
        expect(Members::DestroyService).to receive(:new).with(
          an_instance_of(ProjectMember),
          hash_including(skip_subresources: true, unassign_issuables: true)
        ).twice.and_call_original

        perform
      end
    end

    context 'when triggering_user does not exist' do
      subject(:perform) do
        described_class.new.perform(non_existing_record_id, service_account.id, group.id)
      end

      it_behaves_like 'does not remove memberships or call destroy service'
    end

    context 'when service account does not exist' do
      subject(:perform) do
        described_class.new.perform(triggering_user.id, non_existing_record_id, group.id)
      end

      it_behaves_like 'does not remove memberships or call destroy service'
    end

    context 'when group does not exist' do
      subject(:perform) do
        described_class.new.perform(triggering_user.id, service_account.id, non_existing_record_id)
      end

      it_behaves_like 'does not remove memberships or call destroy service'
    end

    context 'when service account has no memberships in the hierarchy' do
      let_it_be(:empty_group) { create(:group, owners: triggering_user) }

      subject(:perform) do
        described_class.new.perform(
          triggering_user.id, service_account.id, empty_group.id, members_destroy_service_options
        )
      end

      it 'does not call Members::DestroyService' do
        expect(Members::DestroyService).not_to receive(:new)

        perform
      end

      it 'does not raise an error' do
        expect { perform }.not_to raise_error
      end
    end

    context 'when service account has memberships outside the hierarchy' do
      let_it_be(:other_group) { create(:group, owners: triggering_user, developers: service_account) }
      let_it_be(:other_project) do
        create(:project, group: other_group, developers: service_account)
      end

      subject(:perform) do
        described_class.new.perform(triggering_user.id, service_account.id, group.id, members_destroy_service_options)
      end

      it 'only removes project memberships within the specified hierarchy' do
        expect { perform }.to change {
          ProjectMember.in_hierarchy(group).with_user(service_account).count
        }.to(0).and not_change {
          Member.in_hierarchy(other_group).with_user(service_account).count
        }
      end

      it 'does not affect memberships in other groups' do
        perform

        expect(other_group.members.with_user(service_account)).to exist
        expect(other_project.members.with_user(service_account)).to exist
      end

      it 'does not remove group memberships in the hierarchy' do
        expect { perform }.not_to change {
          GroupMember.in_hierarchy(group).with_user(service_account).count
        }
      end
    end

    context 'when Members::DestroyService fails for one membership' do
      let_it_be(:group) { create(:group, owners: triggering_user) }
      let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }
      let_it_be(:project) { create(:project, group: group, developers: service_account) }

      before do
        allow_next_instance_of(Members::DestroyService) do |instance|
          allow(instance).to receive(:execute) do
            instance.send(:member).errors.add(:base, 'Deletion failed')
          end
        end
      end

      it 'tracks and reports the error' do
        error = described_class::MemberDeletionError.new("Could not delete member: Deletion failed")
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
          error, { project_id: project.id, service_account_id: service_account.id }
        )

        perform
      end
    end

    context 'when one of the memberships is still needed for a flow' do
      let_it_be(:flow) { create(:ai_catalog_item, :flow) }

      let_it_be(:group_flow_consumer) do
        create(:ai_catalog_item_consumer, item: flow, service_account: service_account, group: group)
      end

      let_it_be(:project_flow_consumer) do
        create(
          :ai_catalog_item_consumer,
          item: flow,
          service_account: nil,
          parent_item_consumer: group_flow_consumer,
          project: subgroup_project
        )
      end

      it 'does not delete that membership' do
        expect { perform }.not_to change {
          subgroup_project.members.with_user(service_account).count
        }
      end
    end

    context 'with string keys in members_destroy_service_options' do
      let(:members_destroy_service_options) { { 'unassign_issuables' => true } }

      it 'symbolizes keys and merges with skip_subresources' do
        expect(Members::DestroyService).to receive(:new).with(
          anything,
          hash_including(skip_subresources: true, unassign_issuables: true)
        ).twice.and_call_original

        perform
      end
    end

    context 'when part way through, a new consumer is created for the service account' do
      let_it_be(:flow) { create(:ai_catalog_item, :flow) }

      let(:project_member) { ProjectMember.find_by(project: project, user: service_account) }
      let(:subgroup_project_member) { ProjectMember.find_by(project: subgroup_project, user: service_account) }

      before do
        allow(::ProjectMember).to receive_message_chain(:in_hierarchy, :with_user, :find_each) do |&block|
          block.call(project_member)

          group_flow_consumer =
            create(:ai_catalog_item_consumer, item: flow, service_account: service_account, group: group)

          create(
            :ai_catalog_item_consumer,
            item: flow,
            service_account: nil,
            parent_item_consumer: group_flow_consumer,
            project: subgroup_project
          )

          block.call(subgroup_project_member)
        end
      end

      it 'does not delete the member for the flow/project' do
        expect { perform }.to change { Member.count }.by(-1)

        expect(ProjectMember).not_to exist(project_member.id)
        expect(ProjectMember).to exist(subgroup_project_member.id)
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [triggering_user.id, service_account.id, group.id, {}] }
  end
end
