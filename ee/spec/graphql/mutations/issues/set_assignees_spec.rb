# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Issues::SetAssignees, feature_category: :api do
  it_behaves_like 'a multi-assignable resource' do
    let_it_be_with_reload(:resource) { create(:issue) }
  end
end
