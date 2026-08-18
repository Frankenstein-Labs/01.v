# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageDataCounters::QuickActionActivityUniqueCounter, :clean_gitlab_redis_shared_state, feature_category: :product_analytics do
  let(:user) { build(:user, id: 1) }
  let(:note) { build(:note, author: user) }
  let(:args) { nil }
  let(:project) { build(:project) }

  shared_examples_for 'a tracked quick action internal event' do
    it "triggers an internal event" do
      expect { track_event }.to trigger_internal_events(action).with(
        category: 'InternalEventTracking',
        project: project,
        user: user,
        additional_properties: { label: label }
      )
    end
  end

  subject(:track_event) do
    described_class.track_unique_action(quickaction_name, args: args, user: user, project: project)
  end

  context 'when tracking q', feature_category: :ai_agents do
    using RSpec::Parameterized::TableSyntax

    let(:quickaction_name) { 'q' }

    where(subcommand: (
      ::Ai::AmazonQ::Commands::ISSUE_SUBCOMMANDS +
      ::Ai::AmazonQ::Commands::MERGE_REQUEST_SUBCOMMANDS).uniq)

    with_them do
      it_behaves_like 'a tracked quick action internal event' do
        let(:args) { subcommand.to_s }
        let(:label) { subcommand.to_s }
        let(:action) { 'i_quickactions_q' }
      end
    end
  end
end
