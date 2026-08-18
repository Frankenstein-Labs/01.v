# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::DetectRepositoryLanguagesService, :clean_gitlab_redis_shared_state, feature_category: :groups_and_projects do
  let_it_be_with_reload(:project) { create(:project) }

  describe '#execute' do
    context 'without previous detection' do
      before do
        stub_ee_application_setting(elasticsearch_indexing?: true)
      end

      it 'calls ProcessBookkeepingService' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(project).once
        described_class.new(project).execute
      end
    end
  end
end
