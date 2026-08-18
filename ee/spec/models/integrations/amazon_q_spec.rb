# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::AmazonQ, feature_category: :duo_agent_platform do
  it_behaves_like Integrations::Base::AmazonQ
end
