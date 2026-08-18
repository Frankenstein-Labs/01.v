# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::Upstream, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:other_project) { create(:project) }
  let_it_be(:other_project_global_id) { other_project.to_global_id.to_s }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_group_global_id) { other_group.to_global_id.to_s }

  subject(:upstream) { build(:virtual_registries_packages_npm_upstream) }

  describe 'associations', :aggregate_failures do
    it 'has many registry upstreams' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Npm::RegistryUpstream')
        .inverse_of(:upstream)
        .autosave(true)
    end

    it 'has many registries' do
      is_expected.to have_many(:registries)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Npm::Registry')
    end

    it 'has many cache local entries' do
      is_expected.to have_many(:cache_local_entries)
        .class_name('VirtualRegistries::Packages::Npm::Cache::Local::Entry')
        .inverse_of(:upstream)
    end

    it 'has many cache remote entries' do
      is_expected.to have_many(:cache_remote_entries)
        .class_name('VirtualRegistries::Packages::Npm::Cache::Remote::Entry')
        .inverse_of(:upstream)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_length_of(:url).is_at_most(255) }
    it { is_expected.to validate_length_of(:auth_token).is_at_most(2048) }
    it { is_expected.to validate_numericality_of(:cache_validity_hours).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:metadata_cache_validity_hours).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }

    context 'for remote upstream' do
      # Use 172.21.11.1 (from the rarely-used 172.16.0.0/12 range)
      # to avoid matching a developer's machine IP and getting classified
      # as "localhost" instead of "local network" by the URL blocker
      context 'for url' do
        where(:url, :valid, :error_messages) do
          'http://test.npm'     | true  | nil
          'https://test.npm'    | true  | nil
          'git://test.npm'      | false | ['Url is blocked: Only allowed schemes are http, https']
          nil                   | false | ["Url can't be blank", 'Url must be a valid URL']
          ''                    | false | ["Url can't be blank", 'Url must be a valid URL']
          "http://#{'a' * 255}" | false | 'Url is too long (maximum is 255 characters)'
          'http://127.0.0.1'    | false | 'Url is blocked: Requests to localhost are not allowed'
          'npm.local'           | false | 'Url is blocked: Only allowed schemes are http, https'
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
            'http://test.npm'       | 'http://test.npm'
            'http://test.npm/'      | 'http://test.npm'
            'http://test.npm//'     | 'http://test.npm'
            'http://test.npm/path'  | 'http://test.npm/path'
            'http://test.npm/path/' | 'http://test.npm/path'
          end

          with_them do
            before do
              upstream.url = url_to_set
            end

            it { is_expected.to be_valid.and have_attributes(url: expected_url) }
          end

          context 'when creating upstreams with same URL but different trailing slashes' do
            let_it_be(:group) { create(:group) }

            it 'prevents duplicate upstreams with trailing slash' do
              create(:virtual_registries_packages_npm_upstream, url: 'http://test.npm', group: group)

              duplicate = build(:virtual_registries_packages_npm_upstream, url: 'http://test.npm/', group: group)

              expect(duplicate).to be_invalid.and have_attributes(
                errors: match_array(Array.wrap(
                  'Group already has a remote upstream with the same url and credentials'
                )),
                url: 'http://test.npm'
              )
            end
          end
        end
      end

      context 'for credentials' do
        where(:auth_token, :valid, :error_message) do
          'token'     | true  | nil
          ''          | true  | nil
          nil         | true  | nil
          ''          | true  | nil
          ('a' * 2049) | false | 'Auth token is too long (maximum is 2048 characters)'
        end

        with_them do
          before do
            upstream.assign_attributes(auth_token:)
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it { is_expected.to be_invalid.and have_attributes(errors: match_array(Array.wrap(error_message))) }
          end
        end

        context 'when url is updated' do
          where(:new_url, :new_pwd, :expected_pwd) do
            'http://original_url.test' | 'test' | 'test'
            'http://update_url.test'   | 'test' | 'test'
            'http://update_url.test'   | :none  | nil
          end

          with_them do
            before do
              upstream.update!(url: 'http://original_url.test', auth_token: 'original_pwd')
            end

            it 'resets the auth_token when necessary' do
              new_attributes = { url: new_url, auth_token: new_pwd }.select { |_, v| v != :none }
              upstream.update!(new_attributes)

              expect(upstream.reload).to have_attributes(
                url: new_url,
                auth_token: expected_pwd
              )
            end
          end
        end
      end
    end

    context 'for local upstreams' do
      context 'for local project upstream' do
        subject(:upstream) do
          build(:virtual_registries_packages_npm_upstream, :without_credentials, url: other_project_global_id)
        end

        it { is_expected.to validate_absence_of(:auth_token) }
      end

      context 'for local group upstream' do
        subject(:upstream) do
          build(:virtual_registries_packages_npm_upstream, :without_credentials, url: other_group_global_id)
        end

        it { is_expected.to validate_absence_of(:auth_token) }
      end

      describe '#ensure_local_project_or_local_group' do
        let_it_be(:user_global_id) { create(:user).to_global_id.to_s }

        let(:invalid_project_global_id) { Project.new(id: non_existing_record_id).to_global_id.to_s }
        let(:invalid_group_global_id) { Group.new(id: non_existing_record_id).to_global_id.to_s }

        where(:url, :expected_error_messages) do
          ref(:other_project_global_id)   | []
          ref(:other_group_global_id)     | []
          ref(:invalid_project_global_id) | ['Url should point to an existing Project']
          ref(:invalid_group_global_id)   | ['Url should point to an existing Group']
          nil                             | ["Url can't be blank", 'Url must be a valid URL']
          'test'                          | ['Url is blocked: Only allowed schemes are http, https']
          ref(:user_global_id)            | ['Url should point to a Project or Group']
        end

        with_them do
          subject(:upstream) { build(:virtual_registries_packages_npm_upstream, :without_credentials, url:) }

          if params[:expected_error_messages].any?
            it { is_expected.to be_invalid.and have_attributes(errors: match_array(expected_error_messages)) }
          else
            it { is_expected.to be_valid }
          end
        end
      end
    end

    describe '#credentials_uniqueness_for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:existing_upstream) do
        create(
          :virtual_registries_packages_npm_upstream,
          group: group,
          url: 'https://example.com',
          auth_token: 'token'
        )
      end

      let_it_be(:local_project_url) do
        other_project_global_id.to_s.tap do |url|
          create(:virtual_registries_packages_npm_upstream, :without_credentials, group:, url:)
        end
      end

      let_it_be(:local_group_url) do
        other_group_global_id.tap do |url|
          create(:virtual_registries_packages_npm_upstream, :without_credentials, group:, url:)
        end
      end

      where(:test_group, :url, :auth_token, :valid, :description) do
        ref(:group)  | 'https://example.com'   | 'token'     | false | 'same group, same credentials'
        ref(:group)  | 'https://example.com'   | 'different' | true  | 'same group, different auth token'
        ref(:group)  | 'https://different.com' | 'token'     | true  | 'same group, different URL'
        ref(:group2) | 'https://example.com'   | 'token'     | true  | 'different group, same credentials'

        ref(:group)  | ref(:local_project_url)  | nil | false | 'same local project'
        ref(:group)  | ref(:local_group_url)    | nil | false | 'same local group'
      end

      with_them do
        context 'when creating new upstream' do
          subject(:new_upstream) do
            build(
              :virtual_registries_packages_npm_upstream,
              group: test_group,
              url: url,
              auth_token: auth_token
            )
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              error = if new_upstream.remote?
                        described_class::SAME_URL_AND_CREDENTIALS_ERROR
                      else
                        described_class::SAME_LOCAL_PROJECT_OR_GROUP_ERROR
                      end

              is_expected.to be_invalid.and have_attributes(errors: match_array(["Group #{error}"]))
            end
          end
        end

        context 'when updating existing upstream' do
          # `freeze: false` is required in this spec: one or more `let_it_be` subjects
          # cannot be frozen by default (deep_freeze traversal failure, a non-AR
          # subject, or an in-memory mutation that survives reload/refind). Do not
          # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
          # (see gitlab-org/gitlab#602925).
          let_it_be(:updated_upstream, freeze: false) do
            create(
              :virtual_registries_packages_npm_upstream,
              group: group,
              url: 'https://example2.com',
              auth_token: 'token'
            )
          end

          subject { updated_upstream }

          before do
            updated_upstream.assign_attributes(
              group: test_group,
              url: url,
              auth_token: auth_token
            )
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when updating to #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              expected_message = if updated_upstream.remote?
                                   'Group already has a remote upstream with the same url and credentials'
                                 else
                                   'Group already has a local upstream with the same target project or group'
                                 end

              is_expected.to be_invalid
                .and have_attributes(errors: match_array([expected_message]))
            end
          end
        end
      end
    end
  end

  describe 'scopes' do
    describe '.for_group' do
      let_it_be(:group) { create(:group) }
      # `freeze: false` is required in this spec: one or more `let_it_be` subjects
      # cannot be frozen by default (deep_freeze traversal failure, a non-AR
      # subject, or an in-memory mutation that survives reload/refind). Do not
      # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
      # (see gitlab-org/gitlab#602925).
      let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_npm_upstream, group:) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_npm_upstream) }

      subject { described_class.for_group(group) }

      it { is_expected.to eq([upstream]) }
    end
  end

  describe 'encryption' do
    subject(:saved_upstream) { upstream.tap(&:save!) }

    it { is_expected.to be_encrypted_attribute(:auth_token) }
  end

  describe '#local?' do
    where(:url, :result) do
      nil                           | false
      ref(:other_project_global_id) | true
      'https://gitlab.com/npm/test' | false
    end

    with_them do
      subject do
        build(:virtual_registries_packages_npm_upstream, :without_credentials, url:).local?
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#remote?' do
    where(:url, :result) do
      nil                           | true
      ref(:other_project_global_id) | false
      'https://gitlab.com/npm/test' | true
    end

    with_them do
      subject do
        build(:virtual_registries_packages_npm_upstream, :without_credentials, url:).remote?
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#as_json' do
    subject { upstream.as_json }

    it { is_expected.not_to include('auth_token') }
  end

  describe '#url_for' do
    context 'with a remote upstream' do
      let_it_be(:upstream) do
        build_stubbed(:virtual_registries_packages_npm_upstream, url: described_class::NPMJS_REGISTRY_URL)
      end

      it 'returns the full url' do
        result = upstream.url_for('pkg/-/pkg-1.0.0.tgz')

        expect(result).to eq("#{described_class::NPMJS_REGISTRY_URL}/pkg/-/pkg-1.0.0.tgz")
      end

      it 'handles scoped packages' do
        result = upstream.url_for('@scope/package-name/-/package-1.0.0.tgz')

        expect(result).to eq("#{described_class::NPMJS_REGISTRY_URL}/@scope/package-name/-/package-1.0.0.tgz")
      end
    end

    context 'with a local upstream' do
      let_it_be(:upstream) do
        build_stubbed(:virtual_registries_packages_npm_upstream, :without_credentials, url: other_project_global_id)
      end

      it 'returns nil' do
        expect(upstream.url_for('pkg/-/pkg-1.0.0.tgz')).to be_nil
      end
    end
  end

  describe '#headers' do
    context 'when auth_token is present' do
      let_it_be(:upstream) do
        build_stubbed(:virtual_registries_packages_npm_upstream, auth_token: 'test-token')
      end

      it 'returns authorization header with bearer token' do
        expect(upstream.headers).to eq({ Authorization: 'Bearer test-token' })
      end

      it 'ignores the optional argument' do
        expect(upstream.headers('ignored')).to eq({ Authorization: 'Bearer test-token' })
      end
    end

    context 'when auth_token is not present' do
      let_it_be(:upstream) do
        build_stubbed(:virtual_registries_packages_npm_upstream, :without_credentials)
      end

      it 'returns an empty hash' do
        expect(upstream.headers).to eq({})
      end
    end
  end

  describe '#object_storage_key' do
    let_it_be(:upstream) { build_stubbed(:virtual_registries_packages_npm_upstream) }

    it_behaves_like 'virtual registries: has object storage key', key_prefix: 'packages/npm'
  end

  describe '#default_cache_entries' do
    # `freeze: false` is required in this spec: one or more `let_it_be` subjects
    # cannot be frozen by default (deep_freeze traversal failure, a non-AR
    # subject, or an in-memory mutation that survives reload/refind). Do not
    # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
    # (see gitlab-org/gitlab#602925).
    let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_npm_upstream) }
    let_it_be(:default_cache_entry, freeze: false) do
      create(:virtual_registries_packages_npm_cache_remote_entry, upstream:)
    end

    let_it_be(:pending_destruction_cache_entry) do
      create(:virtual_registries_packages_npm_cache_remote_entry, :pending_destruction, upstream:)
    end

    subject { upstream.default_cache_entries }

    it { is_expected.to contain_exactly(default_cache_entry) }
  end

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), upstream)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
