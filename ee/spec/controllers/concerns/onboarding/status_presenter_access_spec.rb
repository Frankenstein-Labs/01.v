# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::StatusPresenterAccess, feature_category: :onboarding do
  let_it_be(:current_user) { build(:user) }

  let(:controller_class) do
    Class.new(ApplicationController) do
      include Onboarding::StatusPresenterAccess

      def call_onboarding_status_presenter
        onboarding_status_presenter
      end
    end
  end

  let(:controller) { controller_class.new }

  before do
    allow(controller).to receive(:current_user).and_return(current_user)
  end

  describe '#onboarding_status_presenter' do
    it 'builds the presenter with the default hook values' do
      expect(Onboarding::StatusPresenter).to receive(:new).with({}, nil, current_user).and_call_original

      controller.call_onboarding_status_presenter
    end

    it 'memoizes the presenter' do
      expect(Onboarding::StatusPresenter).to receive(:new).once.and_call_original

      2.times { controller.call_onboarding_status_presenter }
    end

    it 'is registered as a helper method' do
      expect(controller_class._helper_methods).to include(:onboarding_status_presenter)
    end

    context 'when a subclass overrides the hook methods' do
      let(:controller_class) do
        Class.new(ApplicationController) do
          include Onboarding::StatusPresenterAccess

          def call_onboarding_status_presenter
            onboarding_status_presenter
          end

          private

          def onboarding_status_presenter_params
            { foo: 'bar' }
          end

          def onboarding_status_presenter_user_return_to
            '/return/to'
          end

          def onboarding_status_presenter_user
            'overridden_user'
          end
        end
      end

      it 'passes the overridden values through to the presenter constructor' do
        expect(Onboarding::StatusPresenter).to receive(:new).with({ foo: 'bar' }, '/return/to', 'overridden_user')

        controller.call_onboarding_status_presenter
      end
    end
  end
end
