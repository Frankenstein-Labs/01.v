# frozen_string_literal: true

RSpec.shared_examples 'violations resolver' do
  using RSpec::Parameterized::TableSyntax

  context 'when user is unauthorized' do
    it 'returns nil' do
      expect(subject).to be_nil
    end
  end

  context 'when user is authorized' do
    before do
      obj.add_owner(current_user)
    end

    context 'when invoked without any filters or sorting' do
      it 'finds all the compliance violations' do
        expect(subject).to match_array(filter_results.call([compliance_violation, compliance_violation2]))
      end
    end

    context 'when filtering the results' do
      context 'when given merged at dates' do
        where(:merged_params, :result) do
          { merged_before: 2.days.ago.to_date } | lazy { compliance_violation }
          { merged_after: 2.days.ago.to_date } | lazy { compliance_violation2 }
          { merged_before: Date.current, merged_after: 2.days.ago.to_date } | lazy { compliance_violation2 }
        end

        with_them do
          let(:args) { { filters: merged_params } }

          it 'finds the filtered compliance violations' do
            expect(subject).to match_array(filter_results.call([result]))
          end
        end
      end
    end

    context 'when sorting the results' do
      where(:direction, :result) do
        'SEVERITY_LEVEL_ASC' | lazy { [compliance_violation, compliance_violation2] }
        'SEVERITY_LEVEL_DESC' | lazy { [compliance_violation2, compliance_violation] }
        'VIOLATION_REASON_ASC' | lazy { [compliance_violation, compliance_violation2] }
        'VIOLATION_REASON_DESC' | lazy { [compliance_violation2, compliance_violation] }
        'MERGE_REQUEST_TITLE_ASC' | lazy { [compliance_violation, compliance_violation2] }
        'MERGE_REQUEST_TITLE_DESC' | lazy { [compliance_violation2, compliance_violation] }
        'MERGED_AT_ASC' | lazy { [compliance_violation, compliance_violation2] }
        'MERGED_AT_DESC' | lazy { [compliance_violation2, compliance_violation] }
        'UNKNOWN_SORT' | lazy { [compliance_violation, compliance_violation2] }
      end

      with_them do
        let(:args) { { sort: direction } }

        it 'finds the filtered compliance violations' do
          expect(subject).to match_array(filter_results.call(result))
        end

        it "uses offset pagination" do
          expect(subject).to be_a(::Gitlab::Graphql::Pagination::OffsetActiveRecordRelationConnection)
        end
      end
    end
  end
end
