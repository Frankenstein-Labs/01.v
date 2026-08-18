# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SamlProvider, feature_category: :system_access do
  let(:group) { create(:group) }

  subject(:saml_provider) { create(:saml_provider, group: group) }

  before do
    stub_licensed_features(group_saml: true)
  end

  describe "Associations" do
    it { is_expected.to belong_to :group }
    it { is_expected.to have_many :identities }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:sso_url) }
    it { is_expected.to validate_presence_of(:certificate_fingerprint) }
    it { is_expected.to validate_presence_of(:default_membership_role) }
    it { is_expected.to validate_inclusion_of(:default_membership_role).in_array([10, 20, 30, 40]) }

    context 'when SAML SSO is disabled' do
      before do
        subject.enabled = false
      end

      it { is_expected.not_to validate_presence_of(:sso_url) }
      it { is_expected.not_to validate_presence_of(:certificate_fingerprint) }
    end

    it 'expects sso_url to be an https URL' do
      expect(subject).to allow_value('https://example.com').for(:sso_url)
      expect(subject).not_to allow_value('http://example.com').for(:sso_url)
    end

    it 'prevents homoglyph phishing attacks by only allowing ascii URLs' do
      expect(subject).to allow_value('https://gitlab.com/adfs/ls').for(:sso_url)
      expect(subject).not_to allow_value('https://𝕘itⅼaƄ.ᴄοｍ/adfs/ls').for(:sso_url)
    end

    it 'allows unicode domain names when encoded as ascii punycode' do
      expect(subject).to allow_value('https://xn--gitl-ocb944a.xn--m-rmb025q/adfs/ls').for(:sso_url)
    end

    it 'expects certificate_fingerprint to be in an accepted format' do
      expect(subject).to allow_value('000030EDC285E01D6B5EA33010A79ADD142F5004').for(:certificate_fingerprint)
      expect(subject).to allow_value('00:00:30:ED:C2:85:E0:1D:6B:5E:A3:30:10:A7:9A:DD:14:2F:50:04').for(:certificate_fingerprint)
      expect(subject).to allow_value('00 00 30 ED C2 85 E0 1D 6B 5E A3 30 10 A7 9A DD 14 2F 50 04').for(:certificate_fingerprint)
      expect(subject).to allow_value('D84D439499F3FD8C2304250FD74A7BE81007D428BB95A1F9FD5642EDAE51472A').for(:certificate_fingerprint)
      expect(subject).to allow_value('3E:2E:3D:B7:83:C0:FE:11:65:F0:30:A3:8B:E6:7B:3C:01:92:36:72:02:42:62:98:F8:64:F3:62:E2:52:14:AB').for(:certificate_fingerprint)
      expect(subject).to allow_value('68 0C 5A 3F CC 4C DB 04 B1 E1 3B 81 C1 3E A3 0A 5B 29 AD 87 B5 5C 6B 71 B7 1A CD DA 2E CB BC 26').for(:certificate_fingerprint)

      too_short = '00:00:30'
      invalid_characters = '00@0030EDC285E01D6B5EA33010A79ADD142F5004'
      invalid_separator = '00-00-30-ED-C2-85-E0-1D-6B-5E-A3-30-10-A7-9A-DD-14-2F-50-04'
      sha512 = 'a12bc3d4567ef89ba97f4d1904815d56a497ffc2fe9d5b0f13439a5da73f4f1afde03b1c1b213128e173da24e75cadf224286696f5171540eedf59b684a5f8dd'
      expect(subject).not_to allow_value(too_short).for(:certificate_fingerprint)
      expect(subject).not_to allow_value(invalid_characters).for(:certificate_fingerprint)
      expect(subject).not_to allow_value(invalid_separator).for(:certificate_fingerprint)
      expect(subject).not_to allow_value(sha512).for(:certificate_fingerprint)
    end

    it 'strips left-to-right marks from certificate_fingerprint' do
      expect(subject).to allow_value("\u200E00 00 30 ED C2 85 E0 1D 6B 5E A3 30 10 A7 9A DD 14 2F 50 04‎").for(:certificate_fingerprint)
    end

    context 'for an existing record with a previously valid fingerprint' do
      before do
        previously_valid_fingerprint = '00-00-30-ED-C2-85-E0-1D-6B-5E-A3-30-10-A7-9A-DD-14-2F-50-04'
        subject.update_attribute(:certificate_fingerprint, previously_valid_fingerprint)
      end

      it 'does not validate the certificate_fingerprint format with the new logic when it is not updated' do
        expect(subject).to be_valid
      end

      it 'validates the certificate_fingerprint format with the new logic when it is updated' do
        expect(subject).not_to allow_value('00-00-30-ED-C2-85-E0-1D').for(:certificate_fingerprint)
      end
    end

    context 'for an existing record with a previously invalid fingerprint' do
      before do
        previously_valid_fingerprint = '00-00-30-ED-C2-85-E0-1D-6B-5E-A3-30-10-A7-9A'
        subject.update_attribute(:certificate_fingerprint, previously_valid_fingerprint)
      end

      it 'considers the record invalid' do
        expect(subject).to be_invalid
      end

      it 'validates the certificate_fingerprint format with the new logic when it is updated' do
        expect(subject).not_to allow_value('00-00-30-ED-C2-85-E0-1D-6B-5E-A3-30-10-A7-9A-DD').for(:certificate_fingerprint)
      end
    end

    it 'requires group to be top-level' do
      group = create(:group)
      nested_group = create(:group, :nested)

      expect(subject).to allow_value(group).for(:group)
      expect(subject).not_to allow_value(nested_group).for(:group)
    end

    describe 'access level inclusion' do
      let(:group) { create(:group) }

      context 'when minimal access user feature is switched on' do
        before do
          stub_licensed_features(minimal_access_role: true)
        end

        it 'default membership role can have access levels from minimal access to owner' do
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::NO_ACCESS)).to be_invalid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::MINIMAL_ACCESS)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::GUEST)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::REPORTER)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::DEVELOPER)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::MAINTAINER)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::OWNER)).to be_valid
        end
      end

      context 'when minimal access user feature switched off' do
        before do
          stub_licensed_features(minimal_access_role: false)
        end

        it 'default membership role can have access levels from guest to owner' do
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::NO_ACCESS)).to be_invalid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::MINIMAL_ACCESS)).to be_invalid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::GUEST)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::REPORTER)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::DEVELOPER)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::MAINTAINER)).to be_valid
          expect(build(:saml_provider, group: group, default_membership_role: ::Gitlab::Access::OWNER)).to be_valid
        end
      end
    end

    describe 'git_check_enforced' do
      let_it_be(:group) { create(:group) }

      context 'sso is enforced' do
        it 'git_check_enforced is valid' do
          expect(build(:saml_provider, group: group, enabled: true, enforced_sso: true, git_check_enforced: true)).to be_valid
          expect(build(:saml_provider, group: group, enabled: true, enforced_sso: true, git_check_enforced: false)).to be_valid
        end
      end

      context 'sso is not enforced' do
        it 'git_check_enforced is invalid when set to true' do
          expect(build(:saml_provider, group: group, enabled: true, enforced_sso: false, git_check_enforced: true)).to be_invalid
        end

        it 'git_check_enforced is valid when set to false' do
          expect(build(:saml_provider, group: group, enabled: true, enforced_sso: false, git_check_enforced: false)).to be_valid
        end
      end
    end
  end

  describe 'Default values' do
    it 'defaults enabled to true' do
      expect(subject).to be_enabled
    end
  end

  describe '#settings' do
    let(:group) { create(:group, path: 'foo-group') }
    let(:settings) { subject.settings }

    before do
      stub_default_url_options(protocol: "https")
    end

    it 'generates callback URL' do
      expect(settings[:assertion_consumer_service_url]).to eq "https://localhost/groups/foo-group/-/saml/callback"
    end

    it 'generates issuer from group' do
      expect(settings[:issuer]).to eq "https://localhost/groups/foo-group"
    end

    it 'uses unscoped URL for issuer regardless of organization context' do
      organization = create(:organization)
      stub_current_organization(organization)

      expect(settings[:issuer]).to eq "https://localhost/groups/foo-group"
      expect(settings[:issuer]).not_to include("/o/#{organization.path}")
    end

    it 'includes NameID format' do
      expect(settings[:name_identifier_format]).to start_with 'urn:oasis:names:tc:'
    end

    it 'includes fingerprint' do
      expect(settings[:idp_cert_fingerprint]).to eq saml_provider.certificate_fingerprint
    end

    it 'includes the fingerprint algorithm' do
      expect(settings[:idp_cert_fingerprint_algorithm]).to eq 'http://www.w3.org/2000/09/xmldsig#sha1'
    end

    it 'includes SSO URL' do
      expect(settings[:idp_sso_target_url]).to eq saml_provider.sso_url
    end

    it 'includes default attribute statements' do
      expect(settings[:attribute_statements]).to eq(::Gitlab::Auth::Saml::Config.default_attribute_statements)
    end

    it 'detects the SHA256 algorithm with a SHA256 fingerprint' do
      saml_provider = build(
        :saml_provider,
        group: group,
        certificate_fingerprint:
          '73:2d:28:c2:d2:d0:34:9F:F8:9a:9c:74:23:BF:0a:cb:66:75:78:9b:01:4D:1F:7D:60:8f:ad:47:a2:30:d7:4a'
      )
      settings = saml_provider.settings

      expect(settings[:idp_cert_fingerprint_algorithm]).to eq 'http://www.w3.org/2001/04/xmlenc#sha256'
    end

    context 'when saml_message_max_byte_size present in gitlab settings' do
      before do
        stub_omniauth_setting(saml_message_max_byte_size: 1_000_000)
      end

      it 'includes saml_message_max_byte_size' do
        expect(settings[:message_max_bytesize]).to eq 1_000_000
      end
    end
  end

  describe '#enforced_sso?' do
    context 'when provider is enabled' do
      before do
        subject.enabled = true
      end

      it 'matches attribute' do
        subject.enforced_sso = true
        expect(subject).to be_enforced_sso
        subject.enforced_sso = false
        expect(subject).not_to be_enforced_sso
      end

      it 'does not enforce SSO when the feature is unavailable' do
        stub_licensed_features(group_saml: false)
        subject.enforced_sso = true

        expect(subject).not_to be_enforced_sso
      end
    end

    context 'when provider is disabled' do
      before do
        subject.enabled = false
      end

      it 'ignores attribute value' do
        subject.enforced_sso = true
        expect(subject).not_to be_enforced_sso
        subject.enforced_sso = false
        expect(subject).not_to be_enforced_sso
      end
    end
  end

  describe '#enforced_group_managed_accounts?' do
    before do
      stub_feature_flags(group_managed_accounts: true)
    end

    context 'when enforced_sso is enabled' do
      before do
        subject.enabled = true
        subject.enforced_sso = true
      end

      it 'matches attribute' do
        subject.enforced_group_managed_accounts = true
        expect(subject).to be_enforced_group_managed_accounts
        subject.enforced_group_managed_accounts = false
        expect(subject).not_to be_enforced_group_managed_accounts
      end

      context 'and feature flag is disabled' do
        before do
          stub_feature_flags(group_managed_accounts: false)
        end

        it 'is false' do
          subject.enforced_group_managed_accounts = true

          expect(subject).not_to be_enforced_group_managed_accounts
        end
      end
    end

    context 'when enforced_sso is disabled' do
      before do
        subject.enabled = true
        subject.enforced_sso = false
      end

      it 'ignores attribute value' do
        subject.enforced_group_managed_accounts = true
        expect(subject).not_to be_enforced_group_managed_accounts
        subject.enforced_group_managed_accounts = false
        expect(subject).not_to be_enforced_group_managed_accounts
      end
    end
  end

  describe '#git_check_enforced?' do
    context 'without enforced sso' do
      before do
        allow(subject).to receive(:enforced_sso?).and_return(false)
      end

      it 'does not enforce git activity check' do
        subject.git_check_enforced = true
        expect(subject).not_to be_git_check_enforced
        subject.git_check_enforced = false
        expect(subject).not_to be_git_check_enforced
      end
    end

    context 'with enforced sso' do
      before do
        allow(subject).to receive(:enforced_sso?).and_return(true)
      end

      it 'enforces git activity check when attribute is set to true' do
        subject.git_check_enforced = true
        expect(subject).to be_git_check_enforced
        subject.git_check_enforced = false
        expect(subject).not_to be_git_check_enforced
      end
    end
  end

  describe '#prohibited_outer_forks?' do
    context 'without enforced GMA' do
      it 'is false when prohibited_outer_forks flag value is true' do
        subject.prohibited_outer_forks = true

        expect(subject.prohibited_outer_forks?).to be_falsey
      end

      it 'is false when prohibited_outer_forks flag value is false' do
        subject.prohibited_outer_forks = false

        expect(subject.prohibited_outer_forks?).to be_falsey
      end
    end

    context 'when enforced GMA is enabled' do
      before do
        subject.enabled = true
        subject.enforced_sso = true
        subject.enforced_group_managed_accounts = true
      end

      it 'is true when prohibited_outer_forks flag value is true' do
        subject.prohibited_outer_forks = true

        expect(subject.prohibited_outer_forks?).to be_truthy
      end

      it 'is false when prohibited_outer_forks flag value is false' do
        subject.prohibited_outer_forks = false

        expect(subject.prohibited_outer_forks?).to be_falsey
      end
    end
  end

  it_behaves_like 'model with member role relation' do
    subject(:model) { build(:saml_provider) }
  end
end
