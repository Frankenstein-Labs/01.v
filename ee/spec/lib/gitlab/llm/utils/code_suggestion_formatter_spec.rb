# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::CodeSuggestionFormatter, feature_category: :code_suggestions do
  let(:body) { nil }

  describe '#append_prompt' do
    subject(:append_prompt) { described_class.append_prompt(body) }

    context 'when the body is provided' do
      let(:body) { 'Hello!' }

      it 'appends code suggestion formatting instruction' do
        expect(append_prompt).to include <<~NOTE_CONTENT
        Hello!

        When you are responding with a code suggestion, format your code suggestion as follows:
        NOTE_CONTENT
      end
    end

    context 'when the body is nil' do
      let(:body) { nil }

      it 'returns an empty array' do
        expect(append_prompt).to be_blank
      end
    end
  end

  describe '#parse' do
    subject(:parse) { described_class.parse(body) }

    context 'with valid content' do
      context 'with text only comment' do
        let(:body) do
          <<~RESPONSE
          First line of comment
          Second line of comment

          Third line of comment
          RESPONSE
        end

        it 'returns the expected comment' do
          expect(parse[:from]).to be_nil
          expect(parse[:body]).to eq <<~NOTE_CONTENT
          First line of comment
          Second line of comment

          Third line of comment
          NOTE_CONTENT
        end
      end

      context 'with code suggestion' do
        let(:body) do
          <<~RESPONSE
          First comment with suggestions
          <from>
              first offending line
          </from>
          <to>
              first improved line
          </to>
          Some more comments
          RESPONSE
        end

        it 'returns the expected comment' do
          expect(parse[:from]).to eq "    first offending line\n"
          expect(parse[:body]).to eq <<~NOTE_CONTENT
          First comment with suggestions
          ```suggestion:-0+0
              first improved line
          ```
          Some more comments
          NOTE_CONTENT
        end

        context 'when <from> and <to> tags are inlined' do
          let(:body) do
            <<~RESPONSE
            First comment with suggestions
            <from>    first offending line</from>
            <to>    first improved line</to>
            Some more comments
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to eq "    first offending line"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
            First comment with suggestions
            ```suggestion:-0+0
                first improved line
            ```
            Some more comments
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
              First comment with suggestions
              <from>    first offending line</from>
              <to>    first offending line</to>
              Some more comments
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq "    first offending line"
              expect(parse[:body]).to eq <<~NOTE_CONTENT
              First comment with suggestions

              Some more comments
              NOTE_CONTENT
            end
          end
        end

        context 'when the response contains a multiline suggestion' do
          let(:body) do
            <<~RESPONSE
            First comment with a suggestion
            <from>
                first offending line
                second offending line
                third offending line
            </from>
            <to>
                first improved line
                second improved line
                  third improved line
                  fourth improved line
            </to>
            Some more comments
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to eq "    first offending line\n    second offending line\n    third offending line\n"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
            First comment with a suggestion
            ```suggestion:-0+2
                first improved line
                second improved line
                  third improved line
                  fourth improved line
            ```
            Some more comments
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
              First comment with a suggestion
              <from>
                  first offending line
                  second offending line
                  third offending line
              </from>
              <to>
                  first offending line
                  second offending line
                  third offending line
              </to>
              Some more comments
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq <<~FROM
              \
                  first offending line
                  second offending line
                  third offending line
              FROM
              expect(parse[:body]).to eq <<~NOTE_CONTENT
              First comment with a suggestion

              Some more comments
              NOTE_CONTENT
            end
          end
        end

        context 'when the response contains multiple suggestions in one comment' do
          let(:body) do
            <<~RESPONSE
            First comment with a suggestion
            <from>
                first offending line
            </from>
            <to>
                first improved line
            </to>

            Alternative suggestion
            <from>
                first offending line
                second offending line
            </from>
            <to>
                second improved line
                third improved line
            </to>

            Some more comments
            RESPONSE
          end

          it 'parses both suggestions correctly' do
            expect(parse[:from]).to eq "    first offending line\n"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
            First comment with a suggestion
            ```suggestion:-0+0
                first improved line
            ```

            Alternative suggestion
            ```suggestion:-0+1
                second improved line
                third improved line
            ```

            Some more comments
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
              First comment with a suggestion
              <from>
                  first offending line
              </from>
              <to>
                  first offending line
              </to>

              Alternative suggestion
              <from>
                  first offending line
                  second offending line
              </from>
              <to>
                  first offending line
                  second offending line
              </to>

              Some more comments
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq "    first offending line\n"
              expect(parse[:body]).to eq <<~NOTE_CONTENT
              First comment with a suggestion


              Alternative suggestion


              Some more comments
              NOTE_CONTENT
            end
          end
        end

        context 'when the content includes other elements' do
          let(:body) do
            <<~RESPONSE
              <from>
                  <div>first offending line</div>
                    <p>second offending line</p>
              </from>
              <to>
                  <div>first improved line</div>
                    <p>second improved line</p>
              </to>
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to eq "    <div>first offending line</div>\n      <p>second offending line</p>\n"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
              ```suggestion:-0+1
                  <div>first improved line</div>
                    <p>second improved line</p>
              ```
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
                Some comment
                <from>
                    <div>first offending line</div>
                      <p>second offending line</p>
                </from>
                <to>
                    <div>first offending line</div>
                      <p>second offending line</p>
                </to>
                Some more comment
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq "    <div>first offending line</div>\n      <p>second offending line</p>\n"
              expect(parse[:body]).to eq <<~NOTE_CONTENT
                Some comment

                Some more comment
              NOTE_CONTENT
            end
          end
        end

        context 'when the content includes <from> and <to>' do
          let(:body) do
            <<~RESPONSE
              <from>
                  <from>first offending line</from>
                  <to>second offending line</to>
              </from>
              <to>
                  <from>first improved line</from>
                  <to>second improved line</to>
              </to>
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to eq "    <from>first offending line</from>\n    <to>second offending line</to>\n"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
              ```suggestion:-0+1
                  <from>first improved line</from>
                  <to>second improved line</to>
              ```
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
                Some comment
                <from>
                    <from>first offending line</from>
                    <to>second offending line</to>
                </from>
                <to>
                    <from>first offending line</from>
                    <to>second offending line</to>
                </to>
                Some more comment
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq "    <from>first offending line</from>\n    <to>second offending line</to>\n"
              expect(parse[:body]).to eq <<~NOTE_CONTENT
                Some comment

                Some more comment
              NOTE_CONTENT
            end
          end
        end

        context 'when the content includes <from>' do
          let(:body) do
            <<~RESPONSE
              Some comment including a <from> tag
              <from>
                  <from>
                    Old
                  </from>
              </from>
              <to>
                  <from>
                    New
                  </from>
              </to>
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to eq "    <from>\n      Old\n    </from>\n"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
              Some comment including a <from> tag
              ```suggestion:-0+2
                  <from>
                    New
                  </from>
              ```
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
                Some comment including a <from> tag
                <from>
                    <from>
                      Old
                    </from>
                </from>
                <to>
                    <from>
                      Old
                    </from>
                </to>
                Some more comment
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq "    <from>\n      Old\n    </from>\n"
              expect(parse[:body]).to eq <<~NOTE_CONTENT
                Some comment including a <from> tag

                Some more comment
              NOTE_CONTENT
            end
          end
        end

        context 'when the suggestion contains any reserved XML characters' do
          let(:body) do
            <<~RESPONSE
            First comment with suggestions
            <from>
              a && b
            </from>
            <to>
              a && b < c
            </to>
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to eq "  a && b\n"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
            First comment with suggestions
            ```suggestion:-0+0
              a && b < c
            ```
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
              First comment with suggestions
              <from>
                a && b
              </from>
              <to>
                a && b
              </to>
              Some more comment
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq "  a && b\n"
              expect(parse[:body]).to eq <<~NOTE_CONTENT
                First comment with suggestions

                Some more comment
              NOTE_CONTENT
            end
          end
        end

        context 'when the code suggestion contains line breaks only' do
          let(:body) do
            <<~RESPONSE
            Please remove extra lines
            <from>



            </from>
            <to>

            </to>
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to eq "\n\n\n"
            expect(parse[:body]).to eq <<~NOTE_CONTENT
            Please remove extra lines
            ```suggestion:-0+2

            ```
            NOTE_CONTENT
          end

          context 'when from and to are the same' do
            let(:body) do
              <<~RESPONSE
              Please remove extra lines
              <from>



              </from>
              <to>



              </to>
              Some more comment
              RESPONSE
            end

            it 'returns the comment without the suggestions' do
              expect(parse[:from]).to eq "\n\n\n"
              expect(parse[:body]).to eq <<~NOTE_CONTENT
                Please remove extra lines

                Some more comment
              NOTE_CONTENT
            end
          end
        end

        context 'when the comment include only <to> tag' do
          let(:body) do
            <<~RESPONSE
              First comment with suggestions
              <to>
                  something random
              </to>
              Some more comments
            RESPONSE
          end

          it 'returns the expected comment' do
            expect(parse[:from]).to be_nil
            expect(parse[:body]).to eq <<~NOTE_CONTENT
              First comment with suggestions
              <to>
                  something random
              </to>
              Some more comments
            NOTE_CONTENT
          end
        end
      end
    end

    context 'when the body is nil' do
      let(:body) { nil }

      it 'returns an empty array' do
        expect(parse[:from]).to be_nil
        expect(parse[:body]).to be_blank
      end
    end

    context 'when the body is empty string' do
      let(:body) { '' }

      it 'returns an empty array' do
        expect(parse[:from]).to be_nil
        expect(parse[:body]).to be_blank
      end
    end
  end
end
