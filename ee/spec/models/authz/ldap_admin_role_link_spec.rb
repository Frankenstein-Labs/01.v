# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::LdapAdminRoleLink, feature_category: :system_access do
  let_it_be(:providers) { ['ldapprovider'] }

  before do
    allow(::Gitlab::Auth::Ldap::Config).to receive_messages(providers: providers)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:member_role) }
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'validations' do
    subject(:ldap_admin_role_link) { build(:ldap_admin_role_link, provider: 'ldapprovider') }

    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_length_of(:provider).is_at_most(255) }
    it { is_expected.to validate_length_of(:cn).is_at_most(255) }
    it { is_expected.to validate_length_of(:filter).is_at_most(255) }

    it { is_expected.to nullify_if_blank(:cn) }
    it { is_expected.to nullify_if_blank(:filter) }

    it { is_expected.to validate_presence_of(:sync_status) }
    it { is_expected.to validate_length_of(:sync_error).is_at_most(255) }

    describe 'enums' do
      let(:sync_statuses) do
        { never_synced: 0, queued: 1, running: 2, failed: 3, successful: 4 }
      end

      it { is_expected.to define_enum_for(:sync_status).with_values(sync_statuses) }
    end

    describe 'cn' do
      context 'when cn is duplicated for the same provider' do
        before do
          create(:ldap_admin_role_link, cn: 'cn', provider: 'ldapprovider')
        end

        it 'returns an error' do
          duplicate_admin_link = build(:ldap_admin_role_link, cn: 'cn', provider: 'ldapprovider')

          expect(duplicate_admin_link).not_to be_valid
          expect(duplicate_admin_link.errors.messages).to eq(cn: ['has already been taken'])
        end
      end

      context 'when filter is also provided' do
        it 'returns an error' do
          admin_link = build(:ldap_admin_role_link, cn: 'cn', filter: '(a=b)', provider: 'ldapprovider')

          expect(admin_link).not_to be_valid
          expect(admin_link.errors.messages).to eq(filter: ['One and only one of [cn, filter] arguments is required'])
        end
      end
    end

    describe 'filter' do
      context 'when filter is duplicated for the same provider' do
        before do
          create(:ldap_admin_role_link, cn: nil, filter: '(a=b)', provider: 'ldapprovider')
        end

        it 'returns an error' do
          duplicate_admin_link = build(:ldap_admin_role_link, cn: nil, filter: '(a=b)', provider: 'ldapprovider')

          expect(duplicate_admin_link).not_to be_valid
          expect(duplicate_admin_link.errors.messages).to eq(filter: ["has already been taken"])
        end
      end

      context 'when invalid filter is provided' do
        it 'returns an error' do
          admin_link = build(:ldap_admin_role_link, cn: nil, filter: 'invalid filter', provider: 'ldapprovider')

          expect(admin_link).not_to be_valid
          expect(admin_link.errors.messages).to eq(filter: ['must be a valid filter'])
        end
      end
    end

    describe 'provider' do
      context 'when provider is invalid' do
        it 'returns an error' do
          admin_link = build(:ldap_admin_role_link, cn: 'cn', provider: 'invalidldapprovider')

          expect(admin_link).not_to be_valid
          expect(admin_link.errors.messages).to eq(provider: ['is invalid'])
        end
      end
    end
  end

  describe 'scopes' do
    describe '.with_provider' do
      let_it_be(:providers) { %w[ldapprovider ldapproviderother] }

      it 'returns ldap admin role links for the specified provider' do
        links = [create(:ldap_admin_role_link, provider: 'ldapprovider'),
          create(:ldap_admin_role_link, provider: 'ldapproviderother')]

        expect(described_class.with_provider('ldapprovider')).to eq([links.first])
      end
    end

    describe '.preload_admin_role' do
      subject(:relation) { described_class.preload_admin_role }

      it 'loads member role association' do
        create(:ldap_admin_role_link, provider: 'ldapprovider')

        expect(relation.first.association(:member_role)).to be_loaded
      end
    end
  end

  describe '.mark_syncs_as_queued' do
    before do
      build_list(:ldap_admin_role_link, 3)
    end

    subject(:mark_syncs_as_queued) { described_class.mark_syncs_as_queued }

    it 'sets the sync status for all records to queued' do
      described_class.all.find_each do |record|
        record.reload

        expect(record.sync_status).to eq('queued')
        expect(record.sync_started_at).to be_nil
        expect(record.sync_ended_at).to be_nil
        expect(record.sync_error).to be_nil
      end
    end
  end

  describe '.mark_syncs_as_running' do
    before do
      build_list(:ldap_admin_role_link, 3)
    end

    subject(:mark_syncs_as_queued) { described_class.mark_syncs_as_running }

    it 'sets the sync status for all records to running', :freeze_time do
      described_class.all.find_each do |record|
        record.reload

        expect(record.sync_status).to eq('running')
        expect(record.sync_started_at).to eq(DateTime.current)
        expect(record.sync_ended_at).to be_nil
        expect(record.sync_error).to be_nil
      end
    end
  end

  describe '.mark_syncs_as_successful' do
    before do
      build_list(:ldap_admin_role_link, 3)
    end

    subject(:mark_syncs_as_queued) { described_class.mark_syncs_as_successful }

    it 'sets the sync status for all records to successful', :freeze_time do
      described_class.all.find_each do |record|
        record.reload

        expect(record.sync_status).to eq('successful')
        expect(record.sync_ended_at).to eq(DateTime.current)
        expect(record.last_successful_sync_at).to eq(DateTime.current)
        expect(record.sync_error).to be_nil
      end
    end
  end

  describe '.mark_syncs_as_failed' do
    let(:error_message) { 'Test error' }

    before do
      build_list(:ldap_admin_role_link, 3)
    end

    subject(:mark_syncs_as_queued) { described_class.mark_syncs_as_failed(error_message) }

    it 'sets the sync status for all records to error', :freeze_time do
      described_class.all.find_each do |record|
        record.reload

        expect(record.sync_status).to eq('successful')
        expect(record.sync_ended_at).to eq(DateTime.current)
        expect(record.sync_error).to eq(error_message)
      end
    end

    context 'when the error message is too long' do
      let(:error_message) { 'e' * 300 }

      it 'truncates error message' do
        described_class.all.find_each do |record|
          record.reload

          expect(record.sync_error.length).to eq(255)
        end
      end
    end
  end
end
