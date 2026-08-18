# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SamlGroupLinksController, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:user)  { create(:user, owner_of: group) }

  before do
    stub_licensed_features(group_saml: true, saml_group_sync: true)

    sign_in(user)
  end

  shared_examples 'checks authorization' do
    let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }
    let_it_be(:params) { route_params }

    it 'renders 404 when the user is not authorized' do
      allow(controller).to receive(:can?).and_call_original
      allow(controller).to receive(:can?).with(user, :admin_saml_group_links, group).and_return(false)

      call_action

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe '#index' do
    let_it_be(:route_params) { { group_id: group } }

    subject(:call_action) { get :index, params: params }

    it_behaves_like 'checks authorization'

    context 'when the SAML provider is enabled' do
      let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }
      let_it_be(:params) { route_params }

      it 'responds with 200' do
        call_action

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe '#create' do
    let_it_be(:route_params) { { group_id: group } }

    subject(:call_action) { post :create, params: params }

    it_behaves_like 'checks authorization'

    context 'when the SAML provider is enabled' do
      let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

      context 'with valid parameters' do
        let_it_be(:saml_group_name) { generate(:saml_group_name) }
        let_it_be(:params) { route_params.merge(saml_group_link: { access_level: ::Gitlab::Access::REPORTER, saml_group_name: saml_group_name }) }

        it 'responds with success' do
          expect(::Gitlab::Audit::Auditor)
            .to receive(:audit).with(
              hash_including(
                { name: "saml_group_links_created",
                  author: user,
                  scope: group,
                  target: group,
                  message: "SAML group links created. Group Name - #{saml_group_name}, Access Level - 20" })
            ).and_call_original

          call_action

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:notice]).to include('New SAML group link saved.')
          expect(AuditEventReader.last.details[:custom_message]).to eq("SAML group links created. Group Name - #{saml_group_name}, Access Level - 20")
        end

        it 'creates the group link without provider' do
          expect { call_action }.to change { group.saml_group_links.count }.by(1)
          expect(group.saml_group_links.last.provider).to be_nil
        end

        context 'with provider in the params' do
          let(:provider) { 'saml2' }
          let(:params) do
            route_params.merge(
              saml_group_link: {
                access_level: ::Gitlab::Access::REPORTER,
                saml_group_name: saml_group_name,
                provider: provider
              }
            )
          end

          it 'creates the group link with provider' do
            expect { call_action }.to change { group.saml_group_links.count }.by(1)
            expect(group.saml_group_links.last.provider).to eq(provider)
          end

          context 'when provider is empty' do
            let(:params) do
              route_params.merge(
                saml_group_link: {
                  access_level: ::Gitlab::Access::REPORTER,
                  saml_group_name: saml_group_name,
                  provider: ''
                }
              )
            end

            it 'stores blank provider as nil' do
              expect { call_action }.to change { group.saml_group_links.count }.by(1)
              expect(group.saml_group_links.last.provider).to be_nil
            end
          end
        end

        context 'when a member_role_id is provided', feature_category: :permissions do
          let(:custom_roles_enabled) { true }
          let_it_be(:member_role) { create(:member_role, namespace: group) }
          let_it_be(:params) do
            route_params.merge(saml_group_link: { access_level: ::Gitlab::Access::DEVELOPER, saml_group_name: saml_group_name, member_role_id: member_role.id })
          end

          before do
            stub_licensed_features(group_saml: true, saml_group_sync: true, custom_roles: custom_roles_enabled)
          end

          it 'sets the member_role' do
            call_action

            expect(group.saml_group_links.last.member_role).to eq(member_role)
          end

          context 'when custom roles are not enabled' do
            let(:custom_roles_enabled) { false }

            it 'does not set the member_role' do
              call_action

              expect(group.saml_group_links.last.member_role).to be_nil
            end
          end
        end

        context 'when SaaS Duo add-on is available' do
          let_it_be(:params) do
            route_params.merge(
              saml_group_link: {
                access_level: ::Gitlab::Access::REPORTER,
                saml_group_name: saml_group_name,
                assign_duo_seats: true
              }
            )
          end

          let_it_be(:add_on_purchase) do
            create(
              :gitlab_subscription_add_on_purchase,
              :duo_pro,
              expires_on: 1.week.from_now.to_date,
              namespace: group
            )
          end

          before do
            stub_saas_features(gitlab_duo_saas_only: true)
          end

          it 'responds with success' do
            expect(::Gitlab::Audit::Auditor)
              .to receive(:audit).with(
                hash_including(
                  {
                    name: "saml_group_links_created",
                    author: user,
                    scope: group,
                    target: group,
                    message: "SAML group links created. Group Name - #{saml_group_name}, Access Level - 20, Assign Duo Seats"
                  }
                )
              ).and_call_original

            call_action

            expect(response).to have_gitlab_http_status(:found)
            expect(flash[:notice]).to include('New SAML group link saved.')
            expect(AuditEventReader.last.details[:custom_message])
              .to eq("SAML group links created. Group Name - #{saml_group_name}, Access Level - 20, Assign Duo Seats")
          end
        end
      end

      context 'with missing parameters' do
        let_it_be(:params) { route_params.merge(saml_group_link: { access_level: ::Gitlab::Access::MAINTAINER }) }

        it 'displays an error' do
          call_action

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:alert]).to include("Could not create SAML group link: Saml group name can't be blank.")
        end
      end

      context 'with unpermitted parameters' do
        let_it_be(:params) do
          route_params.merge(
            saml_group_link: {
              access_level: ::Gitlab::Access::REPORTER,
              saml_group_name: generate(:saml_group_name),
              assign_duo_seats: true
            }
          )
        end

        it 'ignores the parameter' do
          call_action

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:notice]).to include('New SAML group link saved.')
          expect(SamlGroupLink.last).not_to be_assign_duo_seats
        end
      end
    end
  end

  describe '#destroy' do
    let_it_be(:group_link) { create(:saml_group_link, group: group) }
    let_it_be(:route_params) { { group_id: group, id: group_link } }

    subject(:call_action) { delete :destroy, params: params }

    it_behaves_like 'checks authorization'

    context 'when the SAML provider is enabled' do
      let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

      context 'with an existent group link' do
        let_it_be(:params) { route_params }

        it 'responds with success' do
          expect(::Gitlab::Audit::Auditor)
            .to receive(:audit).with(
              hash_including(
                { name: "saml_group_links_removed",
                  author: user,
                  scope: group,
                  target: group,
                  message: "SAML group links removed. Group Name - #{group_link.saml_group_name}" })
            ).and_call_original

          call_action

          expect(response).to have_gitlab_http_status(:found)
          expect(flash[:notice]).to include('SAML group link was successfully removed.')
          expect(AuditEventReader.last.details[:custom_message]).to eq("SAML group links removed. Group Name - #{group_link.saml_group_name}")
        end

        it 'removes the group link' do
          expect { call_action }.to change { group.saml_group_links.count }.by(-1)
        end
      end

      context 'with a non-existent group link' do
        let_it_be(:params) { { group_id: group, id: non_existing_record_id } }

        it 'renders 404' do
          call_action

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
