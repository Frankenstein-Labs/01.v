# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'search/show', feature_category: :global_search do
  let(:search_term) { nil }
  let(:user) { build(:user) }
  let(:search_service_presenter) do
    instance_double(SearchServicePresenter,
      without_count?: false,
      advanced_search_enabled?: false,
      zoekt_enabled?: false,
      zoekt_language_aggregations_enabled?: false,
      show_sort_dropdown?: false
    )
  end

  before do
    allow(view).to receive(:current_user) { user }
    allow(view).to receive(:render_if_exists).and_call_original
    allow(view).to receive(:page_description)
    allow(view).to receive(:repository_ref)
    allow(view).to receive(:nav)
    allow(view).to receive(:page_title)
    allow(view).to receive(:breadcrumb_title)
    allow(view).to receive(:page_card_attributes)

    assign(:search_service_presenter, search_service_presenter)
    assign(:scope, 'issues')
    assign(:search_term, 'test')
    assign(:group, nil)
    assign(:project, nil)
    assign(:hide_top_links, true)
  end

  describe 'SSO session expired' do
    let_it_be(:groups_requiring_reauth) { create_list(:group, 2) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- persisted record required
    let(:search_results) do
      instance_double(Gitlab::SearchResults).tap do |double|
        allow(double).to receive(:formatted_count).and_return(0)
        allow(double).to receive(:respond_to?).with(:failed?).and_return(false)
      end
    end

    let(:paginated_objects) do
      Kaminari.paginate_array([]).page(1).tap do |objects|
        allow(objects).to receive(:total_count).and_return(0)
      end
    end

    before do
      assign(:search_results, search_results)
      assign(:search_objects, paginated_objects)

      allow(search_results).to receive(:failed?).with(any_args).and_return(false)
      allow(view).to receive(:render_if_exists).and_call_original

      allow(view).to receive_messages(search_navigation_json: {},
        params: {},
        user_groups_requiring_reauth: groups_requiring_reauth,
        search_service: search_service
      )
    end

    context 'when search type is global' do
      let(:search_service) do
        instance_double(SearchService,
          level: 'global',
          search_type: 'basic',
          scope: 'issues'
        )
      end

      it 'renders the saml reauth notice partial when groups require reauth' do
        render

        expect(view).to have_rendered(partial: 'shared/dashboard/saml_reauth_notice',
          locals: { groups_requiring_saml_reauth: groups_requiring_reauth })
      end

      it 'does not render the saml reauth notice when no groups require reauth' do
        allow(view).to receive(:user_groups_requiring_reauth).and_return([])

        render

        expect(view).not_to have_rendered(partial: 'shared/dashboard/saml_reauth_notice')
      end
    end

    context 'when search level is group' do
      let(:search_service) do
        instance_double(SearchService,
          level: 'group',
          search_type: 'basic',
          scope: 'issues'
        )
      end

      it 'does not render the saml reauth notice partial when groups require reauth' do
        render

        expect(view).not_to have_rendered(partial: 'shared/dashboard/saml_reauth_notice')
      end
    end

    context 'when search level is project' do
      let(:search_service) do
        instance_double(SearchService,
          level: 'project',
          search_type: 'basic',
          scope: 'issues'
        )
      end

      it 'does not render the saml reauth notice partial when groups require reauth' do
        render

        expect(view).not_to have_rendered(partial: 'shared/dashboard/saml_reauth_notice')
      end
    end
  end
end
