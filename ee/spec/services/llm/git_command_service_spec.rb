# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GitCommandService, feature_category: :code_review_workflow do
  subject { described_class.new(current_user, user, options) }

  describe '#perform', :saas do
    let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:user) { create(:user) }
    let_it_be(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
    end

    let_it_be(:seat_assignment) do
      create(
        :gitlab_subscription_user_add_on_assignment,
        user: user,
        add_on_purchase: add_on_purchase
      )
    end

    let(:current_user) { user }
    let(:options) { { prompt: 'list 10 commit titles' } }
    let(:response) { instance_double(HTTParty::Response, body: %("This is a response."), success?: true) }

    include_context 'with ai features enabled for group'

    before_all do
      group.add_developer(user)
    end

    shared_examples 'performing requests' do
      it 'responds successfully' do
        response = subject.execute

        expect(response).to be_success
        expect(response.payload).to eq({
          predictions: [
            {
              candidates: [
                {
                  content: 'This is a response.'
                }
              ]
            }
          ]
        })
      end
    end

    before do
      allow_next_instance_of(
        ::Gitlab::Llm::AiGateway::Client,
        current_user,
        unit_primitive_name: :glab_ask_git_command,
        tracking_context: {},
        namespace_id: nil,
        project_id: nil,
        governing_namespace_id: nil
      ) do |client|
        allow(client).to receive(:complete_prompt).and_return(response)
      end
    end

    it_behaves_like 'performing requests'

    it 'returns an error when messages are too big' do
      stub_const("#{described_class}::INPUT_CONTENT_LIMIT", 4)

      expect(subject.execute).to be_error
    end

    it 'tracks user AI feature utilization',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/5274' do
      expect(Gitlab::Tracking::AiTracking).to receive(:track_user_activity).with(user)

      subject.execute
    end
  end
end
