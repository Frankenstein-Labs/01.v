# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Analytics, Value streams: review stage (JavaScript fixtures)', :sidekiq_inline, feature_category: :value_stream_management do
  describe Groups::Analytics::CycleAnalytics::StagesController, type: :controller do
    include_context '[EE] Analytics fixtures shared context'

    render_views

    include_examples 'Analytics > Value stream fixtures', 'review'
  end
end
