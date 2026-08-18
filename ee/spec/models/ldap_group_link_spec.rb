# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LdapGroupLink do
  let(:klass) { described_class }
  let(:ldap_group_link) { build :ldap_group_link }

  describe 'validation' do
    let(:invalid_filter_length) { 8193 }
    let(:invalid_cn_length) { 256 }
    let(:invalid_provider_length) { 256 }

    describe 'cn or filter presence' do
      it 'is invalid on create when both cn and filter are blank' do
        link = build(:ldap_group_link, cn: '', filter: '', group_id: 1, provider: 'ldapmain')

        expect(link).not_to be_valid(:create)
        expect(link.errors[:base]).to include('Either LDAP group cn or LDAP user filter is required')
      end

      it 'is invalid on create when both cn and filter are nil' do
        link = build(:ldap_group_link, cn: nil, filter: nil, group_id: 1, provider: 'ldapmain')

        expect(link).not_to be_valid(:create)
        expect(link.errors[:base]).to include('Either LDAP group cn or LDAP user filter is required')
      end

      it 'is valid on update when both cn and filter are nil' do
        link = build(:ldap_group_link, cn: nil, filter: nil, group_id: 1, provider: 'ldapmain')

        expect(link).to be_valid(:update)
      end

      it 'is valid when cn is present' do
        link = build(:ldap_group_link, cn: 'group1', filter: nil, group_id: 1, provider: 'ldapmain')

        expect(link).to be_valid
      end

      it 'is valid when filter is present' do
        link = build(:ldap_group_link, cn: nil, filter: '(a=b)', group_id: 1, provider: 'ldapmain')

        expect(link).to be_valid
      end
    end

    describe 'cn' do
      it 'validates uniqueness based on group_id and provider' do
        create(:ldap_group_link, cn: 'group1', group_id: 1, provider: 'ldapmain')

        group_link = build(:ldap_group_link,
          cn: 'group1', group_id: 1, provider: 'ldapmain')
        expect(group_link).not_to be_valid

        group_link.group_id = 2
        expect(group_link).to be_valid

        group_link.group_id = 1
        group_link.provider = 'ldapalt'
        expect(group_link).to be_valid
      end

      it 'is invalid when a filter is also present' do
        link = build(:ldap_group_link, filter: '(a=b)', group_id: 1, provider: 'ldapmain', cn: 'group1')

        expect(link).not_to be_valid
      end

      it 'validates the CN length' do
        link = build(:ldap_group_link, group_id: 1, provider: 'ldapmain', cn: ('c' * invalid_cn_length).to_s)

        expect(link).not_to be_valid(:create)
      end

      it 'existing CN pass length validation' do
        link = build(:ldap_group_link, group_id: 1, provider: 'ldapmain', cn: ('c' * invalid_cn_length).to_s)

        expect(link).to be_valid(:destroy)
      end
    end

    describe 'filter' do
      it 'validates uniqueness based on group_id and provider' do
        create(:ldap_group_link, filter: '(a=b)', group_id: 1, provider: 'ldapmain', cn: nil)

        group_link = build(:ldap_group_link, filter: '(a=b)', group_id: 1, provider: 'ldapmain', cn: nil)
        expect(group_link).not_to be_valid

        group_link.group_id = 2
        expect(group_link).to be_valid

        group_link.group_id = 1
        group_link.provider = 'ldapalt'
        expect(group_link).to be_valid
      end

      it 'validates the LDAP filter format' do
        link = build(:ldap_group_link, filter: 'invalid', group_id: 1, provider: 'ldapmain', cn: nil)

        expect(link).not_to be_valid
      end

      it 'validates the LDAP filter length' do
        link = build(:ldap_group_link, filter: "(a=#{'b' * invalid_filter_length})", group_id: 1,
          provider: 'ldapmain', cn: nil)

        expect(link).not_to be_valid(:create)
      end

      it 'existing LDAP filter pass length validation' do
        link = build(:ldap_group_link, filter: "(a=#{'b' * invalid_filter_length})", group_id: 1,
          provider: 'ldapmain', cn: nil)

        expect(link).to be_valid(:destroy)
      end
    end

    describe 'provider' do
      it 'shows the set value' do
        ldap_group_link.provider = '1235'
        expect(ldap_group_link.provider).to eql '1235'
      end

      it 'defaults to the first ldap server if empty' do
        expect(klass.new.provider).to eql Gitlab::Auth::Ldap::Config.providers.first
      end

      it 'validates the provider length' do
        link = build(:ldap_group_link, filter: "(a=b)", group_id: 1,
          provider: ('p' * invalid_provider_length).to_s, cn: nil)

        expect(link).not_to be_valid(:create)
      end

      it 'existing provider pass length validation' do
        link = build(:ldap_group_link, filter: "(a=b)", group_id: 1,
          provider: ('p' * invalid_provider_length).to_s, cn: nil)

        expect(link).to be_valid(:destroy)
      end
    end
  end

  describe 'group_access' do
    it 'validates the group_access presence' do
      link = build(:ldap_group_link, filter: "(a=b)",
        provider: 'provider', cn: nil, group_access: nil)

      expect(link).not_to be_valid
    end
  end

  it_behaves_like 'model with member role relation' do
    subject(:model) { ldap_group_link }
  end
end
