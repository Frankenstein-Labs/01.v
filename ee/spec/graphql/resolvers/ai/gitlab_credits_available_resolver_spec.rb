# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::GitlabCreditsAvailableResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }

  describe '#resolve' do
    context 'when user is nil' do
      let(:current_user) { nil }

      subject(:result) { resolve(described_class, ctx: { current_user: current_user }) }

      it 'returns false' do
        expect(result).to be(false)
      end
    end

    context 'when user is present' do
      let(:current_user) { user }
      let(:duo_chat_instance) { instance_double(::Gitlab::Llm::DuoChat) }

      before do
        allow(::Gitlab::Llm::DuoChat).to receive(:new).and_return(duo_chat_instance)
      end

      context 'when namespace_id is not provided' do
        subject(:result) { resolve(described_class, ctx: { current_user: current_user }) }

        context 'when credits are available' do
          before do
            allow(duo_chat_instance).to receive(:credits_available?).and_return(true)
          end

          it 'returns true' do
            expect(result).to be(true)
          end

          it 'instantiates DuoChat with nil group' do
            result

            expect(::Gitlab::Llm::DuoChat).to have_received(:new).with(
              user: current_user,
              group: nil
            )
          end
        end

        context 'when credits are not available' do
          before do
            allow(duo_chat_instance).to receive(:credits_available?).and_return(false)
          end

          it 'returns false' do
            expect(result).to be(false)
          end
        end
      end

      context 'when namespace_id is nil' do
        subject(:result) do
          resolve(described_class, args: { namespace_id: nil },
            ctx: { current_user: current_user })
        end

        before do
          allow(duo_chat_instance).to receive(:credits_available?).and_return(true)
        end

        it 'passes nil as group' do
          result

          expect(::Gitlab::Llm::DuoChat).to have_received(:new).with(
            user: current_user,
            group: nil
          )
        end

        it 'returns the credits_available? result' do
          expect(result).to be(true)
        end
      end

      context 'when namespace_id is provided' do
        let_it_be(:provided_namespace) { create(:group) }

        subject(:result) do
          resolve(described_class, args: { namespace_id: provided_namespace.to_global_id },
            ctx: { current_user: current_user })
        end

        before do
          allow(duo_chat_instance).to receive(:credits_available?).and_return(true)
        end

        it 'uses the provided namespace instead of default' do
          result

          expect(::Gitlab::Llm::DuoChat).to have_received(:new).with(
            user: current_user,
            group: provided_namespace
          )
        end

        it 'does not look up default namespace' do
          allow(current_user.user_preference).to receive(:duo_default_namespace_with_fallback)

          result

          expect(current_user.user_preference).not_to have_received(:duo_default_namespace_with_fallback)
        end
      end
    end
  end
end
