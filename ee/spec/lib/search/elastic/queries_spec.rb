# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Queries, feature_category: :global_search do
  describe '#by_iid' do
    subject(:by_iid) { described_class.by_iid(iid: 1, doc_type: 'my_type') }

    it 'returns the expected query hash' do
      expected_filter = [
        { term: { iid: { _name: 'my_type:related:iid', value: 1 } } },
        { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
      ]

      expect(by_iid[:query][:bool][:must]).to eq([])
      expect(by_iid[:query][:bool][:must_not]).to eq([])
      expect(by_iid[:query][:bool][:should]).to eq([])
      expect(by_iid[:query][:bool][:filter]).to eq(expected_filter)
    end
  end

  describe '#by_full_text' do
    let(:query) { 'foo bar' }
    let(:fields) { %w[iid^3 title^2 description] }
    let(:base_options) { { doc_type: 'my_type', fields: fields } }
    let(:options) { base_options }

    subject(:by_full_text) do
      described_class.by_full_text(query: query, options: options)
    end

    context 'when advanced query syntax is matched' do
      where(:query, :description) do
        [
          # Characters that always match (no spacing required)
          ['"gem sidekiq"', 'exact phrase search with quotes'],
          ['bug error 50*', 'wildcard asterisk'],
          ['test|case', 'pipe character'],
          ['(foo bar)', 'parentheses grouping'],
          ['foo~bar', 'tilde character'],
          ['\*md', 'escape character'],

          # + and - operators
          ['display +banner', 'required operator with spaces'],
          ['display -banner', 'exclusion operator with spaces'],
          ['foo +bar -baz', 'multiple operators with spaces'],
          [' + ', 'plus with spaces'],
          [' - ', 'minus with spaces'],
          ['+required', 'plus at start without space'],
          ['-excluded', 'minus at start without space'],

          # Mixed cases
          ['rails -filename:gemfile.lock', 'text with exclusion operator'],
          ['"exact phrase" +required', 'quotes with required operator'],
          ['search* +term', 'wildcard and required operator'],
          ['RSpec.describe Resolvers -*builder', 'wildcard and exclusion operator'],
          ['(group) -exclude', 'parentheses and exclusion operator'],

          # GitLab syntax
          ['#23456', 'issue reference'],
          ['!23456', 'merge request reference']
        ]
      end

      with_them do
        it "calls by_simple_query_string for #{description}" do
          expect(described_class).to receive(:by_simple_query_string)
            .with(query: query, options: options)

          by_full_text
        end
      end

      describe 'simple_query_string behavior' do
        let(:query) { 'bug error 50*' }

        context 'when custom elasticsearch analyzers are enabled' do
          before do
            stub_ee_application_setting(elasticsearch_analyzers_smartcn_enabled: true,
              elasticsearch_analyzers_smartcn_search: true)
          end

          it 'applies custom analyzer fields' do
            expected_must = [
              { simple_query_string: { _name: 'my_type:match:search_terms',
                                       fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                                       query: query, lenient: true, default_operator: :and } }
            ]

            expect(by_full_text[:query][:bool][:must]).to eql(expected_must)
          end

          context 'when fields is a frozen array' do
            let(:fields) { %w[iid^3 title^2 description].freeze }

            it 'applies custom analyzer fields' do
              expected_must = [
                { simple_query_string: { _name: 'my_type:match:search_terms',
                                         fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                                         query: query, lenient: true, default_operator: :and } }
              ]

              expect(by_full_text[:query][:bool][:must]).to eql(expected_must)
            end
          end
        end

        it 'applies highlight in query' do
          expected = { fields: { iid: {}, title: {}, description: {} },
                       number_of_fragments: 0, pre_tags: ['gitlabelasticsearch→'], post_tags: ['←gitlabelasticsearch'] }

          expect(by_full_text[:highlight]).to eq(expected)
        end

        context 'when options[:clause] is should' do
          let(:options) { base_options.merge(keyword_match_clause: :should) }

          it 'returns a simple_query_string query as a should and adds doc type as a filter' do
            expected_should = [
              { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                       query: query, lenient: true, default_operator: :and } }
            ]
            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
            ]

            expect(by_full_text[:query][:bool][:must]).to eq([])
            expect(by_full_text[:query][:bool][:must_not]).to eq([])
            expect(by_full_text[:query][:bool][:should]).to eq(expected_should)
            expect(by_full_text[:query][:bool][:filter]).to eq(expected_filter)
          end
        end

        context 'when options[:related_ids] are provided' do
          let(:options) { base_options.merge(related_ids: [12, 14]) }

          it 'returns a simple_query_string query and an id query in should array and adds doc type as a filter' do
            expected_should = [
              { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                       query: query, lenient: true, default_operator: :and } },
              { terms: { _name: 'my_type:related:ids', id: [12, 14],
                         boost: Search::Elastic::Queries::DEFAULT_RELATED_ID_BOOST } }
            ]
            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
            ]

            expect(by_full_text[:query][:bool][:must]).to eq([])
            expect(by_full_text[:query][:bool][:must_not]).to eq([])
            expect(by_full_text[:query][:bool][:should]).to eq(expected_should)
            expect(by_full_text[:query][:bool][:filter]).to eq(expected_filter)
          end

          context 'when options[:related_ids_boost] is also provided' do
            let(:options) { base_options.merge(related_ids: [12, 14], related_ids_boost: 12) }

            it 'uses the boost in the id query' do
              expected_should = [
                { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                         query: query, lenient: true, default_operator: :and } },
                { terms: { _name: 'my_type:related:ids', id: [12, 14], boost: 12 } }
              ]
              expected_filter = [
                { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
              ]

              expect(by_full_text[:query][:bool][:must]).to eq([])
              expect(by_full_text[:query][:bool][:must_not]).to eq([])
              expect(by_full_text[:query][:bool][:should]).to eq(expected_should)
              expect(by_full_text[:query][:bool][:filter]).to eq(expected_filter)
            end
          end
        end

        context 'when query is provided' do
          it 'returns a simple_query_string query as a must and adds doc type as a filter' do
            expected_must = [
              { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                       query: query, lenient: true, default_operator: :and } }
            ]
            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
            ]

            expect(by_full_text[:query][:bool][:must]).to eq(expected_must)
            expect(by_full_text[:query][:bool][:must_not]).to eq([])
            expect(by_full_text[:query][:bool][:should]).to eq([])
            expect(by_full_text[:query][:bool][:filter]).to eq(expected_filter)
          end
        end

        context 'when query is not provided' do
          let(:query) { nil }

          it 'returns a match_all query' do
            expected_must = { match_all: {} }

            expect(by_full_text[:query][:bool][:must]).to eq(expected_must)
            expect(by_full_text[:query][:bool][:must_not]).to eq([])
            expect(by_full_text[:query][:bool][:should]).to eq([])
            expect(by_full_text[:query][:bool][:filter]).to eq([])
            expect(by_full_text[:track_scores]).to be(true)
          end
        end

        context 'when options[:count_only] is true' do
          let(:options) { base_options.merge(count_only: true) }

          it 'does not apply highlight in query' do
            expect(by_full_text[:highlight]).to be_nil
          end

          it 'removes field boosts and returns a simple_query_string as a filter' do
            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } },
              { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid title description],
                                       query: query, lenient: true, default_operator: :and } }
            ]

            expect(by_full_text[:query][:bool][:must]).to eq([])
            expect(by_full_text[:query][:bool][:must_not]).to eq([])
            expect(by_full_text[:query][:bool][:should]).to eq([])
            expect(by_full_text[:query][:bool][:filter]).to eq(expected_filter)
          end
        end
      end
    end

    context 'when advanced query syntax is NOT matched' do
      where(:query, :description) do
        [
          # project paths (hyphens without spaces)
          ['gitlab-org/gitlab', 'project path with hyphen'],
          ['my-awesome-project', 'project name with hyphens'],
          ['user-123/repo-name', 'user and repo with hyphens'],

          # + and - operators without proper spacing
          ['display+banner', 'plus without spaces'],
          ['display-banner', 'minus without spaces'],

          ['display \+banner', 'backslash escaped plus with spaces'],
          ['display\-banner', 'backslash escaped plus without spaces'],

          # text terms
          ['simple search', 'simple words'],
          ['ruby programming', 'multiple words'],
          ['gitlab', 'single word'],

          # other characters that don't match
          ['version 1.2.3', 'version number'],
          ['user@example.com', 'email address'],
          ['key=value', 'equals sign'],
          ['hello, world', 'comma separated'],
          ['question?', 'question mark'],
          ['ruby-on-rails framework', 'hyphenated terms']
        ]
      end

      with_them do
        it "calls by_multi_match_query for #{description}" do
          expect(described_class).to receive(:by_multi_match_query)
            .with(query: query, options: options)

          by_full_text
        end
      end

      describe 'multi_match_query behavior' do
        let(:query) { 'simple search' }

        subject(:by_multi_match_query) do
          described_class.by_full_text(query: query, options: options)
        end

        context 'when custom elasticsearch analyzers are enabled' do
          before do
            stub_ee_application_setting(elasticsearch_analyzers_smartcn_enabled: true,
              elasticsearch_analyzers_smartcn_search: true)
          end

          it 'applies custom analyzer fields to multi_match_query' do
            expected_must = [{ bool: {
              should: [
                { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                 fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                                 query: query, operator: :and, lenient: true } },
                { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                 type: :phrase, fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                                 query: query, lenient: true } }
              ],
              minimum_should_match: 1
            } }]

            expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
          end

          context 'when fields is a frozen array' do
            let(:fields) { %w[iid^3 title^2 description].freeze }

            it 'applies custom analyzer fields to multi_match_query' do
              expected_must = [{ bool: {
                should: [
                  { multi_match:
                    { _name: 'my_type:multi_match:and:search_terms',
                      fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                      query: query, operator: :and, lenient: true } },
                  { multi_match:
                    { _name: 'my_type:multi_match_phrase:search_terms',
                      type: :phrase, fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                      query: query, lenient: true } }
                ],
                minimum_should_match: 1
              } }]

              expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
            end
          end
        end

        it 'applies highlight in query' do
          expected = { fields: { iid: {}, title: {}, description: {} },
                       number_of_fragments: 0, pre_tags: ['gitlabelasticsearch→'], post_tags: ['←gitlabelasticsearch'] }

          expect(by_multi_match_query[:highlight]).to eq(expected)
        end

        context 'when query is provided' do
          it 'returns a by_multi_match_query query as a should and adds doc type as a filter' do
            expected_must = [{ bool: {
              should: [
                { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                 fields: %w[iid^3 title^2 description],
                                 query: query, operator: :and, lenient: true } },
                { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                 type: :phrase, fields: %w[iid^3 title^2 description],
                                 query: query, lenient: true } }
              ],
              minimum_should_match: 1
            } }]

            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
            ]

            expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
            expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
            expect(by_multi_match_query[:query][:bool][:should]).to eq([])
            expect(by_multi_match_query[:query][:bool][:filter]).to eq(expected_filter)
          end
        end

        context 'when query is not provided' do
          let(:query) { nil }

          it 'returns a match_all query' do
            expected_must = { match_all: {} }

            expect(by_multi_match_query[:query][:bool][:must]).to eq(expected_must)
            expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
            expect(by_multi_match_query[:query][:bool][:should]).to eq([])
            expect(by_multi_match_query[:query][:bool][:filter]).to eq([])
            expect(by_multi_match_query[:track_scores]).to be(true)
          end
        end

        context 'when options[:clause] is should' do
          let(:options) { base_options.merge(keyword_match_clause: :should) }

          it 'removes field boosts and returns a by_multi_match_query as a filter' do
            expected_should = [
              { bool: {
                should: [
                  { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                   fields: %w[iid^3 title^2 description],
                                   query: query, operator: :and, lenient: true } },
                  { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                   type: :phrase, fields: %w[iid^3 title^2 description],
                                   query: query, lenient: true } }
                ],
                minimum_should_match: 1
              } }
            ]

            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
            ]
            expect(by_multi_match_query[:query][:bool][:must]).to eq([])
            expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
            expect(by_multi_match_query[:query][:bool][:should]).to eql(expected_should)
            expect(by_multi_match_query[:query][:bool][:filter]).to eql(expected_filter)
          end
        end

        context 'when options[:related_ids] is provided' do
          let(:options) { base_options.merge(related_ids: [12, 14]) }

          it 'returns a by_multi_match_query query and an id query in should array and adds doc type as a filter' do
            expected_should = [
              { bool: { minimum_should_match: 1,
                        should: [
                          { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                           fields: %w[iid^3 title^2 description],
                                           query: query, operator: :and, lenient: true } },
                          { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                           type: :phrase, fields: %w[iid^3 title^2 description],
                                           query: query, lenient: true } }
                        ] } },
              { terms: { _name: 'my_type:related:ids', id: [12, 14],
                         boost: Search::Elastic::Queries::DEFAULT_RELATED_ID_BOOST } }
            ]
            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
            ]

            expect(by_multi_match_query[:query][:bool][:must]).to be_empty
            expect(by_multi_match_query[:query][:bool][:must_not]).to be_empty
            expect(by_multi_match_query[:query][:bool][:should]).to eq(expected_should)
            expect(by_multi_match_query[:query][:bool][:filter]).to eq(expected_filter)
          end

          context 'when options[:related_ids_boost] is also provided' do
            let(:options) { base_options.merge(related_ids: [12, 14], related_ids_boost: 12) }

            it 'uses the boost in the id query' do
              expected_should = [
                { bool: { minimum_should_match: 1,
                          should: [
                            { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                             fields: %w[iid^3 title^2 description],
                                             query: query, operator: :and, lenient: true } },
                            { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                             type: :phrase, fields: %w[iid^3 title^2 description],
                                             query: query, lenient: true } }
                          ] } },
                { terms: { _name: 'my_type:related:ids', id: [12, 14], boost: 12 } }
              ]
              expected_filter = [
                { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
              ]

              expect(by_multi_match_query[:query][:bool][:must]).to be_empty
              expect(by_multi_match_query[:query][:bool][:must_not]).to be_empty
              expect(by_multi_match_query[:query][:bool][:should]).to eq(expected_should)
              expect(by_multi_match_query[:query][:bool][:filter]).to eq(expected_filter)
            end
          end
        end

        context 'when options[:count_only] is true' do
          let(:options) { base_options.merge(count_only: true) }

          it 'does not apply highlight in query' do
            expect(by_multi_match_query[:highlight]).to be_nil
          end

          it 'removes field boosts and returns a by_multi_match_query as a filter' do
            expected_filter = [
              { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } },
              { bool: {
                should: [
                  { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                                   fields: %w[iid title description],
                                   query: query, operator: :and, lenient: true } },
                  { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                                   type: :phrase, fields: %w[iid title description],
                                   query: query, lenient: true } }
                ],
                minimum_should_match: 1
              } }
            ]

            expect(by_multi_match_query[:query][:bool][:must]).to eq([])
            expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
            expect(by_multi_match_query[:query][:bool][:should]).to eq([])
            expect(by_multi_match_query[:query][:bool][:filter]).to eql(expected_filter)
          end
        end
      end
    end
  end

  describe '#by_fuzzy_text' do
    let(:query) { 'bob' }
    let(:fields) { %w[name username public_email] }
    let(:options) { { doc_type: 'user', no_join_project: true, fields: fields } }

    subject(:by_fuzzy_text) { described_class.by_fuzzy_text(query: query, options: options) }

    it 'returns fuzzy match queries as a must with named clauses per field' do
      expected_must = [
        {
          bool: {
            should: fields.map do |field|
              { match: { "#{field}": { query: query, fuzziness: 'AUTO', _name: "user:fuzzy:#{field}" } } }
            end,
            minimum_should_match: 1
          }
        }
      ]

      expect(by_fuzzy_text[:query][:bool][:must]).to eq(expected_must)
      expect(by_fuzzy_text[:query][:bool][:filter]).to eq([])
      expect(by_fuzzy_text[:query][:bool][:should]).to eq([])
    end

    context 'when fuzzy_operator is set' do
      let(:options) { { doc_type: 'user', no_join_project: true, fields: fields, fuzzy_operator: 'AND' } }

      it 'includes operator in each match clause' do
        expected_must = [
          {
            bool: {
              should: fields.map do |field|
                { match: { "#{field}": { query: query, fuzziness: 'AUTO', operator: 'AND',
                                         _name: "user:fuzzy:#{field}" } } }
              end,
              minimum_should_match: 1
            }
          }
        ]

        expect(by_fuzzy_text[:query][:bool][:must]).to eq(expected_must)
      end
    end

    context 'when count_only is true' do
      let(:options) { { doc_type: 'user', no_join_project: true, fields: fields, count_only: true } }

      it 'places the fuzzy query in filter instead of must' do
        expect(by_fuzzy_text[:query][:bool][:filter]).not_to be_empty
        expect(by_fuzzy_text[:query][:bool][:must]).to eq([])
      end
    end

    context 'when keyword_match_clause is should' do
      let(:options) { { doc_type: 'user', no_join_project: true, fields: fields, keyword_match_clause: :should } }

      it 'places the fuzzy query in should' do
        expect(by_fuzzy_text[:query][:bool][:should]).not_to be_empty
        expect(by_fuzzy_text[:query][:bool][:must]).to eq([])
      end
    end

    context 'when options[:fields] is missing' do
      let(:options) { { doc_type: 'user', no_join_project: true } }

      it 'raises ArgumentError' do
        expect { by_fuzzy_text }.to raise_error(ArgumentError, 'by_fuzzy_text requires options[:fields]')
      end
    end

    context 'when options[:fields] is empty' do
      let(:options) { { doc_type: 'user', no_join_project: true, fields: [] } }

      it 'raises ArgumentError' do
        expect { by_fuzzy_text }.to raise_error(ArgumentError, 'by_fuzzy_text requires options[:fields]')
      end
    end
  end
end
