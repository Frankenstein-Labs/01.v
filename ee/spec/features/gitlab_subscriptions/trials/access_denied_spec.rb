# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Ultimate trial access denied flow', :saas_trial, :js, feature_category: :acquisition do
  # rubocop:disable Gitlab/RSpec/AvoidSetup -- reuse of common flow
  it_behaves_like 'duo access denied flow' do
    let(:duo_path) { new_trial_path(namespace_id: non_existing_record_id) }
  end
  # rubocop:enable Gitlab/RSpec/AvoidSetup
end
