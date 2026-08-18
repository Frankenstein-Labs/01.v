# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobAiEntity, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
  let(:content_limit) { 100000 }
  let(:entity) do
    described_class.new(
      build,
      user: user,
      resource: Ai::AiResource::Ci::Build.new(user, build),
      content_limit: content_limit,
      request: request
    )
  end

  let_it_be(:project) { create(:project, :public, :repository) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
  let_it_be(:build) { create(:ci_build, :trace_live, project: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
  let(:job_log) { build.trace.raw }
  let(:request) { EntityRequest.new(project: project) }

  before do
    allow(request).to receive(:current_user).and_return(user)
  end

  subject(:basic_entity) { entity.as_json }

  it "exposes basic entity fields" do
    expected_fields = %i[
      id name started complete archived build_path playable scheduled created_at
      queued_at queued_duration updated_at status
    ]

    is_expected.to include(*expected_fields)
  end

  context "with job_log on the entity" do
    let(:build) do
      create(:ci_build, :trace_live, project: project).tap do |build| # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
        Gitlab::ExclusiveLease.skipping_transaction_check do
          build.trace.set(trace_log)
        end
      end
    end

    let(:trace_log) { 'line of log' }

    it "exposes the job_log information" do
      expect(basic_entity[:job_log]).to eq(job_log)
    end

    context 'with job_log over 1000 lines' do
      let(:trace_log) { Array.new(1010, 'line of log').join("\n") }
      let(:job_log_with_limit) { build.trace.raw(last_lines: 1000) }

      it "limits job_log to the last 1000 lines" do
        expect(basic_entity[:job_log]).to eq(job_log_with_limit)
      end
    end

    context 'with job_log over the content limit' do
      let(:content_limit) { 100 }
      let(:trace_log) { Array.new(110, 'line of log').join("\n") }
      let(:job_log_with_limit) { build.trace.raw(last_lines: 1000)&.last(content_limit) }

      it "limits job_log to the last 100 lines" do
        expect(basic_entity[:job_log]).to eq(job_log_with_limit)
      end
    end
  end
end
