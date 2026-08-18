# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Concerns::XrayContext, feature_category: :code_suggestions do
  let_it_be(:project) { create(:project) }
  let(:language) { instance_double(::CodeSuggestions::ProgrammingLanguage, x_ray_lang: 'ruby') }

  let(:dummy_class) do
    Class.new do
      include Gitlab::Llm::Chain::Concerns::XrayContext
      attr_reader :project, :language

      def initialize(project, language)
        @project = project
        @language = language
      end
    end
  end

  subject(:xray_context) { dummy_class.new(project, language) }

  describe '#libraries' do
    context 'when xray_report exists' do
      let_it_be(:xray_report) { create(:xray_report, project: project, lang: 'ruby') }

      it 'returns an array of library names' do
        expect(xray_context.libraries).to match_array(['bcrypt (3.1.20)', 'logger (1.5.3)'])
      end

      context 'when there are more than MAX_LIBRARIES' do
        before do
          stub_const("#{described_class}::MAX_LIBRARIES", 1)
        end

        it 'limits the number of libraries to MAX_LIBRARIES' do
          expect(xray_context.libraries.count).to eq(described_class::MAX_LIBRARIES)
          expect(xray_context.libraries).to match_array(['bcrypt (3.1.20)'])
        end
      end
    end

    context 'when xray_report does not exist' do
      it 'returns an empty array' do
        expect(xray_context.libraries).to be_empty
      end
    end
  end
end
