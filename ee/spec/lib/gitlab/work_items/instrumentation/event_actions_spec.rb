# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::WorkItems::Instrumentation::EventActions, feature_category: :team_planning do
  describe 'EE-only event constants' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:namespace) { project.namespace }

    ee_only_events = [
      described_class::AGENT_PLAN_CREATE,
      described_class::AGENT_PLAN_DESTROY,
      described_class::AGENT_PLAN_UPDATE
    ]

    ee_only_events.each do |event_name|
      it "defines a valid internal event for '#{event_name}'" do
        expect do
          Gitlab::InternalEvents.track_event(event_name, user: user, project: project, namespace: namespace)
        end.not_to raise_error
      end
    end
  end
end
