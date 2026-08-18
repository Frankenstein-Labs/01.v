# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/credentials_inventory/personal_access_tokens/_personal_access_token.html.haml', feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be(:expiry_date) { 20.days.since }
  let_it_be(:personal_access_token) { build_stubbed(:personal_access_token, user: user, expires_at: expiry_date) }

  let(:granular_tokens_feature_flag) { true }

  before do
    freeze_time
    stub_feature_flags(granular_personal_access_tokens: granular_tokens_feature_flag)

    allow(view).to receive_messages(
      user_detail_path: 'abcd',
      personal_access_token_revoke_path: 'revoke',
      resource_access_token_revoke_path: 'revoke',
      current_user: user
    )

    render 'shared/credentials_inventory/personal_access_tokens/personal_access_token', personal_access_token: personal_access_token
  end

  after do
    unfreeze_time
  end

  it 'shows the users name' do
    expect(rendered).to have_text(user.name)
  end

  it 'shows the created on date' do
    expect(rendered).to have_text(personal_access_token.created_at.to_date.to_s)
  end

  it 'shows the expiry date' do
    expect(rendered).to have_text(personal_access_token.expires_at.to_date.to_s)
  end

  context 'revoked date' do
    let_it_be(:updated_at_date) { 10.days.ago }

    context 'when revoked is set' do
      let_it_be(:personal_access_token) { build_stubbed(:personal_access_token, user: user, updated_at: updated_at_date, revoked: true) }

      it 'shows the revoked on date' do
        expect(rendered).to have_text(updated_at_date.to_date.to_s)
      end

      it 'does not show the revoke button' do
        expect(rendered).not_to have_css('a.btn', text: 'Revoke')
      end
    end

    context 'when revoked is not set' do
      let_it_be(:personal_access_token) { build_stubbed(:personal_access_token, user: user, updated_at: updated_at_date) }

      it 'does not show the revoked on date' do
        expect(rendered).not_to have_text(updated_at_date.to_date.to_s)
      end

      it 'shows the revoke button' do
        expect(rendered).to have_css('a.btn', text: 'Revoke')
      end
    end
  end

  context 'scopes' do
    context 'when set' do
      let_it_be(:scopes) { %w[api read_user read_api] }
      let_it_be(:personal_access_token) { build_stubbed(:personal_access_token, user: user, scopes: scopes) }

      it 'shows the scopes' do
        expect(rendered).to have_text(_('Scope'))
        expect(rendered).to have_text('api, read_user, read_api')
      end
    end

    context 'when not set' do
      let_it_be(:personal_access_token) { build_stubbed(:personal_access_token, user: user, scopes: []) }

      it 'shows no scopes message' do
        expect(rendered).to have_text(_('Scope'))
        expect(rendered).to have_text(_('No Scopes'))
      end
    end

    context 'when the token is granular' do
      let_it_be(:project) { create(:project) }

      let_it_be(:boundary) { Authz::Boundary.for(project) }
      let_it_be(:permission) { :read_member_role }

      let_it_be(:personal_access_token) { create(:granular_pat, user: user, boundary: boundary, permissions: permission) }

      it 'shows the granular scopes' do
        expect(rendered).to have_content(s_('AccessTokens|Permissions:'))
        expect(rendered).to have_content(permission)
      end

      it 'shows the revoke button' do
        expect(rendered).to have_css('a.btn', text: 'Revoke')
      end

      context 'when the granular scope has a namespace' do
        it 'shows namespace name' do
          expect(rendered).to have_text(s_('AccessTokens|Access:'))
          expect(rendered).to have_text(project.name)
        end
      end

      context 'when the granular scope does not have a namespace' do
        let_it_be(:personal_access_token) { create(:granular_pat, user: user, boundary: Authz::Boundary.for(:user), permissions: permission) }

        it 'shows access' do
          expect(rendered).to have_text(s_('AccessTokens|Access:'))
          expect(rendered).to have_text('user')
        end
      end

      context 'when there are no granular scopes' do
        let_it_be(:personal_access_token) { create(:granular_pat) }

        it 'shows no scopes message' do
          expect(rendered).to have_text(_('No Scopes'))
        end

        it 'does not show permissions or access' do
          expect(rendered).not_to have_text(s_('AccessTokens|Permissions:'))
          expect(rendered).not_to have_text(s_('AccessTokens|Access:'))
        end
      end

      context 'when `granular_personal_access_tokens` feature flag is disabled for the token owner' do
        let_it_be(:other_user) { create(:user) }
        let_it_be(:personal_access_token) { create(:granular_pat, user: other_user, boundary: boundary, permissions: permission) }

        # feature flag is enabled only for current_user (user), not for the token owner (other_user)
        let(:granular_tokens_feature_flag) { user }

        it 'shows inactive warning' do
          expect(rendered).to have_text(
            s_('AccessTokens|Inactive: Requires the granular_personal_access_tokens feature flag.')
          )
        end

        it 'does not show the revoke button' do
          expect(rendered).not_to have_css('a.btn', text: 'Revoke')
        end
      end
    end
  end
end
