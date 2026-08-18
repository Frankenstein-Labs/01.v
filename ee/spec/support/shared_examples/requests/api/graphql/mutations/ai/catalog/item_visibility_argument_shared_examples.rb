# frozen_string_literal: true

# Shared examples for the `public`/`visibility` arguments on AI Catalog item
# create and update mutations.
#
# Including specs must define:
# - `execute`: the subject that posts the mutation.
# - `params`: the mutation arguments, including `public`.
# - `mutation_name`: the GraphQL mutation key (for example, `:ai_catalog_agent_create`).
# For update shared examples, also define:
# - `visibility_item`: the catalog item record to reload and assert against.
RSpec.shared_examples 'an AI catalog mutation with a visibility argument' do
  context 'when both public and visibility are provided' do
    let(:params) { super().merge(public: true) }

    it 'returns a mutually exclusive arguments error' do
      execute

      expect(graphql_errors.first['message']).to include(mutually_exclusive_error_message)
    end
  end

  context 'when ai_catalog_internal_visibility feature flag is disabled' do
    before do
      stub_feature_flags(ai_catalog_internal_visibility: false)
    end

    context 'when visibility is RESTRICTED' do
      it 'returns a restricted visibility not available error' do
        execute

        expect(graphql_errors.first['message']).to include('`restricted` visibility is not available')
      end
    end

    context 'when visibility is PUBLIC' do
      let(:params) { super().merge(visibility: 'PUBLIC') }

      it 'does not return an error' do
        execute

        expect(graphql_errors).to be_blank
      end
    end

    context 'when visibility is PRIVATE' do
      let(:params) { super().merge(visibility: 'PRIVATE') }

      it 'does not return an error' do
        execute

        expect(graphql_errors).to be_blank
      end
    end
  end
end

RSpec.shared_examples 'an AI catalog create mutation with a visibility argument' do
  let(:mutually_exclusive_error_message) { 'One and only one of [public, visibility] arguments is required.' }

  it_behaves_like 'an AI catalog mutation with a visibility argument'

  context 'when visibility is provided instead of public' do
    it 'creates an item with the given visibility' do
      execute

      expect(graphql_data_at(mutation_name, :item, :visibility)).to eq('RESTRICTED')
      expect(Ai::Catalog::Item.last).to have_attributes(visibility: 'restricted', public: false)
    end

    context 'when ai_catalog_internal_visibility feature flag is disabled' do
      before do
        stub_feature_flags(ai_catalog_internal_visibility: false)
      end

      it 'does not create an item' do
        expect { execute }.not_to change { Ai::Catalog::Item.count }
      end
    end
  end

  context 'when neither public nor visibility are provided' do
    let(:params) { super().except(:visibility) }

    it 'returns an exactly-one-of arguments error' do
      execute

      expect(graphql_errors.first['message']).to include(mutually_exclusive_error_message)
    end
  end
end

RSpec.shared_examples 'an AI catalog update mutation with a visibility argument' do
  let(:mutually_exclusive_error_message) { 'Only one of [public, visibility] arguments is allowed at the same time.' }

  it_behaves_like 'an AI catalog mutation with a visibility argument'

  context 'when visibility is provided instead of public' do
    it 'updates the item with the given visibility' do
      execute

      expect(graphql_data_at(mutation_name, :item, :visibility)).to eq('RESTRICTED')
      expect(visibility_item.reload).to have_attributes(visibility: 'restricted', public: false)
    end
  end
end
