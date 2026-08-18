# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Utils::ChatAuthorizer, feature_category: :duo_chat do
  shared_examples 'chat is authorized' do
    it 'returns true' do
      expect(authorizer.context(context: context).allowed?).to be(true)
    end
  end

  shared_examples 'chat is not authorized' do
    it 'returns false' do
      expect(authorizer.context(context: context).allowed?).to be(false)
    end
  end

  include_context 'with duo pro addon'

  context 'for saas', :saas do
    let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
    let_it_be_with_reload(:project) {  create(:project, group: group) }
    let_it_be_with_reload(:resource) { create(:issue, project: project) }
    let_it_be(:user) { create(:user) }
    let(:container) { project }
    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: container,
        resource: resource,
        ai_request: nil
      )
    end

    subject(:authorizer) { described_class }

    before_all do
      group.add_developer(user)
    end

    shared_examples 'user authorization' do
      it 'returns true' do
        expect(authorizer.user(user: user).allowed?).to be(true)
      end
    end

    shared_examples 'chat authorization' do
      context 'when ai chat is available for group' do
        include_context 'with duo features enabled and ai chat available for group on SaaS'

        it_behaves_like 'chat is authorized'

        context 'when duo features disabled for group' do
          let(:container) { group }

          include_context 'with duo features disabled and ai chat available for group on SaaS'

          it_behaves_like 'chat is not authorized'
        end
      end

      context 'when ai chat is not available for group' do
        include_context 'with duo features enabled and ai chat not available for group on SaaS'

        context 'when user belongs to another group with ai chat available' do
          it_behaves_like 'chat is authorized'
        end

        context 'when user does not belong to a group with ai chat available' do
          before do
            group.users.first.destroy!
          end

          it_behaves_like 'chat is not authorized'
        end
      end
    end

    describe '.context.allowed?' do
      context 'when current user is not present' do
        let(:user) { nil }

        it_behaves_like 'chat is not authorized'
      end

      context 'when both resource and container are present' do
        context 'when container is authorized' do
          context 'when resource is authorized' do
            it_behaves_like 'chat authorization'
          end

          context 'when resource is not authorized' do
            let(:response) do
              "I'm sorry, I can't generate a response. You might want to try again. " \
                "You could also be getting this error because the items you're asking about " \
                "either don't exist, you don't have access to them, or your session has expired."
            end

            before do
              group.members.first.destroy!
            end

            it 'returns not found message' do
              expect(authorizer.context(context: context).message).to eq(response)
            end

            it_behaves_like 'chat is not authorized'
          end
        end

        context 'when container is not authorized' do
          let(:response) do
            "I am sorry, I cannot access the information you are asking about. " \
              "A group or project owner has turned off Duo features in this group or project."
          end

          before do
            project.update!(duo_features_enabled: false)
          end

          it 'returns not allowed message' do
            expect(authorizer.context(context: context).message).to eq(response)
          end

          it_behaves_like 'chat is not authorized'
        end
      end

      context 'when only resource is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: resource,
            ai_request: nil
          )
        end

        context 'when resource is authorized' do
          it_behaves_like 'chat is authorized'

          context 'when user does not belong to a group with ai chat available' do
            before do
              group.users.first.destroy!
            end

            it_behaves_like 'chat is not authorized'
          end
        end

        context 'when resource is not authorized' do
          before do
            project.update!(duo_features_enabled: false)
          end

          it_behaves_like 'chat is not authorized'
        end
      end

      context 'when only container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: container,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when container is authorized' do
          it_behaves_like 'chat authorization'
        end

        context 'when container is not authorized' do
          before do
            project.update!(duo_features_enabled: false)
          end

          it_behaves_like 'chat is not authorized'
        end
      end

      context 'when neither resource nor container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when user is authorized' do
          it_behaves_like 'chat is authorized'
        end

        context 'when user is not authorized' do
          let(:context) do
            Gitlab::Llm::Chain::GitlabContext.new(
              current_user: create(:user),
              container: nil,
              resource: nil,
              ai_request: nil
            )
          end

          it_behaves_like 'chat is not authorized'
        end
      end
    end

    describe '.container' do
      shared_examples 'container authorizer' do
        before do
          allow(user).to receive(:can?).with(:access_duo_features, container).and_return(duo_features_enabled)
        end

        context 'when container has duo_features enabled' do
          let(:duo_features_enabled) { true }

          it "calls policy with the appropriate arguments" do
            expect(user).to receive(:can?).with(:access_duo_entry_point)

            authorizer.container(container: container, user: user)
          end
        end

        context 'when container has duo_features disabled' do
          let(:duo_features_enabled) { false }

          it 'returns an unauthorized response' do
            expect(authorizer.container(container: container, user: user).allowed?).to be(false)
          end
        end
      end

      it_behaves_like 'container authorizer'

      context 'with a group' do
        let(:container) { create(:group) }

        before do
          allow(user).to receive(:can?).with(:update_organization, container.organization).and_call_original
          allow(user).to receive(:can?).with(:admin_all_resources).and_call_original
        end

        it_behaves_like 'container authorizer'
      end
    end

    describe '.resource' do
      context 'when resource is nil' do
        let(:resource) { nil }

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when resource parent is not authorized' do
        before do
          project.update!(duo_features_enabled: false)
        end

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when resource container is authorized' do
        it 'calls user.can? with the appropriate arguments' do
          expect(user).to receive(:can?).with('read_issue', resource)

          authorizer.resource(resource: context.resource, user: context.current_user)
        end
      end

      context 'when resource is current user' do
        context 'when user is not in any group with ai' do
          # we use 'with duo pro addon' that will assign a seat in addon for
          # `current_user` or `user` if this variable is defined
          # that's why we need to use here a variable with a different name
          let(:new_user) { create(:user) }

          it 'returns false' do
            expect(authorizer.resource(resource: new_user, user: new_user).allowed?)
              .to be(false)
          end
        end

        context 'when user is in a group with ai' do
          it 'returns true' do
            expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
              .to be(true)
          end

          context 'when resource is different user' do
            let(:resource) { build(:user) }

            it 'returns false' do
              expect(authorizer.resource(resource: resource, user: context.current_user).allowed?)
                .to be(false)
            end
          end
        end
      end

      context 'when in merge request review context with confidential resources' do
        let(:confidential_issue) { create(:issue, :confidential, project: project) }
        let(:public_issue) { create(:issue, project: project) }
        let(:merge_request) { create(:merge_request, project: project) }

        before do
          project.update!(duo_features_enabled: true)
        end

        context 'when context is duo code review' do
          let(:duo_code_review_context) do
            context = Gitlab::Llm::Chain::GitlabContext.new(
              current_user: user,
              container: project,
              resource: confidential_issue,
              ai_request: nil
            )
            context.instance_variable_set(:@is_duo_code_review, true)
            context
          end

          it 'denies access to confidential resources' do
            response = authorizer.resource(
              resource: confidential_issue,
              user: user,
              context: duo_code_review_context
            )

            expect(response.allowed?).to be(false)
            expect(response.message).to include("don't exist, you don't have access")
          end

          it 'allows access to public resources' do
            response = authorizer.resource(
              resource: public_issue,
              user: user,
              context: duo_code_review_context
            )

            expect(response.allowed?).to be(true)
          end
        end

        context 'when context is not duo code review' do
          let(:normal_context) do
            Gitlab::Llm::Chain::GitlabContext.new(
              current_user: user,
              container: project,
              resource: confidential_issue,
              ai_request: nil
            )
          end

          it 'allows access to confidential resources for authorized users' do
            response = authorizer.resource(
              resource: confidential_issue,
              user: user,
              context: normal_context
            )

            expect(response.allowed?).to be(true)
          end
        end

        context 'when context is nil' do
          it 'falls back to parent class behavior' do
            response = authorizer.resource(
              resource: confidential_issue,
              user: user,
              context: nil
            )

            expect(response.allowed?).to be(true)
          end
        end

        context 'when resource does not respond to confidential?' do
          let(:non_confidential_resource) { create(:user) }
          let(:duo_code_review_context) do
            context = Gitlab::Llm::Chain::GitlabContext.new(
              current_user: user,
              container: project,
              resource: non_confidential_resource,
              ai_request: nil
            )
            context.instance_variable_set(:@is_duo_code_review, true)
            context
          end

          it 'allows access to resources without confidential? method' do
            response = authorizer.resource(
              resource: non_confidential_resource,
              user: user,
              context: duo_code_review_context
            )

            expect(response.allowed?).to be(false) # User resource authorization
          end
        end

        context 'when resource is nil' do
          let(:duo_code_review_context) do
            context = Gitlab::Llm::Chain::GitlabContext.new(
              current_user: user,
              container: project,
              resource: nil,
              ai_request: nil
            )
            context.instance_variable_set(:@is_duo_code_review, true)
            context
          end

          it 'returns not found for nil resource' do
            response = authorizer.resource(
              resource: nil,
              user: user,
              context: duo_code_review_context
            )

            expect(response.allowed?).to be(false)
          end
        end
      end

      # Test edge cases for private methods
      describe 'private method behavior' do
        context 'when testing merge_request_review_context?' do
          it 'returns false for nil context' do
            expect(
              authorizer.send(:merge_request_review_context?, nil)
            ).to be(false)
          end

          it 'returns false when @is_duo_code_review is not set' do
            context = Gitlab::Llm::Chain::GitlabContext.new(
              current_user: user,
              container: project,
              resource: resource,
              ai_request: nil
            )

            expect(
              authorizer.send(:merge_request_review_context?, context)
            ).to be(false)
          end

          it 'returns false when @is_duo_code_review is false' do
            context = Gitlab::Llm::Chain::GitlabContext.new(
              current_user: user,
              container: project,
              resource: resource,
              ai_request: nil
            )
            context.instance_variable_set(:@is_duo_code_review, false)

            expect(
              authorizer.send(:merge_request_review_context?, context)
            ).to be(false)
          end

          it 'returns true when @is_duo_code_review is true' do
            context = Gitlab::Llm::Chain::GitlabContext.new(
              current_user: user,
              container: project,
              resource: resource,
              ai_request: nil
            )
            context.instance_variable_set(:@is_duo_code_review, true)

            expect(
              authorizer.send(:merge_request_review_context?, context)
            ).to be(true)
          end
        end

        context 'when testing confidential_resource?' do
          it 'returns false for nil resource' do
            expect(
              authorizer.send(:confidential_resource?, nil)
            ).to be(false)
          end

          it 'returns false for resource without confidential? method' do
            resource_without_confidential = create(:user)

            expect(
              authorizer.send(:confidential_resource?, resource_without_confidential)
            ).to be(false)
          end

          it 'returns false for non-confidential resource' do
            public_issue = create(:issue, project: project)

            expect(
              authorizer.send(:confidential_resource?, public_issue)
            ).to be(false)
          end

          it 'returns true for confidential resource' do
            confidential_issue = create(:issue, :confidential, project: project)

            expect(
              authorizer.send(:confidential_resource?, confidential_issue)
            ).to be(true)
          end
        end
      end
    end

    describe '.user' do
      it_behaves_like 'user authorization'
    end
  end

  context 'for self-managed', :with_cloud_connector do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) {  create(:project, group: group) }
    let_it_be_with_reload(:resource) { create(:issue, project: project) }
    let_it_be(:user) { create(:user) }
    let(:container) { project }
    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: container,
        resource: resource,
        ai_request: nil
      )
    end

    subject(:authorizer) { described_class }

    before_all do
      group.add_developer(user)
    end

    shared_examples 'user authorization' do
      context 'when ai is enabled for self-managed' do
        context 'when chat is enabled' do
          include_context 'with duo features enabled and ai chat available for self-managed'

          it 'returns true' do
            expect(authorizer.user(user: user).allowed?).to be(true)
          end
        end
      end

      context 'when ai is disabled by default for self-managed' do
        include_context 'with duo features disabled and ai chat available for self-managed'

        it 'returns true when user has no groups with ai available' do
          expect(authorizer.user(user: user).allowed?).to be(true)
        end
      end
    end

    shared_examples 'chat authorization' do
      context 'when ai chat is enabled' do
        include_context 'with duo features enabled and ai chat available for self-managed'

        it_behaves_like 'chat is authorized'
      end
    end

    describe '.context.allowed?' do
      context 'when both resource and container are present' do
        context 'when ai is enabled for self-managed' do
          context 'when both resource and container is authorized' do
            it_behaves_like 'chat authorization'
          end

          context 'when resource is not authorized' do
            let(:response) do
              "I'm sorry, I can't generate a response. You might want to try again. " \
                "You could also be getting this error because the items you're asking about " \
                "either don't exist, you don't have access to them, or your session has expired."
            end

            before do
              group.members.first.destroy!
            end

            it 'returns not found message' do
              expect(authorizer.context(context: context).message).to include(response)
            end

            it_behaves_like 'chat is not authorized'
          end

          context 'when container is not authorized' do
            let(:response) do
              "I am sorry, I cannot access the information you are asking about. " \
                "A group or project owner has turned off Duo features in this group or project."
            end

            before do
              project.update!(duo_features_enabled: false)
            end

            it 'returns not allowed message' do
              expect(authorizer.context(context: context).message).to eq(response)
            end

            it_behaves_like 'chat is not authorized'
          end
        end

        context 'when ai is disabled by default for self-managed' do
          include_context 'with duo features disabled and ai chat available for self-managed'

          it_behaves_like 'chat authorization'
        end

        context 'when ai is always off for self-managed' do
          include_context 'with duo features always off for self-managed'

          it_behaves_like 'chat is not authorized'
        end
      end

      context 'when only resource is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: resource,
            ai_request: nil
          )
        end

        context 'when ai is enabled for self-managed' do
          it_behaves_like 'chat authorization'
        end

        context 'when ai is disabled by default for self-managed' do
          include_context 'with duo features disabled and ai chat available for self-managed'

          it_behaves_like 'chat authorization'
        end

        context 'when ai is always off for self-managed' do
          include_context 'with duo features always off for self-managed'

          it_behaves_like 'chat is not authorized'
        end
      end

      context 'when only container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: container,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when ai is enabled for self-managed' do
          it_behaves_like 'chat authorization'
        end

        context 'when ai is disabled by default for self-managed' do
          include_context 'with duo features disabled and ai chat available for self-managed'

          it_behaves_like 'chat authorization'
        end

        context 'when ai is always off for self-managed' do
          include_context 'with duo features always off for self-managed'

          it_behaves_like 'chat is not authorized'
        end
      end

      context 'when neither resource nor container is present' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: nil,
            ai_request: nil
          )
        end

        context 'when ai is enabled for self-managed' do
          it_behaves_like 'chat authorization'
        end

        context 'when ai is disabled by default for self-managed' do
          include_context 'with duo features disabled and ai chat available for self-managed'

          it_behaves_like 'chat authorization'
        end

        context 'when ai is always off for self-managed' do
          include_context 'with duo features always off for self-managed'

          it_behaves_like 'chat is not authorized'
        end
      end
    end

    describe '.resource' do
      context 'when resource is nil' do
        let(:resource) { nil }

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when ai is disabled by default for self-managed' do
        include_context 'with duo features disabled and ai chat available for self-managed'

        it 'returns true' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(true)
        end
      end

      context 'when ai is enabled for self-managed' do
        include_context 'with duo features enabled and ai chat available for self-managed'

        it 'calls user.can? with the appropriate arguments' do
          expect(user).to receive(:can?).with('read_issue', resource)

          authorizer.resource(resource: context.resource, user: context.current_user)
        end
      end

      context 'when ai is always off for self-managed' do
        include_context 'with duo features always off for self-managed'

        it 'returns false' do
          expect(authorizer.resource(resource: context.resource, user: context.current_user).allowed?)
            .to be(false)
        end
      end

      context 'when resource is current user' do
        context 'when ai is disabled by default for self-managed' do
          include_context 'with duo features disabled and ai chat available for self-managed'

          it 'returns true' do
            expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
              .to be(true)
          end
        end

        context 'when ai is always off for self-managed' do
          include_context 'with duo features always off for self-managed'

          it 'returns false' do
            expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
              .to be(false)
          end
        end

        context 'when ai is enabled for self-managed' do
          context 'when chat is enabled' do
            include_context 'with duo features enabled and ai chat available for self-managed'

            it 'returns true' do
              expect(authorizer.resource(resource: context.current_user, user: context.current_user).allowed?)
                .to be(true)
            end

            context 'when resource is different user' do
              let(:resource) { build(:user) }

              it 'returns false' do
                expect(authorizer.resource(resource: resource, user: context.current_user).allowed?)
                  .to be(false)
              end
            end
          end
        end
      end
    end

    describe '.user' do
      it_behaves_like 'user authorization'
    end
  end
end
