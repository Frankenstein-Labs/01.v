# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::Authorizer, feature_category: :ai_abstraction_layer do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) {  create(:project, group: group) }
  let_it_be_with_reload(:resource) { create(:issue, project: project) }
  let_it_be(:user) { create(:user) }
  let(:container) { project }

  describe '.container' do
    subject(:response) { described_class.container(container: container, user: user) }

    context 'when user is allowed' do
      before do
        allow(user).to receive(:can?).with(:access_duo_features, container).and_return(true)
      end

      it "returns an authorized response" do
        expect(response.allowed?).to be(true)
      end
    end

    context 'when user is not allowed' do
      let(:not_allowed_response) do
        "I am sorry, I cannot access the information you are asking about. " \
          "A group or project owner has turned off Duo features in this group or project."
      end

      let(:not_found_response) do
        "I'm sorry, I can't generate a response. You might want to try again. " \
          "You could also be getting this error because the items you're asking about " \
          "either don't exist, you don't have access to them, or your session has expired."
      end

      before do
        allow(user).to receive(:can?).with(:access_duo_features, container).and_return(false)
      end

      it "returns an error not found response when the user isn't a member of the container" do
        expect(response.allowed?).to be(false)
        expect(response.message).to eq(not_found_response)
      end

      it "returns a not allowed response when the user is a member of the container" do
        container.add_guest(user)

        expect(response.allowed?).to be(false)
        expect(response.message).to eq(not_allowed_response)
      end
    end

    context 'when container is nil' do
      let(:container) { nil }

      it 'handles nil container gracefully' do
        expect { response }.not_to raise_error
        expect(response.allowed?).to be(false)
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'handles nil user gracefully' do
        expect { response }.not_to raise_error
        expect(response.allowed?).to be(false)
      end
    end

    context 'with different container types' do
      context 'with namespace container' do
        let(:container) { create(:namespace) }

        before do
          allow(user).to receive(:can?).with(:access_duo_features, container).and_return(true)
        end

        it 'authorizes namespace containers' do
          expect(response.allowed?).to be(true)
        end
      end

      context 'with personal namespace' do
        let(:container) { user.namespace || create(:user_namespace, owner: user) }

        before do
          allow(user).to receive(:can?).with(:access_duo_features, container).and_return(true)
        end

        it 'authorizes personal namespace' do
          expect(response.allowed?).to be(true)
        end
      end
    end
  end

  describe '.resource' do
    subject(:response) { described_class.resource(resource: resource, user: user) }

    context 'when resource is nil' do
      let(:resource) { nil }

      it 'returns false' do
        expect(response.allowed?).to be(false)
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns false' do
        expect(response.allowed?).to be(false)
      end
    end

    context 'when resource parent is not authorized' do
      it 'returns false' do
        expect(response.allowed?).to be(false)
      end
    end

    context 'when resource container is authorized' do
      it 'calls user.can? with the appropriate arguments' do
        expect(user).to receive(:can?).with('read_issue', resource)

        response
      end
    end

    context 'when resource is current user' do
      let(:resource) { user }

      it 'returns true' do
        expect(response.allowed?).to be(true)
      end
    end

    context 'when resource is different user' do
      let(:resource) { build(:user) }

      it 'returns false' do
        expect(response.allowed?).to be(false)
      end
    end

    context 'with different resource types' do
      context 'with merge request resource' do
        let(:resource) { create(:merge_request, source_project: project) }

        before do
          allow(user).to receive(:can?).with("read_merge_request", resource).and_return(true)
          allow(user).to receive(:can?).with(:access_duo_features, project).and_return(true)
        end

        it 'authorizes merge request access' do
          expect(response.allowed?).to be(true)
        end
      end

      context 'with snippet resource' do
        let(:resource) { create(:project_snippet, project: project) }

        before do
          allow(user).to receive(:can?).with("read_snippet", resource).and_return(true)
          allow(user).to receive(:can?).with(:access_duo_features, project).and_return(true)
        end

        it 'authorizes snippet access' do
          expect(response.allowed?).to be(true)
        end
      end

      context 'with epic resource' do
        let(:resource) { create(:epic, group: group) }

        before do
          allow(user).to receive(:can?).with('read_epic', resource).and_return(true)
          allow(user).to receive(:can?).with(:access_duo_features, group).and_return(true)
        end

        it 'authorizes epic access' do
          expect(response.allowed?).to be(true)
        end
      end
    end

    context 'when resource has no resource_parent' do
      let(:resource) { build(:user) }

      before do
        allow(resource).to receive(:resource_parent).and_return(nil)
        allow(user).to receive(:can?).with("read_user", resource).and_return(true)
      end

      it 'handles resources without parent container' do
        # This would fail at container authorization step
        expect(response.allowed?).to be(false)
      end
    end

    context 'when resource_parent authorization fails' do
      before do
        allow(user).to receive(:can?).with("read_issue", resource).and_return(true)
        allow(user).to receive(:can?).with(:access_duo_features, project).and_return(false)
      end

      it 'returns appropriate message for members' do
        project.add_guest(user) # User is member but features disabled
        expect(response.allowed?).to be(false)
        expect(response.message).to include("turned off Duo features")
      end
    end

    context 'when user lacks read permission on resource' do
      before do
        allow(user).to receive(:can?).with("read_issue", resource).and_return(false)
      end

      it 'returns not found message' do
        expect(response.allowed?).to be(false)
        expect(response.message).to include("don't exist, you don't have access")
      end
    end

    context 'with user as resource scenarios' do
      context 'when resource is same user' do
        let(:resource) { user }

        it 'delegates to user method' do
          expect(described_class).to receive(:user).with(user: user).and_call_original
          response
        end
      end

      context 'when resource is different user' do
        let(:resource) { create(:user) }

        it 'returns not found' do
          expect(response.allowed?).to be(false)
          expect(response.message).to include("don't exist, you don't have access")
        end
      end

      context 'when user resource is nil' do
        let(:resource) { nil }
        let(:user) { nil }

        it 'returns not found' do
          expect(response.allowed?).to be(false)
        end
      end
    end
  end

  describe '.user' do
    subject(:response) { described_class.user(user: user) }

    it 'returns true' do
      expect(response.allowed?).to be(true)
    end
  end
end
