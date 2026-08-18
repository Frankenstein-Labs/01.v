# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Applications::CreateService, feature_category: :system_access do
  include TestRequestHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  let(:request) { test_request }
  let(:group) { create(:group) }
  let(:params) { attributes_for(:application, scopes: %w[read_user], organization_id: user.organization.id) }

  subject(:service) { described_class.new(user, request, params) }

  describe '#audit_oauth_application_creation' do
    where(:case_name, :owner, :entity_type) do
      'instance application' | nil | 'User'
      'group application' | ref(:group) | 'Group'
      'user application' | ref(:user) | 'User'
    end

    with_them do
      before do
        stub_licensed_features(extended_audit_events: true)
        params[:owner] = owner
      end

      it 'creates audit event with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'oauth_application_created',
          author: user,
          scope: owner || user,
          target: instance_of(::Authn::OauthApplication),
          message: 'OAuth application added',
          additional_details: hash_including(
            application_name: anything,
            application_id: anything,
            scopes: %w[read_user]
          ),
          ip_address: request.remote_ip
        )

        service.execute
      end

      it 'creates AuditEvent with correct entity type' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.entity_type).to eq(entity_type)
      end
    end

    context 'when application has multiple scopes' do
      let(:params) do
        attributes_for(
          :application,
          scopes: %w[api read_user read_repository],
          organization_id: user.organization.id
        )
      end

      it 'includes all scopes in audit details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            additional_details: hash_including(
              scopes: %w[api read_user read_repository]
            )
          )
        )

        service.execute
      end
    end
  end

  context 'when executed from an internal api call' do
    before do
      stub_licensed_features(extended_audit_events: true)
    end

    context 'when request is nil' do
      let(:request) { nil }

      it 'creates the app and does not fail' do
        expect { service.execute }.to change { Authn::OauthApplication.count }.by(1)
      end

      it 'creates an audit event' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)
      end
    end

    context 'when request does not respond to #remote_ip or #ip' do
      before do
        allow(request).to receive(:respond_to?).and_call_original
        allow(request).to receive(:respond_to?).with(:remote_ip).and_return(false)
        allow(request).to receive(:respond_to?).with(:ip).and_return(false)
      end

      it 'creates the app and does not fail' do
        expect { service.execute }.to change { Authn::OauthApplication.count }.by(1)
      end

      it 'creates an audit event' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)
      end
    end

    context 'when application owner and user are both nil', :with_current_organization do
      let(:user) { nil }
      let(:params) do
        attributes_for(
          :application,
          :without_owner,
          scopes: %w[read_user],
          organization_id: current_organization.id
        )
      end

      it 'creates the app and does not fail' do
        expect { service.execute }.to change { Authn::OauthApplication.count }.by(1)
      end

      it 'skips audit event' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end
  end
end
