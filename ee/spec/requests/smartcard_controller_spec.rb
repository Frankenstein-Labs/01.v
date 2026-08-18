# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SmartcardController, :with_current_organization, type: :request, feature_category: :system_access do
  include LdapHelpers

  let_it_be(:organization) { current_organization }
  let(:smartcard_host) { 'smartcard.example.com' }
  let(:smartcard_port) { 3443 }

  describe '#auth' do
    let(:params) { {} }

    subject { post auth_smartcard_path, params: params }

    before do
      stub_smartcard_config(
        client_certificate_required_host: smartcard_host,
        client_certificate_required_port: smartcard_port
      )
    end

    context 'with smartcard_auth enabled' do
      before do
        enable_smartcard_authentication
      end

      it 'redirects to extract certificate' do
        subject

        expect(response).to have_gitlab_http_status(:redirect)
        expect(response.location).to(
          eq(extract_certificate_smartcard_url(host: smartcard_host, port: smartcard_port))
        )
      end

      context 'with provider param' do
        let(:provider) { 'ldap-provider' }
        let(:params) { { provider: provider } }

        it 'forwards the provider param' do
          subject

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response.location).to(
            eq(extract_certificate_smartcard_url(host: smartcard_host, port: smartcard_port, provider: provider))
          )
        end
      end
    end

    context 'with smartcard_auth disabled' do
      before do
        allow(Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(false)
      end

      it 'renders 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe '#extract_certificate', :freeze_time do
    let(:certificate) { 'certificate' }
    let(:random_str) { SecureRandom.urlsafe_base64(12) }
    let(:nonce) do
      Gitlab::Utils.ensure_utf8_size(random_str, bytes: 12.bytes)
    end

    let(:encrypted_certificate) do
      timestamped_cert = "#{certificate}#{described_class::CERT_SEPARATOR}#{Time.now.utc.to_i}"
      encrypted_cert = Gitlab::CryptoHelper.aes256_gcm_encrypt(timestamped_cert, nonce: nonce)
      CGI.escape(encrypted_cert)
    end

    let(:headers) { {} }
    let(:params) { {} }

    subject do
      get(extract_certificate_smartcard_path, headers: headers, params: params)
    end

    before do
      stub_config_setting(host: 'example.com', port: 443)
      stub_smartcard_config(
        client_certificate_required_host: smartcard_host,
        client_certificate_required_port: smartcard_port
      )

      allow(SecureRandom).to(receive(:urlsafe_base64).and_return(random_str))

      host! "#{smartcard_host}:#{smartcard_port}"
    end

    context 'with smartcard_auth enabled' do
      before do
        enable_smartcard_authentication
      end

      shared_examples 'verify smartcard' do
        it 'redirects to verify certificate' do
          subject

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response.location).to(eq(verify_certificate_smartcard_url(
            host: ::Gitlab.config.gitlab.host,
            port: ::Gitlab.config.gitlab.port,
            client_certificate: encrypted_certificate,
            nonce: nonce
          )))
        end

        context 'with provider param' do
          let(:provider) { 'ldap-provider' }
          let(:params) { { provider: provider } }

          it 'forwards the provider param' do
            subject

            expect(response).to have_gitlab_http_status(:redirect)
            expect(response.location).to(eq(verify_certificate_smartcard_url(
              host: ::Gitlab.config.gitlab.host,
              port: ::Gitlab.config.gitlab.port,
              client_certificate: encrypted_certificate,
              nonce: nonce,
              provider: provider
            )))
          end
        end
      end

      context 'NGINX header' do
        let(:headers) { { 'X-SSL-CLIENT-CERTIFICATE': certificate } }

        it_behaves_like 'verify smartcard'
      end

      context 'Envoy XFCC header' do
        let(:headers) { { 'X-FORWARDED-CLIENT-CERT': "Cert=\"#{certificate}\";" } }

        it_behaves_like 'verify smartcard'
      end

      context 'missing client certificate header' do
        let(:headers) { {} }

        it 'renders unauthorized' do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'request from different host / port' do
        it 'renders 404' do
          host! 'another.host:42'

          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'with smartcard_auth disabled' do
      before do
        allow(Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(false)
      end

      it 'renders 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe '#verify_certificate' do
    shared_examples 'a client certificate authentication' do |auth_method|
      context 'with smartcard_auth enabled' do
        it 'allows sign in' do
          subject

          expect(request.env['warden']).to be_authenticated
        end

        it 'redirects to root' do
          subject

          expect(response).to redirect_to(root_url)
        end

        it 'logs audit event' do
          # Creating a confirmed user also creates an email corresponding to the user primary email
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
            name: "email_created"
          })).and_call_original

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
            name: "smartcard_authentication_created",
            author: instance_of(User),
            scope: instance_of(User),
            target: instance_of(User),
            message: "User authenticated with smartcard",
            additional_details: { with: auth_method, ip_address: '127.0.0.1' }
          })).and_call_original

          subject
        end

        it 'stores active session' do
          session_enforcer = instance_double(Gitlab::Auth::Smartcard::SessionEnforcer)

          expect(::Gitlab::Auth::Smartcard::SessionEnforcer).to(
            receive(:new).and_return(session_enforcer))
          expect(session_enforcer).to receive(:update_session)

          subject
        end

        context 'user does not exist' do
          context 'signup allowed' do
            it 'creates user' do
              expect { subject }.to change { User.count }.from(0).to(1)
            end
          end

          context 'signup disabled' do
            it 'renders 401' do
              allow(Gitlab::CurrentSettings.current_application_settings).to(
                receive(:allow_signup?).and_return(false))

              subject

              expect(flash[:alert]).to eql('Failed to sign in using smart card authentication.')
              expect(response).to redirect_to(new_user_session_path)
              expect(request.env['warden']).not_to be_authenticated
            end
          end
        end

        context 'missing client certificate param' do
          let(:params) { {} }

          it 'renders unauthorized' do
            subject

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(request.env['warden']).not_to be_authenticated
          end
        end

        context 'when timestamp of certificate param is expired' do
          let(:login_timestamp) { (Time.now.utc - described_class::LOGIN_CUTOFF_LIMIT).to_i }

          it 'renders unauthorized' do
            subject

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(request.env['warden']).not_to be_authenticated
          end
        end

        context 'when timestamp of certificate param is in the future' do
          let(:login_timestamp) { (Time.now.utc + 1.minute).to_i }

          it 'renders unauthorized' do
            subject

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(request.env['warden']).not_to be_authenticated
          end
        end
      end

      context 'with smartcard_auth disabled' do
        before do
          allow(Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(false)
        end

        it 'renders 404' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    let(:client_certificate) { 'certificate' }
    let(:random_str) { SecureRandom.urlsafe_base64(12) }
    let(:nonce) do
      Gitlab::Utils.ensure_utf8_size(random_str, bytes: 12.bytes)
    end

    let(:login_timestamp) { Time.now.utc.to_i }
    let(:encrypted_client_certificate) do
      timestamped_cert = "#{client_certificate}#{described_class::CERT_SEPARATOR}#{login_timestamp}"
      encrypted_cert = Gitlab::CryptoHelper.aes256_gcm_encrypt(timestamped_cert, nonce: nonce)
      CGI.escape(encrypted_cert)
    end

    let(:params) { { client_certificate: encrypted_client_certificate, nonce: nonce } }
    let(:serial) { 42 }
    let(:subject_dn) { '/O=Random Corp Ltd/CN=gitlab-user/emailAddress=gitlab-user@random-corp.org' }
    let(:issuer_dn) { 'CN=Random Corp,O=Random Corp Ltd,C=US' }

    before do
      enable_smartcard_authentication
      stub_certificate_store
      stub_certificate
    end

    context 'Smartcard::Certificate' do
      subject { get verify_certificate_smartcard_path, params: params }

      it_behaves_like 'a client certificate authentication', 'smartcard'

      context 'user already exists' do
        before do
          user = create(:user)
          create(:smartcard_identity, subject: subject_dn, issuer: issuer_dn, user: user)
        end

        it 'finds existing user' do
          expect { subject }.not_to change { User.count }
          expect(request.env['warden']).to be_authenticated
        end
      end

      context 'certificate header formats from NGINX' do
        shared_examples 'valid certificate header' do
          it 'authenticates user' do
            expect(Gitlab::Auth::Smartcard::Certificate).to receive(:new).with(expected_certificate, current_organization).and_call_original

            subject

            expect(request.env['warden']).to be_authenticated
          end
        end

        let(:expected_certificate) { "-----BEGIN CERTIFICATE-----\nrow\nrow\n-----END CERTIFICATE-----" }

        context 'escaped format' do
          let(:client_certificate) { '-----BEGIN%20CERTIFICATE-----%0Arow%0Arow%0A-----END%20CERTIFICATE-----' }

          it_behaves_like 'valid certificate header'
        end

        context 'deprecated format' do
          let(:client_certificate) { '-----BEGIN CERTIFICATE----- row row -----END CERTIFICATE-----' }

          it_behaves_like 'valid certificate header'
        end
      end
    end

    context 'Smartcard::LdapCertificate' do
      let(:ldap_connection) { instance_double(::Net::LDAP) }
      let(:subject_ldap_dn) { 'uid=john doe,ou=people,dc=example,dc=com' }
      let(:ldap_email) { 'john.doe@example.com' }
      let(:ldap_entry) do
        Net::LDAP::Entry.new.tap do |entry|
          entry['dn'] = subject_ldap_dn
          entry['uid'] = 'john doe'
          entry['cn'] = 'John Doe'
          entry['mail'] = ldap_email
        end
      end

      let(:ldap_user_search_scope) { 'dc=example,dc=com' }
      let(:ldap_search_params) do
        { attributes: array_including('dn', 'cn', 'mail', 'uid', 'userid'),
          base: ldap_user_search_scope,
          filter: Net::LDAP::Filter.ex(
            'userCertificate:certificateExactMatch',
            "{ serialNumber #{serial}, issuer \"#{issuer_dn}\" }") }
      end

      subject(:verify_smartcard) do
        get(verify_certificate_smartcard_path, params: params.merge({ provider: 'ldapmain' }))
      end

      before do
        stub_ldap_config(active_directory: false)
        allow(Net::LDAP).to receive(:new).and_return(ldap_connection)
        allow(ldap_connection).to(
          receive(:search).with(ldap_search_params).and_return([ldap_entry]))
      end

      it_behaves_like 'a client certificate authentication', 'smartcard_ldap'

      it 'sets correct parameters for LDAP search' do
        expect(ldap_connection).to(
          receive(:search).with(ldap_search_params).and_return([ldap_entry]))

        verify_smartcard
      end

      context 'when ldap is an active directory server' do
        let(:ldap_search_params) do
          {
            attributes: array_including('dn', 'cn', 'mail', 'uid', 'userid'),
            base: ldap_user_search_scope,
            filter: Net::LDAP::Filter.eq('altSecurityIdentities', "X509:<I>#{issuer_dn}<SR>2a")
          }
        end

        before do
          stub_ldap_config(
            active_directory: true,
            smartcard_ad_cert_field: 'altSecurityIdentities',
            smartcard_ad_cert_format: 'issuer_and_serial_number'
          )
        end

        it 'sets correct parameters for LDAP search' do
          expect(ldap_connection).to(
            receive(:search).with(ldap_search_params).and_return([ldap_entry]))

          verify_smartcard
        end
      end

      context 'user already exists' do
        let_it_be(:user) { create(:user) }

        it 'finds existing user' do
          create(:identity, { provider: 'ldapmain',
                              extern_uid: subject_ldap_dn,
                              user: user })

          expect { verify_smartcard }.not_to change { User.count }

          expect(request.env['warden']).to be_authenticated
        end

        context 'user has a different identity' do
          let(:ldap_email) { user.email }

          before do
            create(:identity, { provider: 'ldapmain',
                                extern_uid: 'different_identity_dn',
                                user: user })
          end

          it "doesn't login a user" do
            verify_smartcard

            expect(request.env['warden']).not_to be_authenticated
          end

          it "doesn't create a new user entry either" do
            expect { verify_smartcard }.not_to change { User.count }
          end
        end
      end

      context 'when user is not found on LDAP server' do
        before do
          allow(ldap_connection).to(
            receive(:search).with(ldap_search_params).and_return([])
          )
        end

        it 'does not create new user' do
          expect { verify_smartcard }.not_to change { User.count }
        end
      end
    end
  end

  def enable_smartcard_authentication
    allow(Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(true)
  end

  def stub_smartcard_config(smartcard_settings)
    allow(::Gitlab.config.smartcard).to(receive_messages(smartcard_settings))
  end

  def stub_certificate_store
    openssl_certificate_store = instance_double(OpenSSL::X509::Store)
    allow(Gitlab::Auth::Smartcard::Base).to receive(:store).and_return(openssl_certificate_store)
    allow(openssl_certificate_store).to receive(:verify).and_return(true)
  end

  def stub_certificate
    issuer = instance_double(OpenSSL::X509::Name, to_s: issuer_dn)
    openssl_certificate = instance_double(OpenSSL::X509::Certificate, subject: subject_dn, issuer: issuer, serial: serial)
    allow(OpenSSL::X509::Certificate).to receive(:new).and_return(openssl_certificate)
  end
end
