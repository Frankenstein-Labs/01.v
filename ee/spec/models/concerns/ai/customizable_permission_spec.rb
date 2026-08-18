# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CustomizablePermission, feature_category: :duo_agent_platform do
  let(:ai_settings) { nil }
  let(:root_namespace) { create(:group, ai_settings: ai_settings) }
  let(:configured_access_level) { ::Gitlab::Access::MAINTAINER }

  describe '#ai_minimum_access_level_execute_with_fallback' do
    subject(:minimum_access_level) { root_namespace.ai_minimum_access_level_execute_with_fallback }

    context 'when on saas', :saas do
      context 'with a sub group' do
        let(:ai_settings) { create(:namespace_ai_settings, minimum_access_level_execute: configured_access_level) }
        let(:sub_group) { create(:group, parent: root_namespace) }

        it 'uses root_namespace ai settings' do
          result = sub_group.ai_minimum_access_level_execute_with_fallback

          expect(result).to eq configured_access_level
        end
      end

      context 'when root_namespace does not have ai settings' do
        before do
          allow(root_namespace).to receive(:ai_settings).and_return(nil)
        end

        it 'returns nil' do
          expect(minimum_access_level).to be_nil
        end
      end

      context 'when root_namespace has ai settings' do
        let(:ai_settings) { create(:namespace_ai_settings) }

        context 'when minimum_access_level_execute is not configured' do
          it 'returns nil' do
            expect(minimum_access_level).to be_nil
          end
        end

        context 'when minimum_access_level_execute is configured' do
          let(:ai_settings) { create(:namespace_ai_settings, minimum_access_level_execute: configured_access_level) }

          it 'returns the configured access level' do
            expect(minimum_access_level).to eq configured_access_level
          end
        end
      end
    end

    context 'when on self-managed' do
      let(:instance_ai_settings) { Ai::Setting.for_organization(root_namespace.organization) }

      context 'when minimum_access_level_execute is not configured' do
        it 'returns nil' do
          expect(minimum_access_level).to be_nil
        end
      end

      context 'when minimum_access_level_execute is configured' do
        before do
          instance_ai_settings.update!(minimum_access_level_execute: configured_access_level)
        end

        it 'returns the configured access level' do
          expect(minimum_access_level).to eq configured_access_level
        end
      end
    end
  end

  describe '#ai_minimum_access_level_execute_async_with_fallback' do
    subject(:minimum_access_level) { root_namespace.ai_minimum_access_level_execute_async_with_fallback }

    context 'when on saas', :saas do
      context 'with a sub group' do
        let(:ai_settings) do
          create(:namespace_ai_settings, minimum_access_level_execute_async: configured_access_level)
        end

        let(:sub_group) { create(:group, parent: root_namespace) }

        it 'uses root_namespace ai settings' do
          result = sub_group.ai_minimum_access_level_execute_async_with_fallback

          expect(result).to eq configured_access_level
        end
      end

      context 'when root_namespace does not have ai settings' do
        before do
          allow(root_namespace).to receive(:ai_settings).and_return(nil)
        end

        it 'returns default developer access level' do
          expect(minimum_access_level).to eq(::Gitlab::Access::DEVELOPER)
        end
      end

      context 'when root_namespace has ai settings' do
        let(:ai_settings) { create(:namespace_ai_settings) }

        context 'when minimum_access_level_execute_async is not configured' do
          it 'returns default developer access level' do
            expect(minimum_access_level).to eq(::Gitlab::Access::DEVELOPER)
          end
        end

        context 'when minimum_access_level_execute_async is configured' do
          let(:ai_settings) do
            create(:namespace_ai_settings, minimum_access_level_execute_async: configured_access_level)
          end

          it 'returns the configured access level' do
            expect(minimum_access_level).to eq configured_access_level
          end
        end
      end
    end

    context 'when on self-managed' do
      let(:instance_ai_settings) { Ai::Setting.for_organization(root_namespace.organization) }

      context 'when minimum_access_level_execute_async is not configured' do
        it 'returns default developer access level' do
          expect(minimum_access_level).to eq(::Gitlab::Access::DEVELOPER)
        end
      end

      context 'when minimum_access_level_execute_async is configured' do
        before do
          instance_ai_settings.update!(minimum_access_level_execute_async: configured_access_level)
        end

        it 'returns the configured access level' do
          expect(minimum_access_level).to eq configured_access_level
        end
      end
    end
  end
end
