import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import {
  isTrackedRefFilterEnabled,
  buildDefaultTrackedRefFilter,
} from 'ee/dependencies/components/filtered_search/utils';

describe('project dependencies filtered search utils', () => {
  const defaultBranchContext = {
    id: 'gid://gitlab/Security::ProjectTrackedContext/23',
    name: 'main',
  };

  const enabledArgs = {
    glFeatures: {
      vulnerabilitiesAcrossContexts: true,
      projectDependencyTrackedRef: true,
    },
    projectFullPath: 'gitlab-org/my-project',
    defaultBranchContext,
  };

  describe('isTrackedRefFilterEnabled', () => {
    it('returns true when all conditions are met', () => {
      expect(isTrackedRefFilterEnabled(enabledArgs)).toBe(true);
    });

    it('returns false when called without arguments', () => {
      expect(isTrackedRefFilterEnabled()).toBe(false);
    });

    it.each`
      scenario                                  | overrides
      ${'vulnerabilitiesAcrossContexts is off'} | ${{ glFeatures: { vulnerabilitiesAcrossContexts: false, projectDependencyTrackedRef: true } }}
      ${'projectDependencyTrackedRef is off'}   | ${{ glFeatures: { vulnerabilitiesAcrossContexts: true, projectDependencyTrackedRef: false } }}
      ${'projectFullPath is missing'}           | ${{ projectFullPath: '' }}
      ${'defaultBranchContext is null'}         | ${{ defaultBranchContext: null }}
    `('returns false when $scenario', ({ overrides }) => {
      expect(isTrackedRefFilterEnabled({ ...enabledArgs, ...overrides })).toBe(false);
    });
  });

  describe('buildDefaultTrackedRefFilter', () => {
    it('builds the default tracked ref filter from the default branch context', () => {
      expect(buildDefaultTrackedRefFilter(defaultBranchContext)).toEqual([
        {
          type: 'trackedRefIds',
          value: {
            data: [{ id: defaultBranchContext.id, name: defaultBranchContext.name }],
            operator: OPERATORS_OR[0].value,
          },
        },
      ]);
    });

    it.each`
      scenario       | context
      ${'null'}      | ${null}
      ${'undefined'} | ${undefined}
    `('returns an empty array when defaultBranchContext is $scenario', ({ context }) => {
      expect(buildDefaultTrackedRefFilter(context)).toEqual([]);
    });
  });
});
