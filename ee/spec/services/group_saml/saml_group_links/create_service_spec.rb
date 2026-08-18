# frozen_string_literal: true

require "spec_helper"

RSpec.describe GroupSaml::SamlGroupLinks::CreateService, feature_category: :system_access do
  subject(:service) { described_class.new(current_user: current_user, group: group, params: params) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, owners: current_user) }

  describe "#execute" do
    let(:params) do
      {
        saml_group_name: "Test group",
        access_level: ::Gitlab::Access::GUEST
      }
    end

    let_it_be(:audit_event_message) { "SAML group links created. Group Name - Test group, Access Level - 10" }

    context "when authorized user" do
      context "when licensed features are available" do
        before do
          stub_licensed_features(group_saml: true, saml_group_sync: true)
        end

        context "with valid params" do
          let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

          it "create a new saml_group_link entry against the group" do
            audit_context = {
              name: 'saml_group_links_created',
              author: current_user,
              scope: group,
              target: group,
              message: audit_event_message
            }
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).once.and_call_original

            response = service.execute

            expect(response).to be_success
            expect(AuditEventReader.count).to eq(1)
            expect(AuditEventReader.last.details[:custom_message]).to eq(audit_event_message)
          end

          context 'when a `member_role_id` parameter is provided', feature_category: :permissions do
            let_it_be(:member_role) { create(:member_role, namespace: group) }
            let(:params) { super().merge(member_role_id: member_role.id) }

            context 'when custom roles are not enabled' do
              it 'does not update the `member_role`' do
                response = service.execute

                expect(response).to be_success
                expect(group.saml_group_links.last.member_role).to eq(nil)
                expect(AuditEventReader.last.details[:custom_message]).not_to include("Member Role - #{member_role.id}")
              end
            end

            context 'when custom roles are enabled' do
              before do
                stub_licensed_features(group_saml: true, saml_group_sync: true, custom_roles: true)
              end

              it 'updates the `access_level` and the `member_role`' do
                response = service.execute
                saml_group_link = group.saml_group_links.last

                expect(response).to be_success
                expect(saml_group_link.member_role).to eq(member_role)
                expect(saml_group_link.access_level).to eq(member_role.base_access_level)
                expect(AuditEventReader.last.details[:custom_message]).to include("Member Role - #{member_role.id}")
              end
            end
          end
        end

        context "when invalid params" do
          let(:invalid_params) do
            {
              saml_group_name: "Test group",
              access_level: "invalid"
            }
          end

          subject(:service) { described_class.new(current_user: current_user, group: group, params: invalid_params) }

          it "throws bad request error" do
            response = service.execute
            expect(response).not_to be_success
            expect(response[:error]).to match(/Access level is invalid/)
          end
        end
      end
    end

    context "when user is not allowed to create saml_group_links" do
      before do
        allow(Ability).to receive(:allowed?).with(current_user, :admin_saml_group_links, group).and_return(false)
      end

      it "throws unauthorized error" do
        response = service.execute

        expect(response).not_to be_success
        expect(response[:message]).to eq("Unauthorized")
      end
    end
  end
end
