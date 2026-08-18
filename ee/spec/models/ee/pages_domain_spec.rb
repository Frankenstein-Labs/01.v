# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PagesDomain, feature_category: :pages do
  subject(:pages_domain) { described_class.new }

  describe '#root_group' do
    let(:pages_domain) { create(:pages_domain, project: project) }

    context 'when pages_domain belongs to project' do
      context 'when project belongs to user' do
        let_it_be(:user_namespace) { create(:user).namespace }
        let_it_be(:project) { create(:project, namespace: user_namespace) }

        it 'returns nil' do
          expect(pages_domain.root_group).to be_nil
        end
      end

      context 'when project belongs to root group' do
        let_it_be(:root_group) { create(:group) }
        let_it_be(:project) { create(:project, namespace: root_group) }

        it 'returns root group' do
          expect(pages_domain.root_group).to eq(root_group)
        end

        context 'when project is in subgroup' do
          let_it_be(:subgroup) { create(:group, parent: root_group) }
          let_it_be(:project) { create(:project, namespace: subgroup) }

          it 'returns root group' do
            expect(pages_domain.root_group).to eq(root_group)
          end
        end
      end
    end
  end

  describe "validate domain" do
    subject(:pages_domain) { build(:pages_domain, domain: domain) }

    let(:reserved_domains) { ['example.com'] }

    before do
      stub_const("Gitlab::Access::ReservedDomains::ALL", reserved_domains)
    end

    context 'when domain is reserved' do
      let(:domain) { 'example.com' }

      it 'does not allow domain' do
        subject.valid?
        expect(subject.errors.full_messages).to include("Domain You cannot verify #{domain} because it is a popular \
public email domain.")
      end

      context 'when the domain format differs from the format in the list' do
        let(:domain) { 'Example.com' }

        it 'does not allow domain' do
          subject.valid?
          expect(subject.errors.full_messages).to include("Domain You cannot verify #{domain} because it is a popular \
public email domain.")
        end
      end

      context 'when domain is not reserved' do
        let(:domain) { 'gitlab.com' }

        it { is_expected.to be_valid }
      end
    end
  end
end
