# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::Packages::Setting, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  describe 'relationships' do
    it { is_expected.to belong_to(:project).inverse_of(:dependency_proxy_packages_setting) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }

    context 'for maven registry url' do
      # Use 172.21.11.1 (from the rarely-used 172.16.0.0/12 range)
      # to avoid matching a developer's machine IP and getting classified
      # as "localhost" instead of "local network" by the URL blocker
      where(:url, :valid, :error_message) do
        'http://test.maven'   | true  | nil
        'https://test.maven'  | true  | nil
        'git://test.maven'    | false | 'Maven external registry url is blocked: Only allowed schemes are http, https'
        nil                   | false | 'At least one field of ' \
                                        '["maven_external_registry_url", "npm_external_registry_url"] must be present'
        ''                    | false | 'At least one field of ' \
                                        '["maven_external_registry_url", "npm_external_registry_url"] must be present'
        "http://#{'a' * 255}" | false | 'Maven external registry url is too long (maximum is 255 characters)'
        'http://127.0.0.1'    | false | 'Maven external registry url is blocked: Requests to localhost are not allowed'
        'maven.local'         | false | 'Maven external registry url is blocked: Only allowed schemes are http, https'
        'http://172.21.11.1'  | false | 'Maven external registry url is blocked: Requests to the local network are ' \
                                        'not allowed'
      end

      with_them do
        let(:setting) { build(:dependency_proxy_packages_setting, :maven, maven_external_registry_url: url) }

        if params[:valid]
          it { expect(setting).to be_valid }
        else
          it 'is invalid with the expected error' do
            expect(setting).not_to be_valid
            expect(setting.errors).to contain_exactly(error_message)
          end
        end
      end
    end

    context 'for maven credentials' do
      where(:username, :password, :valid, :error_message) do
        'user'      | 'password'  | true  | nil
        ''          | ''          | true  | nil
        {}          | {}          | true  | nil
        ''          | nil         | true  | nil
        nil         | ''          | true  | nil
        nil         | 'password'  | false | "Maven external registry username can't be blank"
        'user'      | nil         | false | "Maven external registry password can't be blank"
        ''          | 'password'  | false | "Maven external registry username can't be blank"
        'user'      | ''          | false | "Maven external registry password can't be blank"
        ('a' * 256) | 'password'  | false | 'Maven external registry username is too long (maximum is 255 characters)'
        'user'      | ('a' * 256) | false | 'Maven external registry password is too long (maximum is 255 characters)'
      end

      with_them do
        let(:setting) do
          build(
            :dependency_proxy_packages_setting,
            :maven,
            maven_external_registry_username: username,
            maven_external_registry_password: password
          )
        end

        if params[:valid]
          it { expect(setting.save).to be_truthy }
        else
          it do
            expect(setting.save).to be_falsey
            expect(setting.errors).to contain_exactly(error_message)
          end
        end
      end
    end

    context 'for npm registry url' do
      # Use 172.21.11.1 (from the rarely-used 172.16.0.0/12 range)
      # to avoid matching a developer's machine IP and getting classified
      # as "localhost" instead of "local network" by the URL blocker
      where(:url, :valid, :error_message) do
        'http://test.npm'     | true  | nil
        'https://test.npm'    | true  | nil
        'git://test.npm'      | false | 'Npm external registry url is blocked: Only allowed schemes are http, https'
        nil                   | false | 'At least one field of ' \
                                        '["maven_external_registry_url", "npm_external_registry_url"] must be present'
        ''                    | false | 'At least one field of ' \
                                        '["maven_external_registry_url", "npm_external_registry_url"] must be present'
        "http://#{'a' * 255}" | false | 'Npm external registry url is too long (maximum is 255 characters)'
        'http://127.0.0.1'    | false | 'Npm external registry url is blocked: Requests to localhost are not allowed'
        'maven.local'         | false | 'Npm external registry url is blocked: Only allowed schemes are http, https'
        'http://172.21.11.1'  | false | 'Npm external registry url is blocked: Requests to the local network are ' \
                                        'not allowed'
      end

      with_them do
        let(:setting) { build(:dependency_proxy_packages_setting, :npm, npm_external_registry_url: url) }

        if params[:valid]
          it { expect(setting).to be_valid }
        else
          it 'is invalid with the expected error' do
            expect(setting).not_to be_valid
            expect(setting.errors).to contain_exactly(error_message)
          end
        end
      end
    end

    context 'for npm credentials' do
      where(:basic_auth, :auth_token, :valid, :error_message) do
        'auth'      | 'auth'      | false | 'Npm external registry basic auth ' \
                                            "and auth token can't be set at the same time"
        nil         | nil         | true  | nil
        ''          | ''          | true  | nil
        {}          | {}          | true  | nil
        ''          | nil         | true  | nil
        nil         | ''          | true  | nil
        nil         | 'auth'      | true  | nil
        'auth'      | nil         | true  | nil
        ''          | 'auth'      | true  | nil
        'auth'      | ''          | true  | nil
        ('a' * 256) | nil         | false | 'Npm external registry basic auth is too long (maximum is 255 characters)'
        nil         | ('a' * 256) | false | 'Npm external registry auth token is too long (maximum is 255 characters)'
      end

      with_them do
        let(:setting) do
          build(
            :dependency_proxy_packages_setting,
            :npm,
            npm_external_registry_basic_auth: basic_auth,
            npm_external_registry_auth_token: auth_token
          )
        end

        if params[:valid]
          it { expect(setting.save).to be_truthy }
        else
          it do
            expect(setting.save).to be_falsey
            expect(setting.errors).to contain_exactly(error_message)
          end
        end
      end
    end
  end

  context 'when maven_external_registry_url is updated' do
    where(:new_url, :new_user, :new_pwd, :expected_user, :expected_pwd) do
      'http://original_url.test' | 'test' | 'test' | 'test' | 'test'
      'http://update_url.test'   | 'test' | 'test' | 'test' | 'test'
      'http://update_url.test'   | :none  | :none  | nil    | nil
      'http://update_url.test'   | 'test' | :none  | nil    | nil
      'http://update_url.test'   | :none  | 'test' | nil    | nil
    end

    with_them do
      let(:setting) do
        create(:dependency_proxy_packages_setting, :maven,
          maven_external_registry_url: 'http://original_url.test',
          maven_external_registry_username: 'original_user',
          maven_external_registry_password: 'original_pwd'
        )
      end

      it 'resets the username and the password when necessary' do
        new_attributes = {
          maven_external_registry_url: new_url,
          maven_external_registry_username: new_user,
          maven_external_registry_password: new_pwd
        }.select { |_, v| v != :none }
        setting.update!(new_attributes)

        expect(setting.reload).to have_attributes(
          maven_external_registry_url: new_url,
          maven_external_registry_username: expected_user,
          maven_external_registry_password: expected_pwd
        )
      end
    end
  end

  describe '.enabled' do
    let_it_be(:enabled_setting) { create(:dependency_proxy_packages_setting) }
    let_it_be(:disabled_setting) { create(:dependency_proxy_packages_setting, :disabled) }

    subject { described_class.enabled }

    it { is_expected.to contain_exactly(enabled_setting) }
  end

  describe '#url_from_maven_upstream' do
    let(:setting) { build_stubbed(:dependency_proxy_packages_setting, :maven) }

    subject { setting.url_from_maven_upstream(path: 'path', file_name: 'file.pom') }

    it { is_expected.to eq('http://local.test/maven/path/file.pom') }

    context 'when maven_external_registry_url ends with a slash' do
      let(:setting) { super().tap { |s| s.maven_external_registry_url = 'http://local.test/maven/' } }

      it { is_expected.to eq('http://local.test/maven/path/file.pom') }
    end
  end

  describe '#headers_from_maven_upstream' do
    let(:setting) do
      build_stubbed(
        :dependency_proxy_packages_setting,
        :maven,
        maven_external_registry_username: nil,
        maven_external_registry_password: nil
      )
    end

    subject { setting.headers_from_maven_upstream }

    it { is_expected.to eq({}) }

    context 'with username and password set' do
      let(:setting) do
        super().tap do |s|
          s.maven_external_registry_username = 'user'
          s.maven_external_registry_password = 'password'
        end
      end

      let(:expected_authorization) do
        ActionController::HttpAuthentication::Basic.encode_credentials('user', 'password')
      end

      it { is_expected.to eq(Authorization: expected_authorization) }
    end
  end
end
