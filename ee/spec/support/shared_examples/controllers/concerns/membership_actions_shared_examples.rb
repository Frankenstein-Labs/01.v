# frozen_string_literal: true

RSpec.shared_examples 'member promotion management' do
  before do
    allow(::Gitlab::CurrentSettings).to receive(:enable_member_promotion_management?).and_return(true)
    allow(License).to receive(:current).and_return(create(:license, plan: License::ULTIMATE_PLAN))
  end

  context 'when members are queued for approval' do
    context 'when all members are queued' do
      it 'indicates that some members were queued for approval' do
        params[:id] = [requester.id, requester2.id]

        put :update, params: params, xhr: true

        expect(requester.reload.human_access).to eq('Guest')
        expect(requester2.reload.human_access).to eq('Guest')
        expect(response).to have_gitlab_http_status(:success)
        expect(json_response).to include('enqueued' => true)
      end
    end

    context 'when some members are queued and some updated' do
      it 'indicates that some members were queued for approval' do
        requester2.update!(access_level: Gitlab::Access::DEVELOPER)

        params[:id] = [requester.id, requester2.id]

        put :update, params: params, xhr: true

        expect(requester.reload.human_access).to eq('Guest')
        expect(requester2.reload.human_access).to eq('Maintainer')
        expect(response).to have_gitlab_http_status(:success)
        expect(json_response).to include({ 'enqueued' => true })
      end
    end
  end

  context 'when all members were promoted' do
    it 'returns { using_license: true }' do
      requester.update!(access_level: Gitlab::Access::REPORTER)

      put :update, params: params, xhr: true

      expect(requester.reload.human_access).to eq('Maintainer')
      expect(response).to have_gitlab_http_status(:success)
      expect(json_response['using_license']).to be_boolean
    end
  end
end
