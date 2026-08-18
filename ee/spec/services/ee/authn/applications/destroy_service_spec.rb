# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Authn::Applications::DestroyService, feature_category: :system_access do
  include TestRequestHelpers

  let(:user) { create(:user) }
  let(:application) { create(:oauth_application, owner: user) }
  let(:request) { test_request }

  subject(:service) { described_class.new(user, request, application) }

  describe '#execute' do
    context 'when audit events feature is enabled' do
      before do
        stub_licensed_features(extended_audit_events: true)
        application # Force eager evaluation so its creation audit events aren't counted during service.execute
      end

      it 'creates audit event with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'oauth_application_deleted',
          author: user,
          scope: user,
          target: application,
          message: 'OAuth application deleted',
          additional_details: hash_including(
            application_name: application.name,
            application_id: application.id
          ),
          ip_address: request.remote_ip
        )

        service.execute
      end

      it 'creates an AuditEvent record' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)
      end

      context 'when destruction is not authorized' do
        let_it_be(:other_user) { create(:user) }

        subject(:service) { described_class.new(other_user, request, application) }

        it 'does not create an audit event' do
          expect { service.execute }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
