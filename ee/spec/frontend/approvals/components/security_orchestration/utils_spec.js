import { parsePolicies } from 'ee/approvals/components/security_orchestration/utils';

const fullPath = 'group/project';

const rawPolicy = {
  yaml: `
    name: test policy
    enabled: true
    rules: []
    actions: []
    approval_settings:
      prevent_approval_by_author: true
  `,
  actionApprovers: [],
  editPath: '/edit',
  source: null,
};

describe('parsePolicies', () => {
  it('parses raw policies with fromYaml and attaches metadata', () => {
    const result = parsePolicies([rawPolicy], fullPath);

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      name: 'test policy',
      enabled: true,
      actionApprovers: [],
      editPath: '/edit',
      source: { project: { fullPath } },
    });
  });

  it('falls back to fullPath source when rawPolicy.source is null', () => {
    const result = parsePolicies([rawPolicy], fullPath);

    expect(result[0].source).toEqual({ project: { fullPath } });
  });

  it('uses rawPolicy.source when present', () => {
    const policyWithSource = { ...rawPolicy, source: { project: { fullPath: 'other/path' } } };
    const result = parsePolicies([policyWithSource], fullPath);

    expect(result[0].source).toEqual({ project: { fullPath: 'other/path' } });
  });

  it('filters out policies that produce no name after parsing', () => {
    const noNamePolicy = { ...rawPolicy, yaml: 'enabled: true' };
    const result = parsePolicies([noNamePolicy], fullPath);

    expect(result).toHaveLength(0);
  });

  it('returns empty array when given empty input', () => {
    expect(parsePolicies([], fullPath)).toEqual([]);
  });
});
