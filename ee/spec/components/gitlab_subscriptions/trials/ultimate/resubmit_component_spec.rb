# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::Ultimate::ResubmitComponent, feature_category: :acquisition do
  it_behaves_like 'resubmit component'
  it_behaves_like 'resubmit component with data attributes'
end
