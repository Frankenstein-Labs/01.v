# frozen_string_literal: true

RSpec.shared_examples 'base SamlProvider service' do
  let(:params) do
    {
      sso_url: 'https://test',
      certificate_fingerprint: fingerprint,
      enabled: true,
      enforced_sso: true
    }
  end

  let(:fingerprint) { '11:22:33:44:55:66:77:88:99:11:22:33:44:55:66:77:88:99:AA:BB' }

  before do
    stub_licensed_features(group_saml: true)
  end

  it 'updates SAML provider with given params' do
    expect(::Gitlab::Audit::Auditor)
      .to receive(:audit).with(
        hash_including(
          { name: audit_event_name,
            author: current_user,
            scope: group,
            target: group })
      ).exactly(4).times.and_call_original

    expect do
      service.execute
      group.reload
    end.to change { group.saml_provider&.sso_url }.to('https://test')
             .and change { group.saml_provider&.certificate_fingerprint }.to(fingerprint)
             .and change { group.saml_provider&.enabled? }.to(true)
             .and change { group.saml_provider&.enforced_sso? }.to(true)
             .and change { AuditEventReader.count }.by(4)

    audit_event_messages = [
      %r{enabled changed([\w\s]*)to true},
      %r{certificate_fingerprint changed([\w\W\s]*)to #{fingerprint}},
      %r{sso_url changed([\w\W\s]*)to https:\/\/test},
      %r{enforced_sso changed([\w\s]*)to true}
    ]

    audit_events = AuditEventReader.last(4)

    audit_event_messages.each_with_index do |expected_message, index|
      expect(audit_events[index].details[:custom_message]).to match(expected_message)
    end
  end

  context 'when a `member_role_id` parameter is provided' do
    let(:member_role) { create(:member_role, namespace: group) }
    let(:params) { super().merge(member_role_id: member_role.id) }

    context 'when custom roles are not enabled' do
      it 'does not update the `member_role`' do
        expect { service.execute }.not_to change { group.reload.saml_provider&.member_role }

        audit_event_details = AuditEventReader.last(2).pluck(:details)
        expect(audit_event_details).not_to include(hash_including(custom_message: /default_membership_role changed/))
        expect(audit_event_details).not_to include(hash_including(custom_message: /member_role_id changed/))
      end
    end

    context 'when custom roles are enabled' do
      before do
        stub_licensed_features(group_saml: true, custom_roles: true)
      end

      it 'updates the `default_membership_role` and the `member_role`' do
        expect do
          service.execute
          group.reload
        end.to change { group.saml_provider&.default_membership_role }.to(member_role.base_access_level)
          .and change { group.saml_provider&.member_role }.to(member_role)

        audit_event_details = AuditEventReader.last(2).pluck(:details)
        expect(audit_event_details).to include(hash_including(custom_message: /default_membership_role changed([\w\s]*)to 30/))
        expect(audit_event_details).to include(hash_including(custom_message: /member_role_id changed([\w\s]*)to #{member_role.id}/))
      end
    end
  end
end

RSpec.shared_examples 'SamlProvider service toggles Group Managed Accounts' do
  context 'when enabling enforced_group_managed_accounts' do
    let(:params) do
      attributes_for(:saml_provider, :enforced_group_managed_accounts)
    end

    before do
      create(:group_saml_identity, user: current_user, saml_provider: saml_provider)
    end

    it 'updates enforced_group_managed_accounts boolean' do
      expect do
        service.execute
        group.reload
      end.to change { group.saml_provider&.enforced_group_managed_accounts? }.to(true)
    end

    context 'when owner has not linked SAML yet' do
      before do
        Identity.delete_all
      end

      it 'adds an error warning that the owner must first link SAML' do
        service.execute

        expect(service.saml_provider.errors[:base]).to eq(["Group Owner must have signed in with SAML before enabling Group Managed Accounts"])
      end
    end
  end
end

RSpec.shared_examples 'SamlProvider service toggles Password authentication for Enterprise users' do
  context 'when enabling disable_password_authentication_for_enterprise_users' do
    let(:params) do
      attributes_for(:saml_provider, disable_password_authentication_for_enterprise_users: true)
    end

    it 'updates disable_password_authentication_for_enterprise_users boolean to true' do
      expect do
        service.execute
        group.reload
      end.to change { group.saml_provider&.disable_password_authentication_for_enterprise_users }.to(true)

      expect(AuditEventReader.last.details[:custom_message]).to match(/disable_password_authentication_for_enterprise_users changed([\w\s]*)to true/)
    end
  end

  context 'when disabling disable_password_authentication_for_enterprise_users' do
    before do
      group.saml_provider.update!(disable_password_authentication_for_enterprise_users: true)
    end

    let(:params) do
      attributes_for(:saml_provider, disable_password_authentication_for_enterprise_users: false)
    end

    it 'updates disable_password_authentication_for_enterprise_users boolean to false' do
      expect do
        service.execute
        group.reload
      end.to change { group.saml_provider&.disable_password_authentication_for_enterprise_users }.to(false)

      expect(AuditEventReader.last.details[:custom_message]).to match(/disable_password_authentication_for_enterprise_users changed([\w\s]*)to false/)
    end
  end
end
