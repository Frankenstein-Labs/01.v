# frozen_string_literal: true

RSpec.shared_examples 'handle quickactions without Duo access' do
  let(:duo_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

  before do
    allow(Gitlab::Duo::CodeReview).to receive(:enabled?)
      .with(user: user, container: project)
      .and_return(has_duo_access)
  end

  context 'when using /assign_reviewer with Duo bot' do
    context 'when user lacks Duo access' do
      let(:has_duo_access) { false }

      context 'when only Duo was assigned as a reviewer' do
        let(:description) { "/assign_reviewer @#{duo_bot.username}" }

        it 'filters out Duo bot and shows access error message' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("You don't have access to GitLab Duo Code Review")
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end

      context 'when a user was assigned with Duo bot' do
        let(:description) { "/assign_reviewer @#{duo_bot.username} @#{user.username}" }

        it 'still assigns a regular reviewer' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("You don't have access to GitLab Duo Code Review")

          expect(merge_request.reload.reviewers).to include(user)
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end
    end

    context 'when user has Duo access' do
      let(:has_duo_access) { true }
      let(:description) { "/assign_reviewer @#{duo_bot.username}" }

      it 'assigns Duo bot as reviewer' do
        send_request

        expect(response).to redirect_to(project_merge_request_path(project, merge_request))

        follow_redirect!

        expect(flash[:alert]).to be_nil
        expect(merge_request.reload.reviewers).to include(duo_bot)
      end
    end
  end

  context 'when using /request_review with Duo bot' do
    let(:description) { "/request_review @#{duo_bot.username}" }

    context 'when user lacks Duo access' do
      let(:has_duo_access) { false }

      context 'when only requesting a review from Duo' do
        it 'filters out Duo bot and shows access error message' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("You don't have access to GitLab Duo Code Review")
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end

      context 'when also requesting a review from a regular user' do
        let(:description) { "/request_review @#{duo_bot.username} @#{user.username}" }

        it 'still requests a review from regular reviewers along with Duo error message' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("You don't have access to GitLab Duo Code Review")
          expect(merge_request.reload.reviewers).to include(user)
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end
    end

    context 'when user has Duo access' do
      let(:description) { "/request_review @#{duo_bot.username}" }
      let(:has_duo_access) { true }

      it 'request review from Duo bot' do
        send_request

        expect(response).to redirect_to(project_merge_request_path(project, merge_request))

        follow_redirect!

        expect(flash[:alert]).to be_nil
        expect(merge_request.reload.reviewers).to include(duo_bot)
      end
    end
  end
end
