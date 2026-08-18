# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SshCertificates::VerifySignatureService, feature_category: :source_code_management do
  let_it_be(:ca_key) do
    SSHData::PrivateKey::RSA.generate(
      ::Gitlab::SSHPublicKey.supported_sizes(:rsa).min, unsafe_allow_small_key: true
    )
  end

  let_it_be_with_refind(:ssh_certificate) { create(:group_ssh_certificate, key: ca_key.public_key.openssh) }
  let_it_be_with_refind(:group) { ssh_certificate.group }
  let_it_be_with_refind(:user) { create(:enterprise_user, enterprise_group: group, developer_of: group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }

  let(:signature) do
    SSHData::Signature.parse_pem(
      <<~SIG
      -----BEGIN SSH SIGNATURE-----
      U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAgdnw0cScIikLiaei34FHG/ov5+r
      5Oc3UKCxGsdYuZ/BsAAAADZ2l0AAAAAAAAAAZzaGE1MTIAAABTAAAAC3NzaC1lZDI1NTE5
      AAAAQDWOEauf0jXyA9caa5bOgK5QZD6c69pm+EbG3GMw5QBL3N/Gt+r413McCSJFohWWBk
      Lxemg8NzZ0nB7lTFbaxQc=
      -----END SSH SIGNATURE-----
      SIG
    )
  end

  let(:committer_email) { user.email }
  let(:certificate) { signature.public_key }
  let(:service) { described_class.new(project, committer_email, certificate) }

  before do
    stub_licensed_features(ssh_certificates: true)
  end

  context 'when the public key of a signature is not a certificate' do
    it 'returns empty status' do
      expect(service.execute).to be_nil
    end

    context 'when ssh certificates are enforced' do
      it 'returns unverified status' do
        group.namespace_settings.update!(enforce_ssh_certificates: true)
        project.reload

        expect(service.execute).to eq(:unverified)
      end
    end
  end

  context 'when the public key of a signature is a certificate' do
    let(:certificate) { SSHData::Certificate.new(public_key: signature.public_key, key_id: user.username) }

    before do
      # Set ca_key value of the certificate
      certificate.sign(ca_key)
    end

    it 'returns verified_ca status' do
      expect(service.execute).to eq(:verified_ca)
    end

    context 'when ca and user was not successfully found' do
      it 'returns empty status' do
        stub_licensed_features(ssh_certificates: false)

        expect(service.execute).to be_nil
      end
    end

    context 'when a project is not within the group namespace' do
      let_it_be_with_refind(:project) { create(:project, :in_group) }

      it 'returns empty status' do
        expect(service.execute).to be_nil
      end
    end

    context 'when another group has the same CA but the project belongs to a different group' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_user) { create(:enterprise_user, enterprise_group: other_group, developer_of: other_group) }
      let_it_be(:other_certificate) do
        create(:group_ssh_certificate, group: other_group, key: ca_key.public_key.openssh)
      end

      let_it_be_with_refind(:other_project) { create(:project, group: other_group) }

      let(:certificate) { SSHData::Certificate.new(public_key: signature.public_key, key_id: other_user.username) }
      let(:service) { described_class.new(other_project, other_user.email, certificate) }

      it 'only matches the certificate for the project root namespace' do
        expect(service.execute).to eq(:verified_ca)
      end
    end

    context 'when committer email is not a verified email of the user' do
      let(:committer_email) { 'does-not-exist@example.com' }

      it 'returns empty status' do
        expect(service.execute).to be_nil
      end
    end

    context 'when a certificate is certificate is expired' do
      let(:certificate) do
        SSHData::Certificate.new(
          public_key: signature.public_key,
          key_id: user.username,
          valid_before: 1.day.ago
        )
      end

      it 'returns empty status' do
        expect(service.execute).to be_nil
      end
    end

    context 'when the certificate is not valid' do
      it 'returns empty status' do
        # Modify the data of certificate to invalidate the signature
        certificate.instance_variable_set(:@valid_before, 1.day.after)

        expect(service.execute).to be_nil
      end
    end
  end
end
