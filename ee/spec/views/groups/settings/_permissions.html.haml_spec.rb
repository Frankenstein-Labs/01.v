# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_permissions.html.haml', :aggregate_failures, :saas, feature_category: :code_suggestions do
  let_it_be(:group) { build(:group, namespace_settings: build(:namespace_settings)) }

  before do
    assign(:group, group)
    allow(view).to receive(:can?).and_return(true)
    allow(view).to receive(:current_user).and_return(build(:user))
  end

  context 'for extended token expiry webhook execution setting' do
    let_it_be(:checkbox_label) { s_('GroupSettings|Add additional webhook triggers for group access token expiration') }

    before do
      allow(group).to receive(:licensed_feature_available?).and_return(true)
    end

    context 'when `group_webhooks` licensed feature is not available' do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:group_webhooks).and_return(false)
      end

      it 'renders nothing', :aggregate_failures do
        render

        expect(rendered).to render_template('groups/settings/_extended_grat_expiry_webhook_execute')
        expect(rendered).not_to have_content(
          s_('GroupSettings|Add additional webhook triggers for group access token expiration')
        )
      end
    end

    context 'when `group_webhooks` licensed feature is available' do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:group_webhooks).and_return(true)
      end

      it 'renders checkbox', :aggregate_failures do
        render

        expect(rendered).to render_template('groups/settings/_extended_grat_expiry_webhook_execute')
        expect(rendered).to have_content(
          s_('GroupSettings|Add additional webhook triggers for group access token expiration')
        )
        expect(rendered).to have_unchecked_field(checkbox_label, type: 'checkbox')
      end
    end
  end

  context 'for enterprise users section' do
    let_it_be(:section_title) { s_('GroupSettings|Enterprise users') }
    let_it_be(:section_description) do
      s_('GroupSettings|Settings that apply only to enterprise users associated with this group.')
    end

    context 'when group is not root' do
      before do
        allow(group).to receive(:root?).and_return(false)
      end

      it 'does not render enterprise users section' do
        render

        expect(rendered).not_to have_content(section_title)
        expect(rendered).not_to have_content(section_description)
      end
    end

    context 'when domain verification is not available' do
      before do
        allow(group).to receive(:root?).and_return(true)
        allow(group).to receive(:domain_verification_available?).and_return(false)
      end

      it 'does not render enterprise users section' do
        render

        expect(rendered).not_to have_content(section_title)
        expect(rendered).not_to have_content(section_description)
      end
    end

    context 'when user does not have read_enterprise_user permission' do
      before do
        allow(group).to receive(:root?).and_return(true)
        allow(group).to receive(:domain_verification_available?).and_return(true)
        allow(view).to receive(:can?).with(anything, :read_enterprise_user, group).and_return(false)
      end

      it 'does not render enterprise users section' do
        render

        expect(rendered).not_to have_content(section_title)
        expect(rendered).not_to have_content(section_description)
      end
    end

    context 'when all conditions are met' do
      before do
        allow(group).to receive(:enterprise_user_settings_available?).and_return(true)
      end

      it 'renders enterprise users section with description' do
        render

        expect(rendered).to have_content(section_title)
        expect(rendered).to have_content(section_description)
      end

      it 'renders enterprise user partials' do
        render

        expect(rendered).to render_template('groups/settings/_enterprise_users_pats')
        expect(rendered).to render_template('groups/settings/_hide_email_on_profile')
        expect(rendered).to render_template('groups/settings/_extensions_marketplace')
      end

      context 'when extensions marketplace can be managed' do
        before do
          allow(group).to receive(:can_manage_extensions_marketplace_for_enterprise_users?).and_return(true)
        end

        it 'renders extensions marketplace checkbox' do
          render

          expect(rendered).to have_unchecked_field(s_('GroupSettings|Enable extension marketplace'), type: 'checkbox')
        end
      end

      context 'when extensions marketplace cannot be managed' do
        before do
          allow(group).to receive(:can_manage_extensions_marketplace_for_enterprise_users?).and_return(false)
        end

        it 'does not render extensions marketplace checkbox' do
          render

          expect(rendered).not_to have_field(s_('GroupSettings|Enable extension marketplace'), type: 'checkbox')
        end
      end

      context 'when enterprise user account deletion can be configured' do
        before do
          allow(group).to receive(:can_configure_enterprise_user_account_deletion?).and_return(true)
          stub_feature_flags(deleting_account_disabled_for_enterprise_users: group)
        end

        shared_examples 'with :allow_enterprise_user_account_deletion UI text' do |checked|
          it "renders label, help text, and a #{checked ? 'checked' : 'unchecked'} checkbox" do
            render

            expect(rendered).to have_field(
              s_('GroupSettings|Allow enterprise users to delete their own accounts'),
              type: 'checkbox',
              checked: checked
            )
            expect(rendered).to have_content(
              s_(
                'GroupSettings|When disabled, enterprise users in this group ' \
                  'cannot delete their own accounts.'
              )
            )
          end
        end

        context 'when allow_enterprise_user_account_deletion? is true' do
          before do
            allow(group.namespace_settings).to receive(:allow_enterprise_user_account_deletion?).and_return(true)
          end

          it_behaves_like 'with :allow_enterprise_user_account_deletion UI text', true
        end

        context 'when allow_enterprise_user_account_deletion? is false' do
          before do
            allow(group.namespace_settings).to receive(:allow_enterprise_user_account_deletion?).and_return(false)
          end

          it_behaves_like 'with :allow_enterprise_user_account_deletion UI text', false
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(deleting_account_disabled_for_enterprise_users: false)
          end

          it 'does not render the checkbox and UI texts' do
            render

            expect(rendered).not_to have_field(
              s_('GroupSettings|Allow account self-deletion by enterprise users'),
              type: 'checkbox'
            )

            expect(rendered).not_to have_content(
              s_(
                'GroupSettings|When disabled, enterprise users in this group ' \
                  'cannot delete their own accounts.'
              )
            )
          end
        end
      end
    end
  end

  context 'for secret manager section' do
    before do
      allow(group).to receive(:licensed_feature_available?).and_return(true)
    end

    context 'when feature flag is disabled' do
      before do
        # The view also renders for the enrollment toggle when
        # `allow_secrets_manager_namespace_enrollment?` is true on SaaS.
        # Disable both flags to assert the "fully hidden" state.
        stub_feature_flags(group_secrets_manager: false, secrets_manager_namespace_enrollment: false)
      end

      it 'does not render secret manager settings' do
        render

        expect(rendered).not_to have_css('.js-group-secrets-manager-settings')
      end
    end

    context 'when licensed feature is not available' do
      before do
        stub_feature_flags(group_secrets_manager: true)
        allow(group).to receive(:licensed_feature_available?)
          .with(:native_secrets_management).and_return(false)
      end

      it 'does not render secret manager settings' do
        render

        expect(rendered).not_to have_css('.js-group-secrets-manager-settings')
      end
    end

    context 'when feature flag is enabled and licensed' do
      before do
        stub_feature_flags(group_secrets_manager: true)
        allow(group).to receive(:licensed_feature_available?)
          .with(:native_secrets_management).and_return(true)
      end

      it 'renders secret manager settings' do
        render

        expect(rendered).to have_css('.js-group-secrets-manager-settings')
      end
    end
  end

  context 'for MCP client access checkbox' do
    before do
      allow(group).to receive(:mcp_server_setting_available?).and_return(true)
    end

    context 'when mcp_server_enabled? is true' do
      before do
        allow(group).to receive(:mcp_server_enabled?).and_return(true)
      end

      it 'renders the checkbox as checked' do
        render

        expect(rendered).to have_checked_field(
          s_('GroupSettings|Allow connection to GitLab'),
          type: 'checkbox'
        )
      end
    end

    context 'when mcp_server_enabled? is false' do
      before do
        allow(group).to receive(:mcp_server_enabled?).and_return(false)
      end

      it 'renders the checkbox as unchecked' do
        render

        expect(rendered).to have_unchecked_field(
          s_('GroupSettings|Allow connection to GitLab'),
          type: 'checkbox'
        )
      end
    end
  end
end
