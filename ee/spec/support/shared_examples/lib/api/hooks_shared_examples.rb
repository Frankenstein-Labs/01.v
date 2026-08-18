# frozen_string_literal: true

RSpec.shared_examples 'web-hook API endpoints with admin_web_hook custom role' do
  describe 'List hooks' do
    it 'allows access' do
      get api(list_url, user)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'Get hook' do
    it 'allows access' do
      get api(get_url, user)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'Add hook' do
    it 'allows access' do
      post api(add_url, user), params: { url: 'http://example.test/' }

      expect(response).to have_gitlab_http_status(:created)
    end
  end

  describe 'Edit hook' do
    it 'allows access' do
      put api(edit_url, user), params: { url: 'http://example1.test' }

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'Delete hook' do
    it 'allows access' do
      delete api(delete_url, user)

      expect(response).to have_gitlab_http_status(:no_content)
    end
  end
end
