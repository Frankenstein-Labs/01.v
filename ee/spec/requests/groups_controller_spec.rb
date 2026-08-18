# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupsController, :aggregate_failures, type: :request, feature_category: :groups_and_projects do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  describe 'GET #edit' do
    context 'step-up authentication enforcement' do
      let_it_be_with_reload(:group) { create(:group) }

      subject(:make_request) { get edit_group_path(group) }

      before do
        sign_in(user)
      end

      context 'when user is owner' do
        let_it_be_with_reload(:user) { create(:user, owner_of: group) }

        let(:expected_success_status) { :ok }

        it_behaves_like 'does not enforce step-up authentication'
      end

      context 'when user is maintainer' do
        let_it_be_with_reload(:user) { create(:user, maintainer_of: group) }

        let(:expected_success_status) { :not_found }

        it_behaves_like 'does not enforce step-up authentication'
      end
    end
  end

  describe 'PUT update' do
    before do
      group.add_owner(user)
      login_as(user)
    end

    subject(:request) do
      put(group_path(group), params: params)
    end

    context 'setting ip_restriction' do
      let(:params) { { group: { ip_restriction_ranges: range } } }
      let(:range) { '192.168.0.0/24' }

      before do
        stub_licensed_features(group_ip_restriction: true)
        allow_any_instance_of(Gitlab::IpRestriction::Enforcer).to(
          receive(:allows_current_ip?).and_return(true))
        # TODO: Remove this workaround once https://gitlab.com/gitlab-org/gitlab/-/issues/442164 is addressed
        allow_any_instance_of(EE::Namespace).to receive(:duo_features_enabled).and_return(false)
        allow_any_instance_of(EE::Namespace).to receive(:auto_duo_code_review_settings_available?).and_return(false)
        allow_any_instance_of(NamespaceSetting).to receive(:require_sha_for_merge_locked?).and_return(false)
        allow_any_instance_of(NamespaceSetting).to receive(:require_sha_for_merge).and_return(false)
      end

      context 'top-level group' do
        context 'when ip_restriction does not exist' do
          context 'valid param' do
            shared_examples 'creates ip restrictions' do
              it 'creates ip restrictions' do
                expect { request }
                  .to change { group.reload.ip_restrictions.map(&:range) }
                    .from([]).to(contain_exactly(*range.split(',')))
                expect(response).to have_gitlab_http_status(:found)
              end
            end

            context 'single IP subnet' do
              let(:range) { '192.168.0.0/24' }

              it_behaves_like 'creates ip restrictions'
            end

            context 'multiple IP subnets' do
              let(:range) { '192.168.0.0/24,192.168.0.1/8' }

              it_behaves_like 'creates ip restrictions'
            end
          end

          context 'invalid param' do
            let(:range) { 'boom!' }

            it 'adds error message' do
              expect { request }
                .not_to(change { group.reload.ip_restrictions.count }.from(0))
              expect(response).to have_gitlab_http_status(:ok)
              expect(response.body).to include('Ip restrictions range is an invalid IP address range')
            end
          end
        end

        context 'when ip_restriction already exists' do
          let!(:ip_restriction) { IpRestriction.create!(group: group, range: '10.0.0.0/8') }
          let(:params) { { group: { ip_restriction_ranges: range } } }

          context 'ip restriction param set' do
            context 'valid param' do
              shared_examples 'updates ip restrictions' do
                it 'updates ip restrictions' do
                  expect { request }
                    .to change { group.reload.ip_restrictions.map(&:range) }
                      .from(['10.0.0.0/8']).to(contain_exactly(*range.split(',')))
                  expect(response).to have_gitlab_http_status(:found)
                end
              end

              context 'single subnet' do
                let(:range) { '192.168.0.0/24' }

                it_behaves_like 'updates ip restrictions'
              end

              context 'multiple subnets' do
                context 'a new subnet along with the existing one' do
                  let(:range) { '10.0.0.0/8,192.168.1.0/8' }

                  it_behaves_like 'updates ip restrictions'
                end

                context 'completely new range of subnets' do
                  let(:range) { '192.168.0.0/24,192.168.1.0/8' }

                  it_behaves_like 'updates ip restrictions'
                end
              end
            end

            context 'invalid param' do
              shared_examples 'does not update existing ip restrictions' do
                it 'does not change ip restriction records' do
                  expect { request }
                    .not_to(change { group.reload.ip_restrictions.map(&:range) }
                      .from(['10.0.0.0/8']))
                end

                it 'adds error message' do
                  request

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(response.body).to include('Ip restrictions range is an invalid IP address range')
                end
              end

              context 'not a valid subnet' do
                let(:range) { 'boom!' }

                it_behaves_like 'does not update existing ip restrictions'
              end

              context 'multiple IP subnets' do
                context 'any one of them being not a valid' do
                  let(:range) { '192.168.0.0/24,boom!' }

                  it_behaves_like 'does not update existing ip restrictions'
                end
              end
            end
          end

          context 'empty ip restriction param' do
            let(:range) { '' }

            it 'deletes ip restriction' do
              expect { request }
                .to(change { group.reload.ip_restrictions.count }.to(0))
              expect(response).to have_gitlab_http_status(:found)
            end
          end
        end
      end

      context 'subgroup' do
        let(:group) { create(:group, :nested) }

        it 'does not create ip restriction' do
          expect { request }
            .not_to change { group.reload.ip_restrictions.count }.from(0)
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('Ip restrictions IP subnet restriction only allowed for top-level groups')
        end
      end

      context 'with empty ip restriction param' do
        let(:params) do
          { group: { two_factor_grace_period: 42,
                     ip_restriction_ranges: "" } }
        end

        it 'updates group setting' do
          expect { request }
            .to change { group.reload.two_factor_grace_period }.from(48).to(42)
          expect(response).to have_gitlab_http_status(:found)
        end

        it 'does not create ip restriction' do
          expect { request }.not_to change { IpRestriction.count }
        end
      end

      context 'feature is disabled' do
        before do
          stub_licensed_features(group_ip_restriction: false)
        end

        it 'does not create ip restriction' do
          expect { request }
            .not_to change { group.reload.ip_restrictions.count }.from(0)
          expect(response).to have_gitlab_http_status(:found)
        end
      end
    end

    context 'setting email domain restrictions' do
      let(:params) { { group: { allowed_email_domains_list: domains } } }

      before do
        stub_licensed_features(group_allowed_email_domains: true)
        # TODO: Remove this workaround once https://gitlab.com/gitlab-org/gitlab/-/issues/442164 is addressed
        allow_any_instance_of(EE::Namespace).to receive(:duo_features_enabled).and_return(false)
        allow_any_instance_of(EE::Namespace).to receive(:auto_duo_code_review_settings_available?).and_return(false)
        allow_any_instance_of(NamespaceSetting).to receive(:require_sha_for_merge_locked?).and_return(false)
        allow_any_instance_of(NamespaceSetting).to receive(:require_sha_for_merge).and_return(false)
      end

      context 'top-level group' do
        context 'when email domain restriction does not exist' do
          context 'valid param' do
            shared_examples 'creates email domain restrictions' do
              it 'creates email domain restrictions' do
                request

                expect(response).to have_gitlab_http_status(:found)
                expect(group.reload.allowed_email_domains.domain_names).to match_array(domains.split(","))
              end
            end

            context 'single domain' do
              let(:domains) { 'gitlab.com' }

              it_behaves_like 'creates email domain restrictions'
            end

            context 'multiple domains' do
              let(:domains) { 'gitlab.com,acme.com' }

              it_behaves_like 'creates email domain restrictions'
            end
          end

          context 'invalid param' do
            let(:domains) { 'boom!' }

            it 'adds error message' do
              expect { request }
                .not_to(change { group.reload.allowed_email_domains.count }.from(0))
              expect(response).to have_gitlab_http_status(:ok)
              expect(response.body).to include('The domain you entered is misformatted')
            end
          end
        end

        context 'when email domain restrictions already exists' do
          let!(:allowed_email_domain) { create(:allowed_email_domain, group: group, domain: 'gitlab.com') }

          context 'allowed email domain param set' do
            context 'valid param' do
              shared_examples 'updates allowed email domain restrictions' do
                it 'updates allowed email domain restrictions' do
                  request

                  expect(response).to have_gitlab_http_status(:found)
                  expect(group.reload.allowed_email_domains.domain_names).to match_array(domains.split(","))
                end
              end

              context 'single domain' do
                let(:domains) { 'hey.com' }

                it_behaves_like 'updates allowed email domain restrictions'
              end

              context 'multiple domains' do
                context 'a new domain along with the existing one' do
                  let(:domains) { 'gitlab.com,hey.com' }

                  it_behaves_like 'updates allowed email domain restrictions'
                end

                context 'completely new set of domains' do
                  let(:domains) { 'hey.com,google.com' }

                  it_behaves_like 'updates allowed email domain restrictions'
                end
              end
            end

            context 'invalid param' do
              shared_examples 'does not update existing email domain restrictions' do
                it 'does not change allowed_email_domains records' do
                  expect { request }
                    .not_to(change { group.reload.allowed_email_domains.domain_names }
                      .from(['gitlab.com']))
                end

                it 'adds error message' do
                  request

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(response.body).to include('The domain you entered is misformatted')
                end
              end

              context 'not a valid domain' do
                let(:domains) { 'boom!' }

                it_behaves_like 'does not update existing email domain restrictions'
              end

              context 'multiple domains' do
                context 'any one of them being not a valid' do
                  let(:domains) { 'acme.com,boom!' }

                  it_behaves_like 'does not update existing email domain restrictions'
                end
              end
            end
          end

          context 'empty param' do
            let(:domains) { '' }

            it 'deletes all email domain restrictions' do
              expect { request }
                .to(change { group.reload.allowed_email_domains.count }.to(0))
              expect(response).to have_gitlab_http_status(:found)
            end
          end
        end
      end

      context 'subgroup' do
        let(:group) { create(:group, :nested) }
        let(:domains) { 'gitlab.com' }

        it 'does not create email domain restriction' do
          expect { request }
            .not_to change { group.reload.allowed_email_domains.count }.from(0)
          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('Allowed email domain restriction only permitted for top-level groups')
        end
      end

      context 'feature is disabled' do
        let(:domains) { 'gitlab.com' }

        before do
          stub_licensed_features(group_allowed_email_domains: false)
        end

        it 'does not create email domain restrictions' do
          expect { request }
            .not_to change { group.reload.allowed_email_domains.count }.from(0)
          expect(response).to have_gitlab_http_status(:found)
        end
      end
    end

    context 'setting enforce_ssh_certificates' do
      let(:params) { { group: { enforce_ssh_certificates: true } } }

      it 'does not change the column' do
        expect { request }.not_to change { group.reload.enforce_ssh_certificates? }
        expect(response).to have_gitlab_http_status(:found)
      end

      context 'when ssh_certificates licensed feature is available' do
        before do
          stub_licensed_features(ssh_certificates: true)
        end

        it 'successfully changes the column' do
          expect { request }.to change { group.reload.enforce_ssh_certificates? }
          expect(response).to have_gitlab_http_status(:found)
        end

        context 'when a group is not a top-level group' do
          let(:group) { create(:group, :nested) }

          it 'does not change the column' do
            expect { request }.not_to change { group.reload.enforce_ssh_certificates? }
            expect(response).to have_gitlab_http_status(:found)
          end
        end
      end
    end

    context 'when setting disable_invite_members' do
      let(:params) { { group: { disable_invite_members: true } } }

      context 'when group is a top level group' do
        context 'when user is a group owner' do
          before do
            group.add_owner(user)
          end

          it 'successfully changes the column' do
            expect { request }.to change { group.reload.disable_invite_members? }
            expect(response).to have_gitlab_http_status(:found)
          end
        end

        context 'when user is not group owner' do
          before do
            group.owners.delete(user)
            group.add_maintainer(user)
          end

          it 'does not change the column and returns not found' do
            expect { request }.not_to change { group.reload.disable_invite_members? }
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when group is not a top level group' do
        let(:group) { create(:group, :nested) }

        it 'does not change the column and returns not found' do
          expect(group.disable_invite_members?).to be(false)

          request

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.disable_invite_members?).to be(false)
        end
      end
    end

    context 'when setting the require_dpop_for_manage_api_endpoints param (default disabled)' do
      let(:params) { { group: { require_dpop_for_manage_api_endpoints: true } } }

      context 'when not group owner' do
        let(:user) { create(:user) }

        before do
          group.add_developer(user)
          login_as(user)
        end

        it 'does not change the column and returns not_found' do
          expect(group.require_dpop_for_manage_api_endpoints?).to be(false)

          request

          expect(response).to have_gitlab_http_status(:not_found)
          expect(group.reload.require_dpop_for_manage_api_endpoints?).to be(false)
        end
      end

      context 'when a group owner' do
        it 'successfully changes the column`s value' do
          expect { request }
            .to change { group.reload.require_dpop_for_manage_api_endpoints? }
            .from(false).to(true)

          expect(response).to have_gitlab_http_status(:found)
        end
      end
    end

    context 'when settings extended_grat_expiry_webhooks_execute' do
      let(:params) { { group: { extended_grat_expiry_webhooks_execute: true } } }

      context 'when licensed feature is not available' do
        before do
          stub_licensed_features(group_webhooks: false)
        end

        it 'does not change the column' do
          expect { request }.not_to change { group.reload.extended_grat_expiry_webhooks_execute? }
          expect(response).to have_gitlab_http_status(:found)
        end
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(group_webhooks: true)
        end

        it 'successfully changes the column' do
          expect { request }.to change { group.reload.extended_grat_expiry_webhooks_execute? }
          expect(response).to have_gitlab_http_status(:found)
        end
      end
    end

    context 'settings enterprise_users_extensions_marketplace_enabled' do
      let(:params) { { group: { enterprise_users_extensions_marketplace_enabled: true } } }

      before do
        stub_application_setting(vscode_extension_marketplace_enabled: true)
      end

      it 'does not change the column' do
        expect { request }.not_to change { group.reload.enterprise_users_extensions_marketplace_enabled? }
        expect(response).to have_gitlab_http_status(:found)
      end

      context 'when disable_extensions_marketplace_for_enterprise_users feature is available' do
        before do
          stub_licensed_features(disable_extensions_marketplace_for_enterprise_users: true)
        end

        it 'successfully changes the column' do
          expect { request }.to change { group.reload.enterprise_users_extensions_marketplace_enabled? }
          expect(response).to have_gitlab_http_status(:found)
        end
      end
    end

    context 'setting disable_personal_access_tokens' do
      let(:params) { { group: { disable_personal_access_tokens: true } } }

      before do
        stub_licensed_features(disable_personal_access_tokens: true)
      end

      context 'when on self-managed' do
        it 'does not change the setting' do
          expect(group.namespace_settings.disable_personal_access_tokens).to be_falsey

          request

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.namespace_settings.disable_personal_access_tokens).to be_falsy
        end
      end

      context 'when on SaaS', :saas do
        before do
          stub_saas_features(disable_personal_access_tokens: true)
        end

        it 'changes the setting' do
          expect(group.namespace_settings.disable_personal_access_tokens).to be_falsey

          request

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.namespace_settings.disable_personal_access_tokens).to be_truthy
        end
      end
    end

    context 'when setting allow_enterprise_bypass_placeholder_confirmation' do
      let(:expiry_date) { 30.days.from_now }
      let(:params) do
        {
          group: {
            allow_enterprise_bypass_placeholder_confirmation: true,
            enterprise_bypass_expires_at: expiry_date
          }
        }
      end

      before do
        group.add_owner(user)
        allow(Group).to receive(:find_by_full_path).and_return(group)
        allow(group).to receive(:domain_verification_available?).and_return(true)
      end

      it 'successfully updates the setting for top-level group owners' do
        expect { request }.to change {
          group.reload.namespace_settings.allow_enterprise_bypass_placeholder_confirmation?
        }.from(false).to(true)

        expect(group.reload.namespace_settings.enterprise_bypass_expires_at).to be_within(1.second).of(expiry_date)
        expect(response).to have_gitlab_http_status(:found)
      end

      context 'and user is not a group owner' do
        before do
          group.owners.delete(user)
          group.add_maintainer(user)
        end

        it 'does not change the setting and returns not found' do
          expect { request }.not_to change {
            group.reload.namespace_settings.allow_enterprise_bypass_placeholder_confirmation?
          }.from(false)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when domain verification is not enabled' do
        before do
          allow(group).to receive(:domain_verification_available?).and_return(false)
        end

        it 'does not change the setting' do
          expect { request }.not_to change {
            group.reload.namespace_settings.allow_enterprise_bypass_placeholder_confirmation?
          }.from(false)

          expect(response).to have_gitlab_http_status(:found)
        end
      end

      context 'when enabling bypass with invalid expiry date' do
        let(:expiry_date) { 1.day.ago }

        it 'fails validation and does not update the setting' do
          expect { request }.not_to change {
            group.reload.namespace_settings.allow_enterprise_bypass_placeholder_confirmation?
          }
        end
      end
    end

    context 'setting disable_ssh_keys' do
      let(:params) { { group: { disable_ssh_keys: true } } }

      before do
        stub_licensed_features(disable_ssh_keys: true)
      end

      context 'when on self-managed' do
        it 'does not change the setting' do
          expect(group.namespace_settings.disable_ssh_keys).to be_falsey

          request

          expect(response).to have_gitlab_http_status(:found)
          expect(group.namespace_settings.reload.disable_ssh_keys).to be_falsey
        end
      end

      context 'when on SaaS', :saas do
        before do
          stub_saas_features(disable_ssh_keys: true)
        end

        it 'changes the setting' do
          expect(group.namespace_settings.disable_ssh_keys).to be_falsey

          request

          expect(response).to have_gitlab_http_status(:found)
          expect(group.namespace_settings.reload.disable_ssh_keys).to be_truthy
        end
      end
    end

    context 'when setting hide_email_on_profile' do
      let(:params) { { group: { hide_email_on_profile: true } } }

      before do
        group.add_owner(user)
        allow(Group).to receive(:find_by_full_path).and_return(group)
        allow(group).to receive(:domain_verification_available?).and_return(true)
      end

      it 'successfully updates the setting for top-level group owners' do
        expect { request }.to change {
          group.reload.namespace_settings.hide_email_on_profile?
        }.from(false).to(true)

        expect(response).to have_gitlab_http_status(:found)
      end

      context 'and user is not a group owner' do
        before do
          group.owners.delete(user)
          group.add_maintainer(user)
        end

        it 'does not change the setting and returns not found' do
          expect { request }.not_to change {
            group.reload.namespace_settings.hide_email_on_profile?
          }.from(false)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when domain verification is not enabled' do
        before do
          allow(group).to receive(:domain_verification_available?).and_return(false)
        end

        it 'does not change the setting' do
          expect { request }.not_to change {
            group.reload.namespace_settings.hide_email_on_profile?
          }.from(false)

          expect(response).to have_gitlab_http_status(:found)
        end
      end

      context 'when group is not a root group' do
        let(:group) { create(:group, :nested) }

        it 'does not change the setting' do
          expect { request }.not_to change {
            group.reload.namespace_settings.hide_email_on_profile?
          }.from(false)

          expect(response).to have_gitlab_http_status(:found)
        end
      end
    end
  end

  describe 'PUT #transfer', :saas do
    let(:new_parent_group) { create(:group) }

    before do
      stub_feature_flags(groups_and_projects_async_transfer: false)
      group.add_owner(user)
      new_parent_group.add_owner(user)
      create(:gitlab_subscription, :ultimate, namespace: group)
      login_as(user)
    end

    it 'does not transfer a group with a gitlab saas subscription' do
      put transfer_group_path(group),
        params: { new_parent_group_id: new_parent_group.id }

      expect(response).to redirect_to(edit_group_path(group))
      expect(flash[:alert]).to include('Transfer failed')
      expect(group.reload.parent_id).to be_nil
    end

    it 'transfers a subgroup with a parent group with a gitlab saas subscription' do
      subgroup = create(:group, parent: group)

      put transfer_group_path(subgroup),
        params: { new_parent_group_id: new_parent_group.id }

      subgroup.reload
      expect(response).to redirect_to(group_path(subgroup))
      expect(flash[:alert]).to be_nil
      expect(subgroup.parent_id).to eq(new_parent_group.id)
    end
  end

  describe 'DELETE #destroy' do
    before do
      group.add_owner(user)
      login_as(user)
    end

    it 'does not delete a group with a gitlab.com subscription', :saas do
      create(:gitlab_subscription, :ultimate, namespace: group)

      expect { delete(group_path(group)) }.not_to change { group.reload.self_deletion_scheduled? }
      expect(response).to redirect_to(edit_group_path(group))
    end

    it 'deletes a subgroup with a parent group with a gitlab.com subscription', :saas do
      create(:gitlab_subscription, :ultimate, namespace: group)
      subgroup = create(:group, parent: group)

      expect { delete(group_path(subgroup)) }
        .to change { subgroup.reload.self_deletion_scheduled? }.from(false).to(true)
      expect(response).to redirect_to(dashboard_groups_path)
    end
  end
end
