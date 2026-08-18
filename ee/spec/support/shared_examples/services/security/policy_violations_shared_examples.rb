# frozen_string_literal: true

RSpec.shared_examples_for 'merge request with scan result violations' do
  let_it_be_with_reload(:scan_result_policy_read_2) do
    create(:scan_result_policy_read, project: project)
  end

  let_it_be(:unrelated_scan_result_violation) do
    create(:scan_result_policy_violation, merge_request: merge_request,
      scan_result_policy_read: scan_result_policy_read_2, project: project)
  end

  it 'creates violation records' do
    expect { execute }.to change { merge_request.scan_result_policy_violations.count }.by(1)
  end

  it 'does not delete unrelated violation records from other policies' do
    execute

    expect(merge_request.scan_result_policy_violations).to include unrelated_scan_result_violation
  end
end

RSpec.shared_examples_for 'merge request without scan result violations' do |previous_violation: true|
  it 'creates no violation records' do
    expect { execute }.not_to change { merge_request.scan_result_policy_violations.count }
  end

  if previous_violation
    context 'with previous violation record' do
      let!(:previous_violation) do
        create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: scan_result_policy_read.approval_policy_rule,
          merge_request: merge_request)
      end

      it 'removes the violation record' do
        expect { execute }.to change { merge_request.scan_result_policy_violations.count }.by(-1)
      end
    end
  end
end
