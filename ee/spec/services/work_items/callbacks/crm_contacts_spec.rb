# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::CrmContacts, feature_category: :service_desk do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:contact) { create(:contact, group: group) }

  let(:default_params) { { contact_ids: [contact.id] } }
  let(:params) { default_params }

  subject(:callback) { described_class.new(issuable: work_item, current_user: user, params: params).after_save }

  context 'when work item belongs to a group' do
    let(:work_item) { create(:work_item, :group_level, namespace: group) }

    context 'with group level work item license' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'updates the contacts' do
        allow(::Issues::SetCrmContactsService).to receive(:new).and_call_original

        callback

        expect(work_item.customer_relations_contacts).to contain_exactly(contact)
      end
    end

    context 'without group level work item license' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'updates the contacts' do
        allow(::Issues::SetCrmContactsService).to receive(:new).and_call_original

        expect { callback }.to raise_error(
          ::Issuable::Callbacks::Base::Error,
          /You have insufficient permissions to set customer relations contacts for this issue/
        )
      end
    end
  end
end
