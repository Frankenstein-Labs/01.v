# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::IdentityLinker, feature_category: :system_access do
  let_it_be_with_reload(:user) { create(:user, can_create_group: true, projects_limit: 10) }
  let(:provider) { 'group_saml' }
  let(:uid) { user.email }
  let(:in_response_to) { '12345' }
  let(:saml_response) { instance_double(OneLogin::RubySaml::Response, in_response_to: in_response_to) }
  let_it_be(:saml_provider) { create(:saml_provider) }
  let_it_be(:group) { saml_provider.group }
  let(:session) { {} }
  let(:raw_info_attributes) { { 'can_create_group' => %w[false], 'projects_limit' => %w[20] } }
  let(:oauth) do
    OmniAuth::AuthHash.new(
      provider: provider,
      uid: uid,
      info: { email: user.email },
      extra: {
        response_object: saml_response,
        raw_info: OneLogin::RubySaml::Attributes.new(raw_info_attributes)
      }
    )
  end

  subject(:identity_linker) { described_class.new(user, oauth, session, saml_provider) }

  context 'when a linked identity exists' do
    let(:extern_uid) { uid }
    let!(:identity) do
      user.identities.create!(provider: provider, extern_uid: extern_uid, saml_provider: saml_provider)
    end

    # Issue: https://gitlab.com/gitlab-org/gitlab/-/work_items/602226
    context 'for enterprise user attributes update' do
      context 'when the user is managed by the group', :saas do
        before do
          stub_licensed_features(domain_verification: true)
          user.user_detail.update!(enterprise_group: group)
        end

        it 'updates the user attributes', :aggregate_failures do
          expect { identity_linker.link }
            .to change { user.reload.can_create_group }.from(true).to(false)
            .and change { user.reload.projects_limit }.from(10).to(20)
        end

        context 'when the user attributes are not present in the SAML response' do
          let(:raw_info_attributes) { {} }

          it 'does not change the user attributes', :aggregate_failures do
            expect { identity_linker.link }
              .to not_change { user.can_create_group }.from(true)
              .and not_change { user.projects_limit }.from(10)
          end
        end
      end

      context 'when the user is not managed by the group' do
        it 'does not change the user attributes', :aggregate_failures do
          expect { identity_linker.link }
            .to not_change { user.can_create_group }.from(true)
            .and not_change { user.projects_limit }.from(10)
        end
      end
    end

    context 'when identity has untrusted extern_uid' do
      before do
        identity.update_column(:trusted_extern_uid, false)
      end

      it 're-trusts the identity after linking' do
        expect { identity_linker.link }.to change { identity.reload.trusted_extern_uid }.from(false).to(true)
      end
    end

    context 'with user onboarding' do
      before do
        stub_saas_features(onboarding: true)
        user.update!(onboarding_in_progress: true)
      end

      it 'finishes user onboarding' do
        expect { identity_linker.link }.to change { user.reload.onboarding_in_progress }.to(false)
      end

      context 'when linking fails' do
        before do
          allow(identity_linker).to receive(:failed?).and_return(true)
        end

        it 'does not finish user onboarding' do
          expect { identity_linker.link }.not_to change { user.reload.onboarding_in_progress }
        end
      end
    end

    context 'when the extern_uid matches' do
      it "doesn't create new identity" do
        expect { identity_linker.link }.not_to change { Identity.count }
      end

      it "sets #changed? to false" do
        identity_linker.link

        expect(identity_linker).not_to be_changed
      end

      it 'adds user to group' do
        identity_linker.link

        expect(saml_provider.group.member?(user)).to be(true)
      end

      it 'calls Duo assignment updater' do
        expect(::Gitlab::Auth::GroupSaml::DuoAddOnAssignmentUpdater)
          .to receive(:new).with(user, saml_provider.group, anything).and_call_original

        identity_linker.link
      end
    end

    context 'when the extern_uid does not match' do
      let(:audit_event) { AuditEventReader.last.details[:custom_message] }
      let_it_be(:extern_uid) { 'ioKaiph5' }

      before do
        stub_licensed_features(admin_audit_log: true)
      end

      it 'updates the identity when the email address matches' do
        expect(identity.extern_uid).to eq(extern_uid)

        identity_linker.link

        expect(identity.reload.extern_uid).to eq(uid)
        expect(identity_linker.failed?).to be(false)
        expect(identity_linker.error_message).to be_empty
        expect(audit_event).to eq("Updated extern_uid from #{extern_uid} to #{uid}")
      end

      it 'does not update the identity when the email address does not match', :aggregate_failures do
        oauth.info.email = generate(:email)

        identity_linker.link

        expect(identity.reload.extern_uid).to eq(extern_uid)
        expect(identity_linker.failed?).to be(true)
        expect(identity_linker.error_message)
          .to eq(
            s_('GroupSAML|SAML Name ID and email address do not match your user account. Contact an administrator.')
          )
        expect(audit_event).to eq("Failed to update extern_uid from #{extern_uid} to #{uid}")
      end

      context 'when identity is untrusted (re-link flow after admin remap)' do
        before do
          identity.update_column(:trusted_extern_uid, false)
        end

        it 'restores trust when the link succeeds', :aggregate_failures do
          identity_linker.link

          expect(identity_linker.failed?).to be(false)
          expect(identity.reload.extern_uid).to eq(uid)
          expect(identity.reload.trusted_extern_uid).to be(true)
        end

        it 'keeps identity untrusted when the email does not match', :aggregate_failures do
          oauth.info.email = generate(:email)

          identity_linker.link

          expect(identity_linker.failed?).to be(true)
          expect(identity.reload.extern_uid).to eq(extern_uid)
          expect(identity.reload.trusted_extern_uid).to be(false)
        end

        it 'keeps identity untrusted when the new extern_uid is already taken', :aggregate_failures do
          saml_provider.identities.create!(provider: provider, extern_uid: uid, user: create(:user))

          identity_linker.link

          expect(identity_linker.failed?).to be(true)
          expect(identity.reload.extern_uid).to eq(extern_uid)
          expect(identity.reload.trusted_extern_uid).to be(false)
        end
      end

      context 'when the extern_uid is already taken' do
        before do
          saml_provider.identities.create!(provider: provider, extern_uid: uid, user: create(:user))
        end

        it 'fails and does not update the identity', :aggregate_failures do
          identity_linker.link

          expect(identity.reload.extern_uid).to eq(extern_uid)
          expect(identity_linker.failed?).to be(true)
          expect(identity_linker.error_message).to eq("Extern uid has already been taken. " \
            "Please contact your administrator to generate a unique extern_uid / NameID")
          expect(audit_event).to eq("Failed to update extern_uid from #{extern_uid} to #{uid}")
        end
      end
    end
  end

  context 'identity needs to be created' do
    context 'with identity provider initiated request' do
      it 'attempting to link accounts raises an exception' do
        expect { identity_linker.link }.to raise_error(Gitlab::Auth::Saml::IdentityLinker::UnverifiedRequest)
      end
    end

    context 'with valid gitlab initiated request' do
      let(:session) { { 'last_authn_request_id' => in_response_to } }

      it 'creates linked identity' do
        expect { identity_linker.link }.to change { user.identities.count }
      end

      it 'sets identity provider' do
        identity_linker.link

        expect(user.identities.last.provider).to eq provider
      end

      it 'sets saml provider' do
        identity_linker.link

        expect(user.identities.last.saml_provider).to eq saml_provider
      end

      it 'sets identity extern_uid' do
        identity_linker.link

        expect(user.identities.last.extern_uid).to eq uid
      end

      it 'sets #changed? to true' do
        identity_linker.link

        expect(identity_linker).to be_changed
      end

      it 'adds user to group' do
        identity_linker.link

        expect(saml_provider.group.member?(user)).to be(true)
      end
    end
  end
end
