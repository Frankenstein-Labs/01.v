# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ssh::Signature, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }

  let(:commit) { project.commit }
  let(:signed_text) { 'This message was signed by an ssh key' }
  let(:signer) { :SIGNER_USER }

  let(:signature_text) do
    # ssh-keygen -Y sign -n git -f id_test-cert.pub message.txt
    <<~SIG
      -----BEGIN SSH SIGNATURE-----
      U1NIU0lHAAAAAQAAAb0AAAAgc3NoLWVkMjU1MTktY2VydC12MDFAb3BlbnNzaC5jb20AAA
      AgWbXlnjWbxTzOlRPcnSMlQQnnJTCsEv2y2ij5o7yVbcUAAAAgYAsBVqgfGrvGdSPjqY0H
      t8yljpOS4VumZHnAh+wCvdEAAAAAAAAAAAAAAAEAAAARYWRtaW5AZXhhbXBsZS5jb20AAA
      AAAAAAAGV9kqgAAAAAZX7kiwAAAAAAAACCAAAAFXBlcm1pdC1YMTEtZm9yd2FyZGluZwAA
      AAAAAAAXcGVybWl0LWFnZW50LWZvcndhcmRpbmcAAAAAAAAAFnBlcm1pdC1wb3J0LWZvcn
      dhcmRpbmcAAAAAAAAACnBlcm1pdC1wdHkAAAAAAAAADnBlcm1pdC11c2VyLXJjAAAAAAAA
      AAAAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIINudhvW7P4c36bBwlWTaxnCCOaSfMrUbXHcP7
      7zH6LyAAAAUwAAAAtzc2gtZWQyNTUxOQAAAEBp9J9YQhaz+tNIKtNpZe5sAxcqvMgcYlB+
      fVaDsYNOj445Bz7TBoFqjrs95yaF6pwARK11IEQTcwtrihLGzGkNAAAAA2dpdAAAAAAAAA
      AGc2hhNTEyAAAAUwAAAAtzc2gtZWQyNTUxOQAAAECfVh7AzwqRBMbnHBApCnMpu9Y1qpGM
      sOSL1EeV3SIOlrThNTCerUpcaizcSY9L8WwP2TXlqw2Sq1BGM+PPSN0C
      -----END SSH SIGNATURE-----
    SIG
  end

  subject(:signature) do
    described_class.new(signature_text, signed_text, signer, commit)
  end

  before do
    allow_next_instance_of(::Groups::SshCertificates::VerifySignatureService) do |service|
      allow(service).to receive(:execute).and_return(verification_status)
    end
  end

  context 'when the signature is verified as an ssh certificate' do
    let(:verification_status) { :verified_ca }

    it 'returns the status calculated in the service' do
      expect(signature.verification_status).to eq(:verified_ca)
    end
  end

  context 'when the signature is not verified as an ssh certificate' do
    let(:verification_status) { nil }

    it 'calls the original status' do
      expect(signature.verification_status).to eq(:unknown_key)
    end
  end
end
