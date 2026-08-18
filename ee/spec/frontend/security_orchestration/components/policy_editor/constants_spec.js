import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  ALL_BRANCHES,
  ALL_PROTECTED_BRANCHES,
  GROUP_DEFAULT_BRANCHES,
  GROUP_TARGET_DEFAULT_BRANCHES,
  PROJECT_DEFAULT_BRANCH,
  PROJECT_TARGET_DEFAULT_BRANCH,
  SPECIFIC_BRANCHES,
  TARGET_PROTECTED_BRANCHES,
  SCAN_EXECUTION_BRANCH_TYPE_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';

describe('SCAN_EXECUTION_BRANCH_TYPE_OPTIONS', () => {
  it('returns extended options for group namespace', () => {
    expect(
      SCAN_EXECUTION_BRANCH_TYPE_OPTIONS({
        namespaceType: NAMESPACE_TYPES.GROUP,
        includeTargetTypes: true,
      }),
    ).toEqual([
      ALL_BRANCHES,
      GROUP_DEFAULT_BRANCHES,
      ALL_PROTECTED_BRANCHES,
      SPECIFIC_BRANCHES,
      TARGET_PROTECTED_BRANCHES,
      GROUP_TARGET_DEFAULT_BRANCHES,
    ]);
  });

  it('returns extended options for project namespace', () => {
    expect(
      SCAN_EXECUTION_BRANCH_TYPE_OPTIONS({
        namespaceType: NAMESPACE_TYPES.PROJECT,
        includeTargetTypes: true,
      }),
    ).toEqual([
      ALL_BRANCHES,
      PROJECT_DEFAULT_BRANCH,
      ALL_PROTECTED_BRANCHES,
      SPECIFIC_BRANCHES,
      TARGET_PROTECTED_BRANCHES,
      PROJECT_TARGET_DEFAULT_BRANCH,
    ]);
  });

  it('uses group namespace by default when namespace type is not provided', () => {
    expect(SCAN_EXECUTION_BRANCH_TYPE_OPTIONS({ includeTargetTypes: true })).toEqual([
      ALL_BRANCHES,
      GROUP_DEFAULT_BRANCHES,
      ALL_PROTECTED_BRANCHES,
      SPECIFIC_BRANCHES,
      TARGET_PROTECTED_BRANCHES,
      GROUP_TARGET_DEFAULT_BRANCHES,
    ]);
  });

  it('does not return target types if not specified', () => {
    expect(SCAN_EXECUTION_BRANCH_TYPE_OPTIONS({ namespaceType: NAMESPACE_TYPES.GROUP })).toEqual([
      ALL_BRANCHES,
      GROUP_DEFAULT_BRANCHES,
      ALL_PROTECTED_BRANCHES,
      SPECIFIC_BRANCHES,
    ]);
  });

  it('uses empty feature flags object by default when not provided', () => {
    expect(SCAN_EXECUTION_BRANCH_TYPE_OPTIONS({ namespaceType: NAMESPACE_TYPES.GROUP })).toEqual([
      ALL_BRANCHES,
      GROUP_DEFAULT_BRANCHES,
      ALL_PROTECTED_BRANCHES,
      SPECIFIC_BRANCHES,
    ]);
  });
});
