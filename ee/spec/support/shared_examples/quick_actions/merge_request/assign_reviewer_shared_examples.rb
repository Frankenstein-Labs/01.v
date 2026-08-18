# frozen_string_literal: true

RSpec.shared_examples 'assigns one or more reviewers to the merge request' do |example|
  context 'when assigning regular reviewers' do
    before do
      target.reviewers = [reviewer]
    end

    it 'adds multiple reviewers from the list' do
      _, update_params, message = service.execute(note)

      expected_format = example[:multiline] ? /Requested a review from @\w+. Requested a review from @\w+./ : /Requested a review from @\w+ and @\w+./

      expect(message).to match(expected_format)
      expect(message).to include("@#{reviewer.username}")
      expect(message).to include("@#{user.username}")

      expect(update_params[:reviewer_ids]).to match_array([user.id, reviewer.id])
      expect { service.apply_updates(update_params, note) }.not_to raise_error
    end
  end

  context 'when assigning Duo bot as reviewer' do
    let(:duo_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }
    let(:has_duo_access) { false }
    let(:note) { create(:note_on_merge_request, note: note_text, noteable: merge_request, project: project) }

    before do
      allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(has_duo_access)
      target.duo_code_review_attempted = nil
    end

    context 'when user lacks Duo access' do
      let(:has_duo_access) { false }
      let(:note_text) { "/assign_reviewer @#{duo_bot.username}" }

      it 'filters out Duo bot and shows access error message' do
        _, update_params, message = service.execute(note)

        expect(message).to include("You don't have access to GitLab Duo Code Review")
        expect(update_params[:reviewer_ids]).to be_nil
        expect(target.duo_code_review_attempted).to eq(:manual)
      end

      context 'when also assigning a regular user' do
        let(:note_text) { "/assign_reviewer @#{duo_bot.username} @#{user.username}" }

        it 'still assigns regular reviewers along with Duo error message' do
          _, update_params, message = service.execute(note)

          expect(message).to include("You don't have access to GitLab Duo Code Review")
          expect(message).to include("Requested a review from @#{user.username}")
          expect(update_params[:reviewer_ids]).to contain_exactly(user.id)
          expect(target.duo_code_review_attempted).to eq(:manual)
        end
      end
    end

    context 'when user has Duo access' do
      let(:has_duo_access) { true }
      let(:note_text) { "/assign_reviewer @#{duo_bot.username}" }

      it 'includes Duo bot in reviewers' do
        _, update_params, message = service.execute(note)

        expect(message).to include("Requested a review from @#{duo_bot.username}")
        expect(update_params[:reviewer_ids]).to contain_exactly(duo_bot.id)
        expect(target.duo_code_review_attempted).to be_nil
      end
    end
  end
end
