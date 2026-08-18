# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::AuditEvents::UserAuditEvent, feature_category: :audit_events do
  let_it_be(:user_audit_event) { create(:audit_events_user_audit_event) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_id) }
  end

  describe '#entity' do
    it 'returns user' do
      expect(user_audit_event.entity).to eq(User.find(user_audit_event.entity_id))
    end
  end

  describe '#entity_id' do
    it 'returns the user_id' do
      expect(user_audit_event.entity_id).to eq(user_audit_event.entity.id)
    end
  end

  describe '#present' do
    it 'returns a presenter' do
      expect(user_audit_event.present).to be_an_instance_of(AuditEventPresenter)
    end
  end

  describe '#user' do
    let_it_be(:user) { create(:user) }
    let_it_be(:user_audit_event) { create(:audit_events_user_audit_event, user_id: user.id) }

    it 'returns user' do
      expect(user_audit_event.user).to eq(user)
    end
  end

  it_behaves_like 'streaming audit event model'
end
