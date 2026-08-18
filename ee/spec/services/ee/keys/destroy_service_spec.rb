# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Keys::DestroyService, feature_category: :user_profile do
  let_it_be(:user) { create(:user) }

  subject { described_class.new(user) }

  it 'does not destroy LDAP key' do
    key = create(:ldap_key)

    expect { subject.execute(key) }.not_to change { Key.count }
    expect(key).not_to be_destroyed
  end

  context 'audit events' do
    context 'when licensed' do
      before do
        stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
      end

      it 'creates an audit event', :aggregate_failures do
        key = create(:personal_key)

        expect { subject.execute(key) }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last).to have_attributes(
          author: user,
          entity_id: key.user.id,
          target_id: key.id,
          target_type: key.class.name,
          target_details: key.title,
          details: include(custom_message: 'Removed SSH key')
        )
      end

      context 'when on SaaS', :saas do
        context 'when user is an Enterprise User', :aggregate_failures do
          let_it_be(:enterprise_group) { create(:group) }
          let_it_be(:user) do
            create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group)
          end

          it 'creates a group audit event' do
            key = create(:personal_key, user: user)
            expect { subject.execute(key) }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: user,
              entity_type: "Group",
              entity_id: enterprise_group.id,
              target_id: key.id,
              target_type: key.class.name,
              target_details: key.title,
              details: include(custom_message: 'Removed SSH key')
            )
          end
        end
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
      end

      it 'does not track audit event' do
        key = create(:personal_key)

        expect { subject.execute(key) }.not_to change { AuditEventReader.count }
      end
    end
  end

  it 'returns the correct value' do
    key = build(:personal_key)
    allow(key).to receive(:destroy).and_return(true)

    expect(subject.execute(key)).to eq(true)
  end

  context 'when destroy operation fails' do
    let(:key) { build(:personal_key) }

    before do
      allow(key).to receive(:destroy).and_return(false)
    end

    it 'does not create an audit event' do
      expect { subject.execute(key) }.not_to change { AuditEventReader.count }
    end

    it 'returns the correct value' do
      expect(subject.execute(key)).to eq(false)
    end
  end
end
