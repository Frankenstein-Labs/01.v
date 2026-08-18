# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::HardDeleteService, feature_category: :organization do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:organization) { create(:organization) }

  before_all do
    create(:organization_user, :owner, organization: organization, user: user)
  end

  subject(:response) { described_class.new(organization, current_user: user).execute }

  describe '#execute' do
    context 'for audit events' do
      before do
        stub_licensed_features(admin_audit_log: true)
        organization.soft_delete!(transition_user: user)
        # Avoid the FK constraint between organizations and organization_users;
        # cascade cleanup is out of scope for the initial service plumbing.
        allow(organization).to receive(:destroy!).and_return(true)
      end

      it 'logs an audit event with instance scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'organization_hard_deleted',
            author: user,
            scope: instance_of(::Gitlab::Audit::InstanceScope),
            target: organization,
            message: "Hard deleted organization '#{organization.name}'"
          )
        ).and_call_original

        expect { response }.to change { AuditEventReader.count }.by(1)
      end

      context 'when destroy! raises' do
        before do
          allow(organization).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed, 'boom')
        end

        it 'does not log an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          expect { response }.to raise_error(ActiveRecord::RecordNotDestroyed)
        end
      end
    end
  end
end
