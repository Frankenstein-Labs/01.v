# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Instance::Streamer, feature_category: :audit_events do
  it_behaves_like 'streamer streaming audit events', :instance
end
