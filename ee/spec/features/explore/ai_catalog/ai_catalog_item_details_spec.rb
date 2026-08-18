# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog Item Details', :js, :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :in_group, maintainers: user) }

  before do
    enable_ai_catalog
    sign_in(user)
  end

  (Ai::Catalog::Item.item_types.keys - ['foundational_agent']).each do |item_type_name|
    describe "#{item_type_name.humanize} detail page" do
      let_it_be(:item) do
        create(:"ai_catalog_#{item_type_name}", :public, project: project, name: "Test #{item_type_name.humanize}")
      end

      it "displays #{item_type_name} name when visiting #{item_type_name} detail URL" do
        url = Gitlab::UrlBuilder.build(item, only_path: true)

        visit url

        expect(page).to have_content("Test #{item_type_name.humanize}")
      end
    end
  end
end
