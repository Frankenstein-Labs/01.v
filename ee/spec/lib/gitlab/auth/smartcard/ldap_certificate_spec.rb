# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Smartcard::LdapCertificate, feature_category: :system_access do
  include LdapHelpers

  let_it_be(:organization) { create(:organization) }
  let(:certificate_header) { 'certificate' }
  let(:openssl_certificate_store) { instance_double(OpenSSL::X509::Store) }
  let(:user_build_service) { instance_double(Users::BuildService) }
  let(:subject_ldap_dn_string_raw) { 'CN=subject_ldap_dn/OU=authority_department/O=authority_name' }
  let(:subject_ldap_dn_string) { 'CN=subject_ldap_dn,OU=authority_department,O=authority_name' }
  let(:reverse_subject_ldap_dn_string) { 'O=authority_name,OU=authority_department,CN=subject_ldap_dn' }
  let(:issuer_string) { 'CN=generating_tool,OU=authority_department,O=authority_name' }
  let(:reverse_issuer_string) { 'O=authority_name,OU=authority_department,CN=generating_tool' }
  let(:issuer) do
    instance_double(OpenSSL::X509::Name,
      to_s: issuer_string,
      to_a: [
        ['O', 'authority_name', 19],
        ['OU', 'authority_department', 12],
        ['CN', 'generating_tool', 12]
      ]
    )
  end

  let(:subject_ldap_dn) do
    instance_double(OpenSSL::X509::Name,
      to_a: [
        ['O', 'authority_name', 19],
        ['OU', 'authority_department', 12],
        ['CN', 'subject_ldap_dn', 12]
      ]
    ).tap do |subject_dn_double|
      allow(subject_dn_double).to receive(:to_s).and_return(subject_ldap_dn_string_raw)
      allow(subject_dn_double).to receive(:to_s).with(OpenSSL::X509::Name::RFC2253).and_return(subject_ldap_dn_string)
    end
  end

  let(:openssl_certificate) do
    instance_double(OpenSSL::X509::Certificate,
      { issuer: issuer,
        serial: 42,
        subject: subject_ldap_dn })
  end

  let(:ldap_provider) { 'ldapmain' }
  let(:ldap_connection) { instance_double(::Net::LDAP) }
  let(:ldap_person_name) { 'John Doe' }
  let(:ldap_person_email) { 'john.doe@example.com' }
  let(:ldap_entry) do
    Net::LDAP::Entry.new.tap do |entry|
      entry['dn'] = subject_ldap_dn_string
      entry['uid'] = 'john doe'
      entry['cn'] = ldap_person_name
      entry['mail'] = ldap_person_email
    end
  end

  before do
    stub_ldap_config(active_directory: false)
    allow(described_class).to(
      receive(:store).and_return(openssl_certificate_store))
    allow(OpenSSL::X509::Certificate).to(
      receive(:new).and_return(openssl_certificate))
    allow(openssl_certificate_store).to(
      receive(:verify).and_return(true))
    allow(Net::LDAP).to receive(:new).and_return(ldap_connection)
    allow(ldap_connection).to receive(:search).and_return([ldap_entry])
  end

  describe '#find_or_create_user' do
    subject(:find_or_create_user) do
      described_class.new(ldap_provider, certificate_header, organization).find_or_create_user
    end

    context 'user not found on ldap server' do
      before do
        allow(ldap_connection).to receive(:search).and_return([])
      end

      it { is_expected.to be_nil }
    end

    context 'user and smartcard ldap certificate already exists' do
      let(:user) { create(:user) }

      before do
        create(:identity, { provider: ldap_provider,
                            extern_uid: subject_ldap_dn_string,
                            user: user })
      end

      it 'finds existing user' do
        expect(find_or_create_user).to eql(user)
      end

      it 'does not create new user' do
        expect { find_or_create_user }.not_to change { User.count }
      end
    end

    context 'user exists but it is using a new ldap certificate' do
      let(:ldap_person_email) { user.email }

      let_it_be(:user) { create(:user) }

      it 'finds existing user' do
        expect(find_or_create_user).to eql(user)
      end

      it 'does create new user identity' do
        expect { find_or_create_user }.to change { user.identities.count }.by(1)
      end

      context 'user already has a different ldap certificate identity' do
        before do
          create(:identity, { provider: 'ldapmain',
                              extern_uid: 'old_subject_ldap_dn',
                              user: user })
        end

        it "doesn't create a new identity" do
          expect { find_or_create_user }.not_to change { Identity.count }
        end

        it "doesn't create a new user" do
          expect { find_or_create_user }.not_to change { User.count }
        end
      end
    end

    context 'user does not exist' do
      let(:user) { create(:user) }

      shared_examples_for 'creates user' do
        it do
          expect { find_or_create_user }.to change { User.count }.from(0).to(1)
        end
      end

      it_behaves_like 'creates user'

      context 'and ldap server is active directory' do
        let(:smartcard_ad_cert_field) { 'altSecurityIdentities' }
        let(:smartcard_ad_cert_format) { nil }

        before do
          stub_ldap_config(
            active_directory: true,
            smartcard_ad_cert_field: smartcard_ad_cert_field,
            smartcard_ad_cert_format: smartcard_ad_cert_format
          )
        end

        it 'defaults to non-active-directory LDAP-compatible behavior' do
          expect { find_or_create_user }.to change { User.count }.from(0).to(1)

          expect(ldap_connection).to have_received(:search).with(
            a_hash_including(
              filter: Net::LDAP::Filter.ex('userCertificate:certificateExactMatch',
                "{ serialNumber 42, issuer \"#{issuer_string}\" }")
            )
          ).at_least(:once)
        end

        # rubocop:disable RSpec/MultipleMemoizedHelpers -- we are testing many formats, no cleaner way to write specs
        context 'when smartcard_ad_cert_format is specified' do
          using RSpec::Parameterized::TableSyntax

          let(:issuer_and_serial_number_formatted) do
            "X509:<I>#{issuer_string}<SR>2a"
          end

          let(:reverse_issuer_and_serial_number_formatted) do
            "X509:<I>#{reverse_issuer_string}<SR>2a"
          end

          let(:principal_name) do
            "X509:<PN>#{subject_ldap_dn_string_raw}"
          end

          let(:rfc822_name) do
            "X509:<RFC822>#{subject_ldap_dn_string_raw}"
          end

          let(:issuer_and_subject_legacy_formatted) do
            "X509:<I>#{issuer_string}<S>#{subject_ldap_dn_string_raw}"
          end

          let(:issuer_and_subject_formatted) do
            "X509:<I>#{issuer_string}<S>#{subject_ldap_dn_string}"
          end

          let(:reverse_issuer_and_subject_formatted) do
            "X509:<I>#{reverse_issuer_string}<S>#{subject_ldap_dn_string}"
          end

          let(:reverse_issuer_and_subject_legacy_formatted) do
            "X509:<I>#{reverse_issuer_string}<S>#{subject_ldap_dn_string_raw}"
          end

          let(:reverse_issuer_and_reverse_subject_formatted) do
            "X509:<I>#{reverse_issuer_string}<S>#{reverse_subject_ldap_dn_string}"
          end

          let(:subject_string) do
            "X509:<S>#{subject_ldap_dn_string}"
          end

          let(:subject_string_legacy) do
            "X509:<S>#{subject_ldap_dn_string_raw}"
          end

          where(:ad_format, :result) do
            'issuer_and_serial_number'           | ref(:issuer_and_serial_number_formatted)
            'reverse_issuer_and_serial_number'   | ref(:reverse_issuer_and_serial_number_formatted)
            'principal_name'                     | ref(:principal_name)
            'rfc822_name'                        | ref(:rfc822_name)
            'issuer_and_subject'                 | ref(:issuer_and_subject_formatted)
            'reverse_issuer_and_subject'         | ref(:reverse_issuer_and_subject_formatted)
            'reverse_issuer_and_reverse_subject' | ref(:reverse_issuer_and_reverse_subject_formatted)
            'subject'                            | ref(:subject_string)
          end

          with_them do
            it do
              stub_ldap_config(
                active_directory: true,
                smartcard_ad_cert_field: smartcard_ad_cert_field,
                smartcard_ad_cert_format: ad_format
              )

              expect { find_or_create_user }.to change { User.count }.from(0).to(1)

              expect(ldap_connection).to have_received(:search).with(
                a_hash_including(
                  filter: Net::LDAP::Filter.eq(smartcard_ad_cert_field, result)
                )
              ).at_least(:once)
            end
          end
        end
        # rubocop:enable RSpec/MultipleMemoizedHelpers

        context 'with unknown cert format' do
          let(:smartcard_ad_cert_format) { 'not a real format' }

          it 'raises invalid config error' do
            expect { find_or_create_user }.to raise_error(
              _('Missing or invalid configuration field: :smartcard_ad_cert_format')
            )
          end
        end

        context 'with different cert field' do
          let(:smartcard_ad_cert_format) { 'issuer_and_serial_number' }
          let(:smartcard_ad_cert_field) { 'extensionAttribute1' }

          before do
            stub_ldap_config(
              active_directory: true,
              smartcard_ad_cert_field: smartcard_ad_cert_field,
              smartcard_ad_cert_format: smartcard_ad_cert_format
            )
          end

          it 'searches using the specified field' do
            expect { find_or_create_user }.to change { User.count }.from(0).to(1)

            expect(ldap_connection).to have_received(:search).with(
              a_hash_including(
                filter: Net::LDAP::Filter.eq(smartcard_ad_cert_field, "X509:<I>#{issuer_string}<SR>2a")
              )
            ).at_least(:once)
          end
        end
      end

      context 'when the current minimum password length is different from the default minimum password length' do
        before do
          stub_application_setting minimum_password_length: 21
        end

        it_behaves_like 'creates user'
      end

      it 'creates user with correct attributes' do
        find_or_create_user

        user = User.find_by(username: 'johndoe')

        expect(user).not_to be_nil
        expect(user.email).to eql(ldap_person_email)
        expect(user.namespace.organization).to eq(organization)
      end

      it 'creates identity' do
        expect { find_or_create_user }.to change { Identity.count }.from(0).to(1)
      end

      it 'creates identity with correct attributes' do
        find_or_create_user

        identity = Identity.find_by(provider: ldap_provider, extern_uid: subject_ldap_dn_string.downcase)

        expect(identity).not_to be_nil
      end

      it 'calls Users::BuildService with correct params' do
        user_params = { name: ldap_person_name,
                        username: 'johndoe',
                        email: ldap_person_email,
                        extern_uid: subject_ldap_dn_string.downcase,
                        provider: ldap_provider,
                        password_automatically_set: true,
                        skip_confirmation: true }

        expect(Users::AuthorizedBuildService).to(
          receive(:new)
            .with(nil, hash_including(user_params))
            .and_return(user_build_service))
        expect(user_build_service).to(
          receive(:execute).and_return(user))

        find_or_create_user
      end

      context 'username generation' do
        context 'uses LDAP uid' do
          it 'creates user with correct username' do
            find_or_create_user

            user = User.find_by(username: 'johndoe')
            expect(user).not_to be_nil
          end
        end

        context 'avoids conflicting namespaces' do
          let!(:existing_user) { create(:user, username: 'johndoe') }

          it 'creates user with correct username' do
            expect { find_or_create_user }.to change { User.count }.from(1).to(2)
            expect(User.last.username).to eql('johndoe1')
          end
        end
      end
    end

    it_behaves_like 'a valid certificate is required'
  end

  it_behaves_like 'a certificate store'
end
