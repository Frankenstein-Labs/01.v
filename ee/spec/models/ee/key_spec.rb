# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Key, feature_category: :system_access do
  describe 'validations' do
    describe 'expiration' do
      using RSpec::Parameterized::TableSyntax

      where(:key, :valid) do
        build(:personal_key, expires_at: 2.days.ago) | false
        build(:personal_key, expires_at: 2.days.from_now) | true
        build(:personal_key) | true
      end

      with_them do
        it 'checks if ssh key expiration is enforced' do
          expect(key.valid?).to eq(valid)
        end
      end
    end

    describe '#validate_expires_at_before_max_expiry_date' do
      using RSpec::Parameterized::TableSyntax

      context 'for a range of key expiry combinations' do
        where(:key, :max_ssh_key_lifetime, :valid) do
          build(:personal_key, created_at: Time.current, expires_at: nil) | nil | true
          build(:personal_key, created_at: Time.current, expires_at: 20.days.from_now) | nil | true
          build(:personal_key, created_at: 1.day.ago, expires_at: 20.days.from_now) | 10 | false
          build(:personal_key, created_at: 6.days.ago, expires_at: 3.days.from_now) | 10 | true
          build(:personal_key, created_at: 10.days.ago, expires_at: 7.days.from_now) | 10 | false
          build(:personal_key, created_at: Time.current, expires_at: nil) | 20 | false
          build(:personal_key, expires_at: nil) | 30 | false
        end

        with_them do
          before do
            stub_licensed_features(ssh_key_expiration_policy: true)
            stub_application_setting(max_ssh_key_lifetime: max_ssh_key_lifetime)
          end

          it 'checks if ssh key expiration is valid' do
            expect(key.valid?).to eq(valid)
          end
        end
      end

      context 'when keys and max expiry are set' do
        where(:key, :max_ssh_key_lifetime, :valid) do
          build(:personal_key, created_at: Time.current, expires_at: 20.days.from_now) | 10 | false
          build(:personal_key, created_at: Time.current, expires_at: 7.days.from_now) | 10 | true
        end

        with_them do
          before do
            stub_licensed_features(ssh_key_expiration_policy: true)
            stub_application_setting(max_ssh_key_lifetime: max_ssh_key_lifetime)
          end

          it 'checks validity properly in the future too' do
            # Travel to the day before the key is set to 'expire'.
            # max_ssh_key_lifetime should still be enforced correctly.
            travel_to(key.expires_at - 1) do
              expect(key.valid?).to eq(valid)
            end
          end
        end
      end
    end

    describe '#ensure_ssh_keys_enabled' do
      context 'for enterprise users', :saas do
        before do
          stub_licensed_features(disable_ssh_keys: true)
          stub_saas_features(disable_ssh_keys: true)
        end

        let_it_be_with_reload(:group) { create(:group) }
        let_it_be_with_reload(:user) { create(:enterprise_user, enterprise_group: group) }

        context 'for regular keys' do
          it 'ensures SSH Keys enabled for the user', :aggregate_failures do
            described_class.regular_key_types.each do |regular_key_type|
              key = build(:key, type: regular_key_type, user: user)
              expect(key.valid?).to be(true)
            end
          end

          context 'when the key is not associated with any user' do
            it 'does not apply the validation' do
              key = build(:key, type: described_class.regular_key_types.sample, user: nil)
              expect(key.valid?).to be(true)
            end
          end
        end

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          context 'for regular keys' do
            it 'ensures SSH Keys enabled for the user', :aggregate_failures do
              described_class.regular_key_types.each do |regular_key_type|
                key = build(:key, type: regular_key_type, user: user)
                expect(key.valid?).to be(false)
                expect(key.errors[:base]).to include('SSH keys are disabled for this user')
              end
            end

            context 'when the key is not associated with any user' do
              it 'does not apply the validation' do
                key = build(:key, type: described_class.regular_key_types.sample, user: nil)
                expect(key.valid?).to be(true)
              end
            end
          end

          # See https://gitlab.com/gitlab-org/gitlab/-/issues/30343#note_2940146057
          context 'for deploy keys' do
            it 'does not apply the validation' do
              key = build(:deploy_key, user: user)
              expect(key.valid?).to be(true)
            end
          end
        end
      end
    end
  end

  describe '#audit_details' do
    it 'equals to the title' do
      key = build(:personal_key)
      expect(key.audit_details).to eq(key.title)
    end
  end

  describe 'scopes' do
    describe '.regular_keys' do
      let_it_be(:ldap_key) { create(:ldap_key) }

      it "includes keys with 'LDAPKey' type" do
        expect(described_class.regular_keys).to include(ldap_key)
      end
    end
  end

  describe '.regular_key_types' do
    it "includes 'LDAPKey'" do
      expect(described_class.regular_key_types).to include('LDAPKey')
    end
  end

  describe '#regular_key?' do
    context "when type is 'LDAPKey'" do
      it 'returns true' do
        expect(build(:ldap_key).regular_key?).to be(true)
      end
    end
  end
end
