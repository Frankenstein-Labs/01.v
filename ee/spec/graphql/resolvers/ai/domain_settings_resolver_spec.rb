# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::DomainSettingsResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:ai_settings) do
    create(:ai_settings, allowed_domains: ['example.com', 'gitlab.com'], denied_domains: ['evil.com'])
  end

  before do
    allow(::Ai::Setting).to receive(:for_organization_read_only).and_return(ai_settings)
  end

  subject(:resolved) do
    resolve(described_class, obj: object, args: { domain_setting_type: domain_setting_type, search: search },
      ctx: { current_user: current_user })
  end

  context 'when object is nil (instance-level)' do
    let(:object) { nil }

    context 'when the user has permission' do
      let(:current_user) { admin }
      let(:search) { nil }

      before do
        allow(admin).to receive(:can_admin_all_resources?).and_return(true)
      end

      context 'with domain_setting_type ALLOWED' do
        let(:domain_setting_type) { 'allowed' }

        it 'returns allowed_domains without creating settings' do
          expect(::Ai::Setting).not_to receive(:for_organization)
          expect(::Ai::Setting).to receive(:for_organization_read_only)
            .with(::Current.organization).and_return(ai_settings)

          expect(resolved).to match_array(['example.com', 'gitlab.com'])
        end

        context 'with a search parameter' do
          let(:search) { 'example' }

          it 'returns only domains matching the substring' do
            expect(resolved).to match_array(['example.com'])
          end
        end

        context 'with a case-insensitive search parameter' do
          let(:search) { 'EXAMPLE' }

          it 'returns domains matching the substring case-insensitively' do
            expect(resolved).to match_array(['example.com'])
          end
        end

        context 'with a search parameter that matches no domains' do
          let(:search) { 'nomatch' }

          it 'returns an empty array' do
            expect(resolved).to be_empty
          end
        end
      end

      context 'with domain_setting_type DENIED' do
        let(:domain_setting_type) { 'denied' }

        it 'returns denied_domains' do
          expect(resolved).to match_array(['evil.com'])
        end

        context 'with a search parameter' do
          let(:search) { 'evil' }

          it 'returns only domains matching the substring' do
            expect(resolved).to match_array(['evil.com'])
          end
        end
      end

      context 'with an unknown domain_setting_type' do
        let(:domain_setting_type) { 'unknown' }

        subject(:resolved) do
          resolve(described_class, obj: object, args: { domain_setting_type: domain_setting_type, search: search },
            ctx: { current_user: current_user }, arg_style: :internal)
        end

        it 'returns nil' do
          expect(resolved).to be_nil
        end
      end
    end

    context 'when the user does not have permission' do
      let(:current_user) { user }
      let(:domain_setting_type) { 'allowed' }
      let(:search) { nil }

      before do
        allow(user).to receive(:can_admin_all_resources?).and_return(false)
      end

      it 'returns nil' do
        expect(resolved).to be_nil
      end
    end

    context 'when current_user is nil' do
      let(:current_user) { nil }
      let(:domain_setting_type) { 'allowed' }
      let(:search) { nil }

      it 'returns nil' do
        expect(resolved).to be_nil
      end
    end
  end

  context 'when object is a Namespace' do
    let_it_be(:root_group) do
      create(:group, ai_allowed_domains: ['group.com'], ai_denied_domains: ['bad.com'])
    end

    let(:search) { nil }

    context 'when the namespace is a root group' do
      let(:object) { root_group }

      context 'when the user has permission' do
        let(:current_user) { user }

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_ai_domain_settings, root_group).and_return(true)
        end

        context 'with domain_setting_type ALLOWED' do
          let(:domain_setting_type) { 'allowed' }

          it 'returns the namespace allowed_domains' do
            expect(resolved).to match_array(['group.com'])
          end
        end

        context 'with domain_setting_type DENIED' do
          let(:domain_setting_type) { 'denied' }

          it 'returns the namespace denied_domains' do
            expect(resolved).to match_array(['bad.com'])
          end
        end

        context 'with an unknown domain_setting_type' do
          let(:domain_setting_type) { 'unknown' }

          subject(:resolved) do
            resolve(described_class, obj: object, args: { domain_setting_type: domain_setting_type, search: search },
              ctx: { current_user: current_user }, arg_style: :internal)
          end

          it 'returns nil' do
            expect(resolved).to be_nil
          end
        end
      end

      context 'when the user does not have permission' do
        let(:current_user) { user }
        let(:domain_setting_type) { 'allowed' }

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_ai_domain_settings, root_group).and_return(false)
        end

        it 'returns nil' do
          expect(resolved).to be_nil
        end
      end
    end

    context 'when the namespace is not a root group' do
      let(:object) { create(:group, parent: root_group) }
      let(:current_user) { admin }
      let(:domain_setting_type) { 'allowed' }

      it 'returns nil' do
        expect(resolved).to be_nil
      end
    end
  end
end
