# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Filters::ConfidentialityFilterContext, feature_category: :global_search do
  let(:user) { build(:user) }
  let(:options) do
    {
      confidential: nil,
      current_user: user,
      min_access_level_confidential: 30,
      min_access_level_confidential_public_internal: 20
    }
  end

  subject(:filter_context) { described_class.new(options) }

  describe '#initialize' do
    it 'sets the confidential attribute' do
      expect(filter_context.confidential).to eq(options[:confidential])
    end

    it 'sets the user attribute from current_user option' do
      expect(filter_context.user).to eq(user)
    end

    it 'sets default filter_path when not provided' do
      expect(filter_context.filter_path).to eq([:query, :bool, :filter])
    end

    it 'uses custom filter_path when provided' do
      custom_options = options.merge(filter_path: [:custom, :path])
      context = described_class.new(custom_options)

      expect(context.filter_path).to eq([:custom, :path])
    end

    it 'sets an auth attribute build from user' do
      expect(::Search::AuthorizationContext).to receive(:new).with(user).and_call_original

      expect(filter_context.auth).to be_an_instance_of(::Search::AuthorizationContext)
    end
  end

  describe '#confidential_only?' do
    context 'when confidential is true' do
      let(:options) { super().merge(confidential: true) }

      it 'returns true' do
        expect(filter_context.confidential_only?).to be true
      end
    end

    context 'when confidential is false' do
      let(:options) { super().merge(confidential: false) }

      it 'returns false' do
        expect(filter_context.confidential_only?).to be false
      end
    end

    context 'when confidential is nil' do
      let(:options) { super().merge(confidential: nil) }

      it 'returns false' do
        expect(filter_context.confidential_only?).to be false
      end
    end
  end

  describe '#non_confidential_only?' do
    context 'when confidential is false' do
      let(:options) { super().merge(confidential: false) }

      it 'returns true' do
        expect(filter_context.non_confidential_only?).to be true
      end
    end

    context 'when confidential is true' do
      let(:options) { super().merge(confidential: true) }

      it 'returns false' do
        expect(filter_context.non_confidential_only?).to be false
      end
    end

    context 'when confidential is nil' do
      let(:options) { super().merge(confidential: nil) }

      it 'returns false' do
        expect(filter_context.non_confidential_only?).to be false
      end
    end
  end

  describe '#confidential_filter_specified?' do
    context 'when confidential is true' do
      let(:options) { super().merge(confidential: true) }

      it 'returns true' do
        expect(filter_context.confidential_filter_specified?).to be true
      end
    end

    context 'when confidential is false' do
      let(:options) { super().merge(confidential: false) }

      it 'returns true' do
        expect(filter_context.confidential_filter_specified?).to be true
      end
    end

    context 'when confidential is nil' do
      let(:options) { super().merge(confidential: nil) }

      it 'returns false' do
        expect(filter_context.confidential_filter_specified?).to be false
      end
    end

    context 'when confidential is a string' do
      let(:options) { super().merge(confidential: 'true') }

      it 'returns false' do
        expect(filter_context.confidential_filter_specified?).to be false
      end
    end
  end

  describe '#min_access_level_confidential' do
    it 'returns the min_access_level_confidential from options' do
      expect(filter_context.min_access_level_confidential).to eq(30)
    end

    context 'when min_access_level_confidential is not provided' do
      let(:options) { super().except(:min_access_level_confidential) }

      it 'raises KeyError' do
        expect { filter_context.min_access_level_confidential }.to raise_error(KeyError)
      end
    end
  end

  describe '#min_access_level_confidential_public_internal' do
    it 'returns the min_access_level_confidential_public_internal from options' do
      expect(filter_context.min_access_level_confidential_public_internal).to eq(20)
    end

    context 'when min_access_level_confidential_public_internal is not provided' do
      let(:options) { super().except(:min_access_level_confidential_public_internal) }

      it 'raises KeyError' do
        expect { filter_context.min_access_level_confidential_public_internal }.to raise_error(KeyError)
      end
    end
  end

  describe '#traversal_ids_field' do
    it 'returns the default TRAVERSAL_IDS_FIELD when traversal_ids_prefix not provided' do
      expect(filter_context.traversal_ids_field).to eq(Search::Elastic::Filters::TRAVERSAL_IDS_FIELD)
    end

    context 'when traversal_ids_prefix is provided in options' do
      let(:options) { super().merge(traversal_ids_prefix: 'custom_traversal_ids') }

      it 'returns the custom traversal_ids_prefix as a symbol' do
        expect(filter_context.traversal_ids_field).to eq(:custom_traversal_ids)
      end
    end
  end

  describe '#project_id_field' do
    it 'returns the default PROJECT_ID_FIELD when project_id_field not provided' do
      expect(filter_context.project_id_field).to eq(Search::Elastic::Filters::PROJECT_ID_FIELD)
    end

    context 'when project_id_field is provided in options' do
      let(:options) { super().merge(project_id_field: 'custom_project_id_field') }

      it 'returns the custom project_id_field as a symbol' do
        expect(filter_context.project_id_field).to eq(:custom_project_id_field)
      end
    end
  end

  describe '#confidential_field' do
    it 'returns the default :confidential when confidential_field not provided' do
      expect(filter_context.confidential_field).to eq(:confidential)
    end

    context 'when confidential_field is provided in options' do
      let(:options) { super().merge(confidential_field: 'issue.confidential') }

      it 'returns the custom confidential_field as a symbol' do
        expect(filter_context.confidential_field).to eq(:"issue.confidential")
      end
    end
  end

  describe '#author_id_field' do
    it 'returns the default :author_id when author_id_field not provided' do
      expect(filter_context.author_id_field).to eq(:author_id)
    end

    context 'when author_id_field is provided in options' do
      let(:options) { super().merge(author_id_field: 'issue.author_id') }

      it 'returns the custom author_id_field as a symbol' do
        expect(filter_context.author_id_field).to eq(:"issue.author_id")
      end
    end
  end

  describe '#assignee_id_field' do
    it 'returns the default :assignee_id when assignee_id_field not provided' do
      expect(filter_context.assignee_id_field).to eq(:assignee_id)
    end

    context 'when assignee_id_field is provided in options' do
      let(:options) { super().merge(assignee_id_field: 'issue.assignee_id') }

      it 'returns the custom assignee_id_field as a symbol' do
        expect(filter_context.assignee_id_field).to eq(:"issue.assignee_id")
      end
    end
  end
end
