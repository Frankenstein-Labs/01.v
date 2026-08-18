# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Authn::Applications::UpdateService, feature_category: :system_access do
  include TestRequestHelpers

  let_it_be(:user) { create(:user) }
  let(:application) { create(:oauth_application, owner: user) }

  let(:request) { test_request }
  let(:params) { { name: 'Updated App' } }

  subject(:service) { described_class.new(user, request, application, params) }

  describe '#execute' do
    context 'when audit events feature is enabled' do
      before do
        stub_licensed_features(extended_audit_events: true)
        application # Force eager evaluation so its creation audit events aren't counted
      end

      it 'creates audit event with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'oauth_application_updated',
          author: user,
          scope: user,
          target: application,
          message: 'OAuth application updated',
          additional_details: hash_including(
            application_name: 'Updated App',
            application_id: application.id
          ),
          ip_address: request.remote_ip
        )

        service.execute
      end

      it 'creates an AuditEvent record' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)
      end

      context 'when update fails' do
        let(:params) { { name: '' } }

        it 'does not create an audit event' do
          expect { service.execute }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
