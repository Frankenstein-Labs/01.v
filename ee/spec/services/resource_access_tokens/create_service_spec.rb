# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceAccessTokens::CreateService, feature_category: :system_access do
  subject(:service_execute) { described_class.new(user, resource, params).execute }

  let_it_be(:user) { create(:user) }
  let_it_be(:params) { { expires_at: nil } }

  before do
    stub_licensed_features(audit_events: true)
    stub_licensed_features(external_audit_events: true)
    stub_feature_flags(allow_resource_access_token_creation_without_expiry_date: true)
    stub_application_setting(require_personal_access_token_expiry: false)
  end

  shared_examples 'token creation succeeds' do
    let(:resource) { create(:project, group: group) }

    before do
      resource.add_maintainer(user)
    end

    it 'does not cause an error' do
      response = service_execute

      expect(response.error?).to be false
    end

    it 'adds the project bot as a member' do
      expect { service_execute }.to change { resource.members.count }.by(1)
    end

    it 'creates a project bot user' do
      expect { service_execute }.to change { User.bots.count }.by(1)
    end
  end

  shared_examples 'audit event details' do
    it 'creates an audit event' do
      expect { service_execute }.to change { AuditEventReader.count }.from(0).to(1)
    end

    it 'logs author and resource info', :aggregate_failures do
      service_execute

      audit_event = AuditEventReader.where(author_id: user.id).last

      expect(audit_event.entity_id).to eq(resource.id)
      expect(audit_event.ip_address).to eq(user.current_sign_in_ip)
    end
  end

  describe '#execute' do
    context 'with enforced group managed account enabled' do
      let(:group) { create(:group_with_managed_accounts, :private) }
      let(:user) { create(:user, :group_managed, managing_group: group) }

      before do
        stub_feature_flags(group_managed_accounts: true)
        stub_licensed_features(group_saml: true)
      end

      it_behaves_like 'token creation succeeds'
    end

    context "for SAML enabled groups" do
      let(:group) { create(:group, :private) }
      let!(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }
      let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
      let(:user) { identity.user }

      before do
        stub_licensed_features(group_saml: true)
      end

      it_behaves_like 'token creation succeeds'
    end

    context 'resource access token audit events' do
      let_it_be(:group) { create(:group) }
      let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

      %i[project group].each do |resource_type|
        context "for #{resource_type} access token" do
          let_it_be(:resource) { resource_type == :project ? create(:project, group: group) : group }

          context "when #{resource_type} access token is successfully created" do
            before_all do
              resource_type == :project ? resource.add_maintainer(user) : resource.add_owner(user)
            end

            it_behaves_like 'audit event details'

            it 'logs the access token details', :aggregate_failures do
              response = service_execute

              audit_event = AuditEventReader.where(author_id: user.id).last
              access_token = response.payload[:access_token]
              custom_message = <<~MESSAGE.squish
              Created #{resource_type} access token with token_id: #{access_token.id} with scopes: #{access_token.scopes} and Maintainer access level.
              MESSAGE

              expect(audit_event.details).to include(
                custom_message: custom_message,
                target_id: access_token.id,
                target_type: access_token.class.name,
                target_details: access_token.user.name
              )
            end

            context 'when audit_user_agent is provided' do
              let(:params) { { expires_at: nil, audit_user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } }

              it 'includes user_agent in audit event details' do
                service_execute

                audit_event = AuditEventReader.where(author_id: user.id).last

                expect(audit_event.details).to include(user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)')
              end
            end

            context 'when audit_user_agent is not provided' do
              it 'does not include user_agent in audit event details' do
                service_execute

                audit_event = AuditEventReader.where(author_id: user.id).last

                expect(audit_event.details).not_to have_key(:user_agent)
              end
            end

            it_behaves_like 'sends correct event type in audit event stream' do
              let_it_be(:event_type) { "#{resource_type}_access_token_created" }
            end
          end

          context "when #{resource_type} access token is unsuccessfully created" do
            context 'with inadequate permissions' do
              before_all do
                resource.add_developer(user)
              end

              it_behaves_like 'audit event details'

              it 'logs the permission error message' do
                service_execute

                audit_event = AuditEventReader.where(author_id: user.id).last
                custom_message = <<~MESSAGE.squish
                Attempted to create #{resource_type} access token but failed with message:
                User does not have permission to create #{resource_type} access token
                MESSAGE

                expect(audit_event.details).to include(
                  custom_message: custom_message,
                  target_id: nil,
                  target_type: nil,
                  target_details: nil
                )
              end

              it_behaves_like 'sends correct event type in audit event stream' do
                let_it_be(:event_type) { "#{resource_type}_access_token_creation_failed" }
              end
            end

            context 'when access provisioning fails' do
              let_it_be(:user) { create(:user) }

              let_it_be(:unpersisted_member) { build("#{resource_type}_member", source: resource, user: user) }

              before do
                allow_next_instance_of(ResourceAccessTokens::CreateService) do |service|
                  allow(service).to receive(:create_user).and_return(ServiceResponse.success(payload: { user: user }))
                  allow(service).to receive(:create_membership).and_return(unpersisted_member)
                end

                allow(unpersisted_member).to receive_message_chain(:errors, :full_messages, :to_sentence)
                                  .and_return('error message')
              end

              before_all do
                resource_type == :project ? resource.add_maintainer(user) : resource.add_owner(user)
              end

              it_behaves_like 'audit event details'

              it 'logs the provisioning error message' do
                service_execute

                audit_event = AuditEventReader.where(author_id: user.id).last
                custom_message = <<~MESSAGE.squish
                Attempted to create #{resource_type} access token but failed with message:
                Could not provision maintainer access to the access token. ERROR: error message
                MESSAGE

                expect(audit_event.details).to include(
                  custom_message: custom_message,
                  target_id: nil,
                  target_type: nil,
                  target_details: nil
                )
              end

              it_behaves_like 'sends correct event type in audit event stream' do
                let_it_be(:event_type) { "#{resource_type}_access_token_creation_failed" }
              end
            end
          end
        end
      end
    end

    context 'when resource is project and reached project_access_token limit' do
      let_it_be(:group) { create(:group) }
      let(:resource) { build(:project, namespace: group) }

      before do
        resource.add_maintainer(user)
        allow(group).to receive(:reached_project_access_token_limit?).and_return(true)
      end

      it 'causes an error and does not change bots or members count' do
        expect { service_execute }.to not_change { resource.members.count }
                          .and not_change { User.bots.count }
        expect(service_execute.error?).to be true
      end
    end

    context 'when created by a service account' do
      let_it_be(:group) { create(:group) }
      let_it_be(:service_account) { create(:service_account) }
      let(:user) { service_account }

      it_behaves_like 'token creation succeeds'

      context 'when the service account is attempting to create a token with a higher access level' do
        let(:resource) { build(:project, namespace: group) }
        let(:params) { { access_level: Gitlab::Access::OWNER } }

        before do
          resource.add_maintainer(user)
        end

        it 'does not cause an error' do
          response = service_execute

          expect(response.error?).to be true
          expect(response.message).to eq("Access level of the token contains permissions not held by the creating user")
        end
      end
    end
  end
end
