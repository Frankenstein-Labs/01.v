# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AllowedEmailDomain, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }

  describe 'relations' do
    it { is_expected.to belong_to(:group) }
  end

  describe '.domain_names' do
    subject(:domain_names) { described_class.domain_names }

    let(:domains) { ['gitlab.com', 'acme.com'] }

    before do
      domains.each do |domain|
        create(:allowed_email_domain, domain: domain)
      end
    end

    it 'returns the array of domain names' do
      expect(domain_names).to match_array(domains)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:domain) }
    it { is_expected.to validate_presence_of(:group_id) }

    describe '#valid domain' do
      context 'with valid domain' do
        let(:valid_domains) { ['gitlab.com', 'gitlab.co.uk', 'GITLAB.COM'] }

        it 'succeeds' do
          valid_domains.each do |domain|
            overridden_subject = described_class.new(group: group, domain: domain)
            expect(overridden_subject.valid?).to be_truthy
          end
        end
      end

      context 'with invalid domain' do
        let(:invalid_domains) do
          ['gitlab', 'git?lab.com', 'gitlab.com!', 'gitlab.@com', 'gitla>b.com', 'gitl<a>b@.c?om!']
        end

        it 'fails' do
          invalid_domains.each do |domain|
            overridden_subject = described_class.new(group: group, domain: domain)
            expect(overridden_subject.valid?).to be_falsey
            expect(overridden_subject.errors[:domain]).to include('The domain you entered is misformatted.')
          end
        end
      end

      context 'with domain from excluded list' do
        let(:domain) { 'hotmail.co.uk' }

        subject(:email_domain_record) { described_class.new(group: group, domain: domain) }

        it 'fails' do
          expect(email_domain_record.valid?).to be_falsey
          expect(email_domain_record.errors[:domain]).to include('The domain you entered is not allowed.')
        end
      end
    end

    describe '#allow_root_group_only' do
      subject(:email_domain_record) { described_class.new(group: group, domain: 'gitlab.com') }

      context 'with top-level group' do
        it 'succeeds' do
          expect(email_domain_record.valid?).to be_truthy
        end
      end

      context 'with subgroup' do
        let_it_be(:group) { create(:group, :nested) }

        it 'fails' do
          expect(email_domain_record.valid?).to be_falsey
          expect(email_domain_record.errors[:base])
            .to include('Allowed email domain restriction only permitted for top-level groups')
        end
      end
    end
  end

  describe '#email_matches_domain?' do
    subject(:email_domain_record) { described_class.new(group: group, domain: 'gitlab.com') }

    context 'with matching domain' do
      it 'returns true' do
        expect(email_domain_record.email_matches_domain?('test@gitlab.com')).to be(true)
      end
    end

    context 'with not matching domain' do
      it 'returns false' do
        expect(email_domain_record.email_matches_domain?('test@gitlab.com.uk')).to be(false)
      end
    end
  end

  describe '#email_domain' do
    subject(:email_domain_record) { described_class.new(group: group, domain: 'gitlab.com') }

    it 'returns formatted domain' do
      expect(email_domain_record.email_domain).to eq('@gitlab.com')
    end
  end
end
