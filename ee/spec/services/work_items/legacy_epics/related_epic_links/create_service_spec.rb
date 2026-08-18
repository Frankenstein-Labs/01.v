# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::RelatedEpicLinks::CreateService, feature_category: :team_planning do
  describe '#execute' do
    let_it_be(:user) { create :user }
    let_it_be(:group) { create :group }
    let_it_be(:issuable) { create :epic, group: group }
    let_it_be(:issuable2) { create :epic, group: group }
    let_it_be(:restricted_issuable) { create(:epic, group: create(:group, :private)) }
    let_it_be(:readonly_issuable) { create(:epic, group: create(:group, :public)) }
    let_it_be(:another_group) { create :group }
    let_it_be(:issuable3) { create :epic, group: another_group }
    let_it_be(:issuable_a) { create :epic, group: group }
    let_it_be(:issuable_b) { create :epic, group: group }
    let_it_be(:issuable_link) do
      create :related_epic_link, source: issuable, target: issuable_b,
        link_type: IssuableLink::TYPE_RELATES_TO
    end

    let(:current_user) { user }
    let(:issuable_parent) { issuable.group }
    let(:issuable_type) { :epic }
    let(:issuable_link_class) { Epic::RelatedEpicLink }
    let(:params) { {} }
    let(:not_found_error) { "No matching epic found. Make sure that you are adding a valid epic URL." }

    before do
      stub_licensed_features(epics: true, related_epics: true)
    end

    before_all do
      group.add_guest(user)
      another_group.add_guest(user)
    end

    subject(:execute) { described_class.new(issuable, current_user, params).execute }

    it_behaves_like 'issuable link creation' do
      let(:async_notes) { true }
      let(:noteable) { issuable.work_item }
      let(:noteable2) { issuable2.work_item }
      let(:noteable3) { issuable3.work_item }
      let(:noteable_link_class) { WorkItems::RelatedWorkItemLink }
    end

    it_behaves_like 'issuable link creation with blocking link_type' do
      let(:async_notes) { true }
      let(:noteable) { issuable.work_item }
      let(:noteable2) { issuable2.work_item }
      let(:noteable3) { issuable3.work_item }
      let(:noteable_link_class) { WorkItems::RelatedWorkItemLink }
      let(:params) do
        { issuable_references: [issuable2.to_reference, issuable3.to_reference(issuable3.group, full: true)] }
      end
    end

    context 'when target issuable is empty' do
      let(:params) do
        {
          target_issuable: nil,
          link_type: 'relates_to'
        }
      end

      it 'does not create a related epic link and returns an error message when references are empty' do
        expect { execute }
          .to not_change { Epic::RelatedEpicLink.count }
          .and not_change { WorkItems::RelatedWorkItemLink.count }

        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to eq(not_found_error)
      end
    end

    context 'with permission checks' do
      let_it_be(:other_user) { create(:user) }

      let(:http_status) { 404 }
      let(:error_message) { not_found_error }
      let(:params) { { issuable_references: [issuable3.to_reference(full: true)] } }

      shared_examples 'creates link' do
        it 'creates relationship', :aggregate_failures do
          expect { subject }.to change { issuable_link_class.count }.by(1)

          expect(issuable_link_class.find_by!(target: issuable3))
            .to have_attributes(source: issuable, link_type: 'relates_to')
          expect(subject[:status]).to eq(:success)
          expect(subject[:created_references]).to contain_exactly(an_instance_of(Epic::RelatedEpicLink))
        end
      end

      shared_examples 'fails to create link' do
        it 'does not create relationship', :aggregate_failures do
          expect { subject }.not_to change { issuable_link_class.count }

          is_expected.to eq(message: error_message, status: :error, http_status: http_status)
        end
      end

      context 'with target issuable' do
        let(:params) do
          {
            target_issuable: issuable3,
            link_type: 'relates_to'
          }
        end

        it_behaves_like 'creates link'

        context 'when related_epics feature is not available' do
          before do
            stub_licensed_features(epics: true, related_epics: false)
          end

          it_behaves_like 'fails to create link'
        end
      end

      context 'when user is not a guest in source group' do
        let_it_be(:current_user) { create(:user, guest_of: another_group) }

        it_behaves_like 'fails to create link'
      end

      context 'when user is not a guest in target group' do
        let_it_be(:current_user) { create(:user, guest_of: group) }
        let(:http_status) { 403 }
        let(:error_message) { "Could not link epics. You must be a member of the project or group of both epics." }

        it_behaves_like 'fails to create link'
      end

      context 'when user is guest in both groups' do
        let_it_be(:current_user) { create(:user, guest_of: [another_group, group]) }

        it_behaves_like 'creates link'
      end
    end

    context 'for syncing to related work item links' do
      let(:params) { { issuable_references: [issuable2.to_reference(full: true)] } }

      it_behaves_like 'syncs all data from an epic to a work item' do
        let(:epic) { issuable }
      end

      it 'creates a link for the epics and the synced work item' do
        expect { execute }.to change { Epic::RelatedEpicLink.count }.by(1)
          .and change { WorkItems::RelatedWorkItemLink.count }.by(1)

        expect(WorkItems::RelatedWorkItemLink.find_by!(target: issuable2.work_item))
          .to have_attributes(source: issuable.work_item, link_type: IssuableLink::TYPE_RELATES_TO)

        expect(issuable.reload.updated_at).to eq(issuable.work_item.updated_at)
        expect(issuable2.reload.updated_at).to eq(issuable2.work_item.updated_at)
      end

      context 'when link type is blocking' do
        let(:params) do
          { issuable_references: [issuable2.to_reference(full: true)], link_type: IssuableLink::TYPE_BLOCKS }
        end

        it 'creates a blocking link' do
          execute

          expect(WorkItems::RelatedWorkItemLink.find_by!(target: issuable2.work_item))
            .to have_attributes(source: issuable.work_item, link_type: IssuableLink::TYPE_BLOCKS)
        end
      end

      context 'when link type is blocked by' do
        let(:params) do
          { issuable_references: [issuable2.to_reference(full: true)], link_type: IssuableLink::TYPE_IS_BLOCKED_BY }
        end

        it 'creates a blocking link' do
          execute

          expect(WorkItems::RelatedWorkItemLink.find_by!(target: issuable.work_item))
            .to have_attributes(source: issuable2.work_item, link_type: IssuableLink::TYPE_BLOCKS)
        end
      end

      context 'when multiple epics are referenced' do
        let(:params) do
          { issuable_references: [issuable2.to_reference(full: true), issuable3.to_reference(full: true)] }
        end

        it 'creates a link for the epics and the synced work item', :sidekiq_inline do
          expect { execute }.to change { Epic::RelatedEpicLink.count }.by(2)
            .and change { WorkItems::RelatedWorkItemLink.count }.by(2)
            .and change {
                   Note.count
                 }.by(3) # 1 note on the source (gets combined for multiple targets) + 1 notes for each target.
        end
      end
    end
  end
end
