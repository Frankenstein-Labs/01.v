# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::SoftDeleteService, feature_category: :organization do
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
      end

      it 'logs an audit event with instance scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'organization_soft_deleted',
            author: user,
            scope: instance_of(::Gitlab::Audit::InstanceScope),
            target: organization,
            message: "Soft deleted organization '#{organization.name}'"
          )
        ).and_call_original

        expect { response }.to change { AuditEventReader.count }.by(1)
      end

      context 'when organization is already soft deleted' do
        before do
          described_class.new(organization, current_user: user).execute
          organization.reload
        end

        it 'does not log an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          response
        end
      end
    end
  end
end
