# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::MergeRequests::StatusCheckResponseExternalStatusCheck, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:external_status_check) do
    build(:external_status_check, project: project, external_url: 'https://example.com/check?token=secret')
  end

  subject(:entity) { described_class.new(external_status_check, current_user: user).as_json }

  it 'exposes only id, name and external_url, mirroring the read path', :aggregate_failures do
    is_expected.to include(:id, :name, :external_url)
    is_expected.not_to include(:project_id, :hmac, :protected_branches)
  end

  context 'when the user can read the status check URL' do
    before do
      allow(user).to receive(:can?).with(:read_merge_request_status_check_url, project).and_return(true)
    end

    it 'exposes the URL without the query string' do
      expect(entity[:external_url]).to eq('https://example.com/check')
    end
  end

  context 'when the user cannot read the status check URL' do
    before do
      allow(user).to receive(:can?).with(:read_merge_request_status_check_url, project).and_return(false)
    end

    it 'returns an empty string' do
      expect(entity[:external_url]).to eq('')
    end
  end

  context 'when no current_user is given' do
    subject(:entity) { described_class.new(external_status_check).as_json }

    it 'returns an empty string' do
      expect(entity[:external_url]).to eq('')
    end
  end
end
