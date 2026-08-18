# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllerInstanceLevelScoping, feature_category: :continuous_integration do
  describe 'associations' do
    subject { build(:ci_runner_controller_instance_level_scoping) }

    it 'belongs to runner_controller' do
      is_expected.to belong_to(:runner_controller).class_name('Ci::RunnerController')
                                                  .inverse_of(:instance_level_scoping)
    end
  end
end
