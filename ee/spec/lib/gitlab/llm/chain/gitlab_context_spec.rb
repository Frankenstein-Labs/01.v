# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::GitlabContext, :saas, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }
  let_it_be(:project) { create(:project, group: group) }
  let(:resource) { nil }
  let(:ai_request) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:additional_context) do
    [
      { category: 'snippet', id: 'hello world', content: 'puts "Hello, world"', metadata: {} }
    ]
  end

  subject(:context) do
    described_class.new(current_user: user, container: nil, resource: resource, ai_request: ai_request,
      agent_version: nil, additional_context: additional_context)
  end

  include_context 'with duo pro addon'

  before_all do
    group.add_reporter(user)
  end

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.update!(experiment_features_enabled: true)
  end

  describe '#resource_serialized' do
    let(:content_limit) { 500 }

    context 'with an authorized, serializable resource' do
      let(:resource) { create(:issue, project: project) }
      let(:resource_xml) do
        Ai::AiResource::Issue.new(user, resource).serialize_for_ai(content_limit: content_limit)
          .to_xml(root: :root, skip_types: true, skip_instruct: true)
      end

      let(:resource2) { create(:issue, project: project) }
      let(:resource_xml2) do
        Ai::AiResource::Issue.new(user, resource2).serialize_for_ai(content_limit: content_limit)
                             .to_xml(root: :root, skip_types: true, skip_instruct: true)
      end

      before_all do
        group.add_reporter(user)
      end

      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
        stub_licensed_features(ai_chat: true)
        group.namespace_settings.update!(experiment_features_enabled: true)
      end

      it 'returns the AI serialization of the resource' do
        expect(context.resource_serialized(content_limit: content_limit)).to eq(resource_xml)

        context.resource = resource2

        # Do not cache value
        expect(context.resource_serialized(content_limit: content_limit)).to eq(resource_xml2)
      end
    end

    context 'with an unauthorized resource' do
      let(:resource) { create(:issue) }

      it 'returns an empty string' do
        expect(context.resource_serialized(content_limit: content_limit)).to eq('')
      end
    end

    context 'with a non-serializable resource' do
      it 'raises an ArgumentError' do
        expect { context.resource_serialized(content_limit: content_limit) }.to raise_error(ArgumentError)
      end
    end

    context 'when is_duo_code_review is provided' do
      let(:content_limit) { 500 }

      it 'serializes merge request resources' do
        mr = create(:merge_request, source_project: project)
        context = described_class.new(
          current_user: user,
          container: nil,
          resource: mr,
          ai_request: ai_request,
          is_duo_code_review: true
        )

        xml = context.resource_serialized(content_limit: content_limit)
        expect(xml).to include('<root>')
        expect(xml).to include('<target-branch>')
      end

      it 'serializes issue resources' do
        issue = create(:issue, project: project)
        context = described_class.new(
          current_user: user,
          container: nil,
          resource: issue,
          ai_request: ai_request,
          is_duo_code_review: true
        )

        xml = context.resource_serialized(content_limit: content_limit)
        expect(xml).to include('<root>')
        expect(xml).to include('<title>')
      end
    end
  end

  describe '#current_page_params' do
    context 'with an unauthorized resource' do
      let(:resource) { create(:issue) }

      it 'returns nil' do
        expect(context.current_page_params).to be_nil
      end
    end

    context 'with an authorized resource' do
      let(:resource) { create(:issue, project: project) }

      it 'returns resource params' do
        expect(context.current_page_params).to include({ title: resource.title })
      end
    end
  end
end
