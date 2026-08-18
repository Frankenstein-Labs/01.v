# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Upstream, type: :model, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  subject(:upstream) { build(:virtual_registries_packages_maven_upstream) }

  it_behaves_like 'it has loose foreign keys' do
    let(:factory_name) { :virtual_registries_packages_maven_upstream }
  end

  describe 'associations' do
    it 'has many cache entries' do
      is_expected.to have_many(:cache_entries)
        .class_name('VirtualRegistries::Packages::Maven::Cache::Remote::Entry')
        .inverse_of(:upstream)
    end

    it 'has many registry upstreams' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::RegistryUpstream')
        .inverse_of(:upstream)
        .autosave(true)
    end

    it 'has many registries' do
      is_expected.to have_many(:registries)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::Registry')
    end

    it 'has many rules' do
      is_expected.to have_many(:rules)
        .class_name('VirtualRegistries::Packages::Maven::Upstream::Rule')
        .inverse_of(:remote_upstream)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_length_of(:url).is_at_most(255) }
    it { is_expected.to validate_length_of(:username).is_at_most(2048) }
    it { is_expected.to validate_length_of(:password).is_at_most(2048) }
    it { is_expected.to validate_numericality_of(:cache_validity_hours).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:metadata_cache_validity_hours).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }

    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_presence_of(:password) }

    context 'for remote upstream' do
      # Use 172.21.11.1 (from the rarely-used 172.16.0.0/12 range)
      # to avoid matching a developer's machine IP and getting classified
      # as "localhost" instead of "local network" by the URL blocker
      context 'for url' do
        where(:url, :valid, :error_messages) do
          'http://test.maven'   | true  | nil
          'https://test.maven'  | true  | nil
          'git://test.maven'    | false | ['Url is blocked: Only allowed schemes are http, https']
          nil                   | false | ["Url can't be blank", 'Url must be a valid URL']
          ''                    | false | ["Url can't be blank", 'Url must be a valid URL']
          "http://#{'a' * 255}" | false | 'Url is too long (maximum is 255 characters)'
          'http://127.0.0.1'    | false | 'Url is blocked: Requests to localhost are not allowed'
          'maven.local'         | false | 'Url is blocked: Only allowed schemes are http, https'
          'http://172.21.11.1'  | false | 'Url is blocked: Requests to the local network are not allowed'
          'http://foobar.x'     | false | 'Url is blocked: Host cannot be resolved or invalid'
        end

        with_them do
          before do
            upstream.url = url
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it 'is invalid with the expected error' do
              is_expected.to be_invalid
              expect(upstream.errors).to match_array(Array.wrap(error_messages))
            end
          end
        end

        context 'for normalization' do
          where(:url_to_set, :expected_url) do
            'http://test.maven'                 | 'http://test.maven'
            'http://test.maven/'                | 'http://test.maven'
            'http://test.maven//'               | 'http://test.maven'
            'http://test.maven/path'            | 'http://test.maven/path'
            'http://test.maven/path/'           | 'http://test.maven/path'
            'https://REPO.MAVEN.ORG/maven2'     | 'https://repo.maven.org/maven2'
            'https://repo.maven.org:443/maven2' | 'https://repo.maven.org/maven2'
            'http://repo.maven.org:80/maven2'   | 'http://repo.maven.org/maven2'
            'https://repo.maven.org:8443/maven2' | 'https://repo.maven.org:8443/maven2'
            '  https://repo.maven.org/maven2  ' | 'https://repo.maven.org/maven2'
            'https://repo.maven.org/maven2.git' | 'https://repo.maven.org/maven2'
            'https://repo.maven.org/maven2.git/' | 'https://repo.maven.org/maven2'
            'https://repo.maven.org/maven2/.git' | 'https://repo.maven.org/maven2'
            'https://repo.maven.org/maven2/.git/' | 'https://repo.maven.org/maven2'
            'https://repo.maven.org/.git' | 'https://repo.maven.org'
            'https://REPO.MAVEN.ORG:443/maven2/.git' | 'https://repo.maven.org/maven2'
          end

          with_them do
            before do
              upstream.url = url_to_set
            end

            it { is_expected.to be_valid.and have_attributes(url: expected_url) }
          end

          context 'with invalid URL' do
            it 'logs warning and keeps original URL' do
              invalid_url = 'http://[invalid'
              upstream.url = invalid_url

              expect(Gitlab::AppLogger).to receive(:warn).with(
                hash_including(message: 'Failed to normalize upstream URL')
              )

              upstream.valid?

              expect(upstream.url).to eq(invalid_url)
            end
          end

          context 'with IPv6 URL' do
            it 'handles IPv6 URLs correctly' do
              upstream.url = 'https://[2001:db8::1]:443/maven2'
              upstream.valid?

              expect(upstream.url).to eq('https://[2001:db8::1]/maven2')
            end
          end

          context 'with .git in middle of path' do
            it 'does not strip .git from middle of path' do
              upstream.url = 'https://repo.maven.org/path.git/subpath'
              upstream.valid?

              expect(upstream.url).to eq('https://repo.maven.org/path.git/subpath')
            end
          end

          context 'with userinfo in URL' do
            it 'preserves userinfo while normalizing host' do
              upstream.url = 'https://myuser:mypass@EXAMPLE.COM:443/maven2/'
              upstream.valid?

              expect(upstream.url).to eq('https://myuser:mypass@example.com/maven2')
            end
          end

          context 'when creating upstreams with same URL but different trailing slashes' do
            let_it_be(:group) { create(:group) }

            it 'prevents duplicate upstreams with trailing slash' do
              create(:virtual_registries_packages_maven_upstream, url: 'http://test.maven', group: group)

              duplicate = build(:virtual_registries_packages_maven_upstream, url: 'http://test.maven/', group: group)

              expect(duplicate).to be_invalid.and have_attributes(
                errors: match_array(Array.wrap(
                  'Group already has a remote upstream with the same url and credentials'
                )),
                url: 'http://test.maven'
              )
            end
          end
        end
      end

      context 'for credentials' do
        context 'with new records' do
          where(:username, :password, :valid, :error_message) do
            'user' | 'password' | true | nil
            ''          | ''           | true  | nil
            ''          | nil          | true  | nil
            nil         | ''           | true  | nil
            nil         | 'password'   | false | "Username can't be blank"
            'user'      | nil          | false | "Password can't be blank"
            ''          | 'password'   | false | "Username can't be blank"
            'user'      | ''           | false | "Password can't be blank"
            ('a' * 2049) | 'password'    | false | 'Username is too long (maximum is 2048 characters)'
            'user'       | ('a' * 2049)  | false | 'Password is too long (maximum is 2048 characters)'
          end

          with_them do
            before do
              upstream.assign_attributes(username:, password:)
            end

            if params[:valid]
              it { is_expected.to be_valid }
            else
              it { is_expected.to be_invalid.and have_attributes(errors: match_array(Array.wrap(error_message))) }
            end
          end
        end

        context 'with existing records' do
          where(:username, :password, :update_name, :valid, :error_message) do
            'new_username'      | 'new_password' | false | true  | nil
            'new_username'      | nil            | false | false | "Password can't be blank"
            'new_username'      | ''             | false | false | "Password can't be blank"
            ''                  | 'new_password' | false | false | "Username can't be blank"
            nil                 | 'new_password' | false | false | "Username can't be blank"
            'existing_username' | ''             | false | true  | nil
            'existing_username' | ''             | true  | true  | nil
            'existing_username' | nil            | true  | true  | nil
          end

          with_them do
            before do
              upstream.update!(
                username: 'existing_username',
                password: 'existing_password'
              )

              upstream.name = 'new name' if update_name

              upstream.assign_attributes(username:, password:)
            end

            if params[:valid]
              it { is_expected.to be_valid }
            else
              it { is_expected.to be_invalid.and have_attributes(errors: match_array(Array.wrap(error_message))) }
            end
          end
        end

        context 'when url is updated' do
          where(:new_url, :new_user, :new_pwd, :expected_user, :expected_pwd) do
            'http://original_url.test' | 'test' | 'test' | 'test' | 'test'
            'http://update_url.test'   | 'test' | 'test' | 'test' | 'test'
            'http://update_url.test'   | :none  | :none  | nil    | nil
            'http://update_url.test'   | 'test' | :none  | nil    | nil
            'http://update_url.test'   | :none  | 'test' | nil    | nil
          end

          with_them do
            before do
              upstream.update!(url: 'http://original_url.test', username: 'original_user', password: 'original_pwd')
            end

            it 'resets the username and the password when necessary' do
              new_attributes = { url: new_url, username: new_user, password: new_pwd }.select { |_, v| v != :none }
              upstream.update!(new_attributes)

              expect(upstream.reload).to have_attributes(
                url: new_url,
                username: expected_user,
                password: expected_pwd
              )
            end
          end
        end
      end
    end

    describe '#credentials_uniqueness_for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:existing_upstream) do
        create(
          :virtual_registries_packages_maven_upstream,
          group: group,
          url: 'https://example.com',
          username: 'user',
          password: 'pass'
        )
      end

      where(:test_group, :url, :username, :password, :valid, :description) do
        ref(:group)  | 'https://example.com'   | 'user'      | 'pass'      | false | 'same group, same credentials'
        ref(:group)  | 'https://example.com'   | 'user'      | 'different' | true  | 'same group, different password'
        ref(:group)  | 'https://example.com'   | 'different' | 'pass'      | true  | 'same group, different username'
        ref(:group)  | 'https://different.com' | 'user'      | 'pass'      | true  | 'same group, different URL'
        ref(:group2) | 'https://example.com'   | 'user'      | 'pass'      | true  | 'different group, same credentials'
      end

      with_them do
        context 'when creating new upstream' do
          subject(:new_upstream) do
            build(
              :virtual_registries_packages_maven_upstream,
              group: test_group,
              url: url,
              username: username,
              password: password
            )
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              is_expected.to be_invalid
                .and have_attributes(errors: match_array(["Group #{described_class::SAME_URL_AND_CREDENTIALS_ERROR}"]))
            end
          end
        end

        context 'when updating existing upstream' do
          let_it_be(:updated_upstream, freeze: false) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: group,
              url: 'https://example2.com',
              username: 'user',
              password: 'pass'
            )
          end

          subject { updated_upstream }

          before do
            updated_upstream.assign_attributes(
              group: test_group,
              url: url,
              username: username,
              password: password
            )
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when updating to #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              is_expected.to be_invalid
                .and have_attributes(
                  errors: match_array(['Group already has a remote upstream with the same url and credentials'])
                )
            end
          end
        end
      end

      context 'with URL normalization edge cases' do
        context 'when protocol differs (http vs https)' do
          let_it_be(:protocol_group) { create(:group) }
          let_it_be(:https_upstream) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: protocol_group,
              url: 'https://example.com/protocol-test',
              username: 'user',
              password: 'pass'
            )
          end

          it 'treats http variant as duplicate with same credentials' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: protocol_group,
              url: 'http://example.com/protocol-test',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end

          it 'allows http variant with different credentials' do
            different_creds = build(
              :virtual_registries_packages_maven_upstream,
              group: protocol_group,
              url: 'http://example.com/protocol-test',
              username: 'different_user',
              password: 'different_pass'
            )

            expect(different_creds).to be_valid
          end
        end

        context 'when URL has case differences in hostname' do
          let_it_be(:case_group) { create(:group) }
          let_it_be(:lowercase_upstream) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: case_group,
              url: 'https://example.com/case-test',
              username: 'user',
              password: 'pass'
            )
          end

          it 'treats uppercase hostname as duplicate' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: case_group,
              url: 'https://EXAMPLE.COM/case-test',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end
        end

        context 'when URL has default port specified' do
          let_it_be(:port_group) { create(:group) }
          let_it_be(:no_port_upstream) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: port_group,
              url: 'https://example.com/port-test',
              username: 'user',
              password: 'pass'
            )
          end

          it 'treats explicit port 443 as duplicate for https' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: port_group,
              url: 'https://example.com:443/port-test',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end

          it 'allows non-default port as different upstream' do
            different_port = build(
              :virtual_registries_packages_maven_upstream,
              group: port_group,
              url: 'https://example.com:8443/port-test',
              username: 'user',
              password: 'pass'
            )

            expect(different_port).to be_valid
          end
        end

        context 'when URL has trailing .git suffix' do
          let_it_be(:git_group) { create(:group) }
          let_it_be(:base_upstream) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: git_group,
              url: 'https://example.com/git-test',
              username: 'user',
              password: 'pass'
            )
          end

          it 'treats URL with .git suffix as duplicate' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: git_group,
              url: 'https://example.com/git-test.git',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end

          it 'treats URL with .git/ suffix as duplicate' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: git_group,
              url: 'https://example.com/git-test.git/',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end

          it 'treats URL with /.git suffix as duplicate' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: git_group,
              url: 'https://example.com/git-test/.git',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end

          it 'treats URL with /.git/ suffix as duplicate' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: git_group,
              url: 'https://example.com/git-test/.git/',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end
        end

        context 'when updating an upstream to match another' do
          let_it_be(:update_group) { create(:group) }
          let_it_be(:target_upstream) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: update_group,
              url: 'https://example.com/update-test',
              username: 'user',
              password: 'pass'
            )
          end

          let(:upstream_to_update) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: update_group,
              url: 'https://example2.com/other-path',
              username: 'user',
              password: 'pass'
            )
          end

          it 'prevents update to duplicate URL with same credentials' do
            upstream_to_update.url = 'https://example.com/update-test'

            expect(upstream_to_update).to be_invalid
            expect(upstream_to_update.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end

          it 'prevents update to protocol variant of existing URL' do
            upstream_to_update.url = 'http://example.com/update-test'

            expect(upstream_to_update).to be_invalid
            expect(upstream_to_update.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end
        end

        context 'with multiple normalizations needed' do
          let_it_be(:multi_group) { create(:group) }
          let_it_be(:normalized_upstream) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: multi_group,
              url: 'https://example.com/multi-test',
              username: 'user',
              password: 'pass'
            )
          end

          it 'treats URL with case, port, and .git differences as duplicate' do
            duplicate = build(
              :virtual_registries_packages_maven_upstream,
              group: multi_group,
              url: 'https://EXAMPLE.COM:443/multi-test/.git/',
              username: 'user',
              password: 'pass'
            )

            expect(duplicate).to be_invalid
            expect(duplicate.errors[:group]).to include(described_class::SAME_URL_AND_CREDENTIALS_ERROR)
          end
        end
      end
    end

    describe '#protocol_variant_url' do
      subject(:upstream) { build(:virtual_registries_packages_maven_upstream) }

      where(:url, :expected_variant) do
        'https://repo.maven.org' | 'http://repo.maven.org'
        'http://repo.maven.org'  | 'https://repo.maven.org'
        nil                      | nil
      end

      with_them do
        it 'returns the protocol variant' do
          upstream.url = url

          expect(upstream.send(:protocol_variant_url)).to eq(expected_variant)
        end
      end
    end
  end

  describe 'callbacks' do
    context 'for set_cache_validity_hours_for_maven_central' do
      %w[
        https://repo1.maven.org/maven2
        https://repo1.maven.org/maven2/
      ].each do |maven_central_url|
        context "with url set to #{maven_central_url}" do
          before do
            upstream.url = maven_central_url
          end

          it 'sets the cache validity hours to 0' do
            upstream.save!

            expect(upstream.cache_validity_hours).to eq(0)
          end
        end
      end

      context 'with url other than maven central' do
        before do
          upstream.url = 'https://test.org/maven2'
        end

        it 'sets the cache validity hours to the database default value' do
          upstream.save!

          expect(upstream.cache_validity_hours).not_to eq(0)
        end
      end

      context 'with no url' do
        before do
          upstream.url = nil
        end

        it 'does not set the cache validity hours' do
          expect(upstream).not_to receive(:set_cache_validity_hours_for_maven_central)

          expect { upstream.save! }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end

    context 'for restore_password!' do
      let_it_be_with_reload(:upstream) do
        create(:virtual_registries_packages_maven_upstream,
          username: 'existing_username',
          password: 'existing_password'
        )
      end

      # rubocop:disable Layout/LineLength -- Avoid formatting to keep one-line table syntax for readability
      where(:new_username, :new_password, :update_name, :should_save, :expected_username, :expected_password,
        :description) do
        'new_username'      | 'new_password' | false | true  | 'new_username'      | 'new_password'      | 'updates both when username and password are changed'
        ''                  | ''             | false | true  | ''                  | ''                  | 'updates both when username and password are changed to an empty string'
        'existing_username' | ''             | false | true  | 'existing_username' | 'existing_password' | 'keeps original password when username remains unchanged'
        'new_username'      | ''             | false | false | nil                 | nil                 | 'allows validation to fail when username changes with blank password'
        'existing_username' | ''             | true  | true  | 'existing_username' | 'existing_password' | 'keeps original password when password is an empty string and updating non-credential fields'
        'existing_username' | nil            | true  | true  | 'existing_username' | 'existing_password' | 'keeps original password when password is nil and updating non-credential fields'
      end
      # rubocop:enable Layout/LineLength

      with_them do
        before do
          upstream.name = 'new name' if update_name
          upstream.username = new_username
          upstream.password = new_password
        end

        if params[:should_save]
          it params[:description] do
            upstream.save!

            expect(upstream).to have_attributes(
              username: expected_username,
              password: expected_password
            )
          end
        else
          it params[:description] do
            expect(upstream).not_to be_valid
            expect(upstream.errors[:password]).to include("can't be blank")
          end
        end
      end
    end
  end

  describe 'scopes' do
    describe '.eager_load_registry_upstream' do
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, :with_upstreams, upstreams_count: 2) }
      let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry, :with_upstreams) }

      subject(:upstreams) { described_class.eager_load_registry_upstream(registry:) }

      it { is_expected.to eq(registry.upstreams) }

      it { is_expected.not_to include(other_registry.upstreams) }

      it 'eager loads the registry_upstream association' do
        recorder = ActiveRecord::QueryRecorder.new { upstreams.each(&:registry_upstreams) }

        expect(recorder.count).to eq(1)
      end

      it 'eager loads the registries association' do
        recorder = ActiveRecord::QueryRecorder.new { upstreams.each(&:registries) }

        expect(recorder.count).to eq(1)
      end
    end

    describe '.for_id_and_group' do
      let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream) }

      before do
        create(:virtual_registries_packages_maven_upstream)
      end

      subject { described_class.for_id_and_group(id: upstream.id, group: upstream.group) }

      it { is_expected.to contain_exactly(upstream) }
    end

    describe '.for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream, group:) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream) }

      subject { described_class.for_group(group) }

      it { is_expected.to eq([upstream]) }
    end

    describe '.for_url' do
      let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream, url: 'https://gitlab.com/maven/test') }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream) }

      subject { described_class.for_url('https://gitlab.com/maven/test') }

      it { is_expected.to eq([upstream]) }
    end

    describe '.search_by_name' do
      let(:query) { 'abc' }
      let_it_be(:name) { 'pkg-name-abc' }
      let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream, name: name) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream) }

      subject { described_class.search_by_name(query) }

      it { is_expected.to eq([upstream]) }
    end
  end

  describe 'encryption' do
    subject(:saved_upstream) { upstream.tap(&:save!) }

    it { is_expected.to be_encrypted_attribute(:username).and be_encrypted_attribute(:password) }
  end

  describe '#url_for' do
    subject { upstream.url_for(path) }

    where(:path, :expected_url) do
      'path'      | 'http://test.maven/path'
      ''          | 'http://test.maven/'
      '/path'     | 'http://test.maven/path'
      '/sub/path' | 'http://test.maven/sub/path'
    end

    with_them do
      before do
        upstream.url = 'http://test.maven/'
      end

      it { is_expected.to eq(expected_url) }
    end
  end

  describe '#headers' do
    subject { upstream.headers }

    where(:username, :password, :expected_headers) do
      'user' | 'pass' | { Authorization: 'Basic dXNlcjpwYXNz' }
      'user' | ''     | {}
      ''     | 'pass' | {}
      ''     | ''     | {}
    end

    with_them do
      before do
        upstream.username = username
        upstream.password = password
      end

      it { is_expected.to eq(expected_headers) }
    end
  end

  describe '#as_json' do
    subject { upstream.as_json }

    it { is_expected.not_to include('password') }
  end

  describe '#default_cache_entries' do
    let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream) }
    let_it_be(:default_cache_entry, freeze: false) do
      create(:virtual_registries_packages_maven_cache_remote_entry, upstream:)
    end

    let_it_be(:pending_destruction_cache_entry) do
      create(:virtual_registries_packages_maven_cache_remote_entry, :pending_destruction, upstream:)
    end

    subject { upstream.default_cache_entries }

    it { is_expected.to contain_exactly(default_cache_entry) }
  end

  describe '#object_storage_key' do
    let_it_be(:upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }

    subject { upstream.object_storage_key }

    it 'contains the expected terms' do
      is_expected.to include(
        "virtual_registries/packages/maven/#{upstream.group_id}/upstream/#{upstream.id}/cache/entry"
      )
    end

    it 'does not return the same value when called twice' do
      first_value = upstream.object_storage_key
      second_value = upstream.object_storage_key

      expect(first_value).not_to eq(second_value)
    end
  end

  describe '#purge_cache!' do
    let(:upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }

    it 'enqueues the MarkEntriesForDestructionWorker' do
      expect(::VirtualRegistries::Cache::MarkEntriesForDestructionWorker)
        .to receive(:perform_async).with(upstream.to_global_id.to_s)

      upstream.purge_cache!
    end
  end

  describe '#test' do
    let(:test_url) { upstream.url_for('com/company/app/maven-metadata.xml') }
    let(:response) { ActiveSupport::OrderedOptions.new }
    let(:code) { 200 }
    let(:message) { 'OK' }

    subject(:test) { upstream.test }

    before do
      allow(Gitlab::HTTP).to receive(:head) do
        response.code = code
        response.message = message
        response
      end
    end

    it 'makes a HEAD request to the test endpoint' do
      test

      expect(Gitlab::HTTP).to have_received(:head).with(
        test_url,
        headers: upstream.headers,
        follow_redirects: true
      )
    end

    context 'with different HTTP response codes' do
      where(:code, :message, :expected_result) do
        200 | 'OK'                    | { success: true }
        201 | 'Created'               | { success: true }
        299 | 'Misc Success'          | { success: true }
        404 | 'Not Found'             | { success: true }
        400 | 'Bad Request'           | { success: false, result: 'Error: 400 - Bad Request' }
        401 | 'Unauthorized'          | { success: false, result: 'Error: 401 - Unauthorized' }
        403 | 'Forbidden'             | { success: false, result: 'Error: 403 - Forbidden' }
        500 | 'Internal Server Error' | { success: false, result: 'Error: 500 - Internal Server Error' }
      end

      with_them do
        it { is_expected.to eq(expected_result) }
      end
    end

    context 'when HTTP errors occur' do
      where(:error_class, :error_message) do
        Net::OpenTimeout | 'Connection timeout'
        SocketError      | 'getaddrinfo: Name or service not known'
      end

      before do
        allow(Gitlab::HTTP).to receive(:head).and_raise(error_class, error_message)
      end

      with_them do
        it { is_expected.to eq({ success: false, result: "Error: #{error_message}" }) }
      end
    end

    context 'with credentials' do
      where(:username, :password, :expected_headers) do
        'testuser' | 'testpass' | { Authorization: 'Basic dGVzdHVzZXI6dGVzdHBhc3M=' }
        nil        | nil        | {}
      end

      before do
        upstream.assign_attributes(username:, password:)
      end

      with_them do
        it 'uses the appropriate headers' do
          test

          expect(Gitlab::HTTP).to have_received(:head).with(
            test_url,
            headers: expected_headers,
            follow_redirects: true
          )
        end
      end
    end

    context 'with existing upstream cache entries' do
      before do
        upstream.save!
        create(
          :virtual_registries_packages_maven_cache_remote_entry,
          upstream: upstream,
          relative_path: 'dummy/path/maven-metadata.xml'
        )
      end

      it 'uses the cache entry relative_path for the HEAD request' do
        test

        expect(Gitlab::HTTP).to have_received(:head).with(
          upstream.url_for('dummy/path/maven-metadata.xml'),
          headers: upstream.headers,
          follow_redirects: true
        )
      end
    end
  end

  describe '#destroy_and_sync_positions' do
    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry1_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry: registry1) }

    let_it_be(:other_registry1_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry1)
    end

    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2_upstream) do
      create(
        :virtual_registries_packages_maven_registry_upstream,
        registry: registry2,
        upstream: registry1_upstream.upstream
      )
    end

    let_it_be(:other_registry2_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry2)
    end

    subject(:destroy_and_sync) { registry1_upstream.upstream.destroy_and_sync_positions }

    it 'destroys the upstream and sync the registries positions' do
      expect { destroy_and_sync }.to change { ::VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
        .and change { registry1.reload.registry_upstreams.count }.from(2).to(1)
        .and change { registry2.reload.registry_upstreams.count }.from(2).to(1)
        .and change { other_registry1_upstream.reload.position }.from(2).to(1)
        .and change { other_registry2_upstream.reload.position }.from(2).to(1)
    end
  end

  describe '#allow_rules' do
    let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream) }
    let_it_be(:allow_rule) do
      create(:virtual_registries_packages_maven_upstream_rule,
        remote_upstream: upstream, rule_type: :allow)
    end

    let_it_be(:deny_rule) do
      create(:virtual_registries_packages_maven_upstream_rule,
        remote_upstream: upstream, rule_type: :deny)
    end

    subject { upstream.allow_rules }

    it { is_expected.to contain_exactly(allow_rule) }
    it { is_expected.not_to include(deny_rule) }
  end

  describe '#deny_rules' do
    let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_maven_upstream) }
    let_it_be(:allow_rule) do
      create(:virtual_registries_packages_maven_upstream_rule,
        remote_upstream: upstream, rule_type: :allow)
    end

    let_it_be(:deny_rule) do
      create(:virtual_registries_packages_maven_upstream_rule,
        remote_upstream: upstream, rule_type: :deny)
    end

    subject { upstream.deny_rules }

    it { is_expected.to contain_exactly(deny_rule) }
    it { is_expected.not_to include(allow_rule) }
  end

  it_behaves_like 'a remote virtual registry object'

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), upstream)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
