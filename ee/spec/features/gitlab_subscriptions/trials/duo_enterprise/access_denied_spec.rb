# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Enterprise trial access denied flow', :saas_trial, :js, feature_category: :acquisition do
  # rubocop:disable Gitlab/RSpec/AvoidSetup -- reuse of common flow
  it_behaves_like 'duo access denied flow' do
    let(:duo_path) { new_trials_duo_enterprise_path }
  end
  # rubocop:enable Gitlab/RSpec/AvoidSetup
end
