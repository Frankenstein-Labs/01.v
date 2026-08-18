import {
  getFormattedIssue,
  getAddRelatedIssueRequestParams,
  normalizeGraphQLVulnerability,
  normalizeGraphQLLastStateTransition,
  formatIdentifierExternalIds,
  isSupportedIdentifier,
  getRefFromBlobPath,
  getTabIndexForCodeFlowPage,
  setTabIndexForCodeFlowPage,
} from 'ee/vulnerabilities/helpers';

describe('Vulnerabilities helpers', () => {
  describe('getFormattedIssue', () => {
    it.each([
      { iid: 135, web_url: 'some/url' },
      { iid: undefined, web_url: undefined },
    ])('returns formatted issue with expected properties for issue %s', (issue) => {
      const formattedIssue = getFormattedIssue(issue);

      expect(formattedIssue).toMatchObject({
        ...issue,
        reference: `#${issue.iid}`,
        path: issue.web_url,
      });
    });
  });

  describe('getAddRelatedIssueRequestParams', () => {
    const defaultPath = 'default/path';

    it.each`
      reference                                          | target_issue_iid                              | target_project_id
      ${'135'}                                           | ${'135'}                                      | ${defaultPath}
      ${'#246'}                                          | ${'246'}                                      | ${defaultPath}
      ${'https://localhost:3000/root/test/-/issues/357'} | ${'357'}                                      | ${'root/test'}
      ${'/root/test/-/issues/357'}                       | ${'/root/test/-/issues/357'}                  | ${defaultPath}
      ${'invalidReference'}                              | ${'invalidReference'}                         | ${defaultPath}
      ${'/?something/@#$%/@#$%/-/issues/1234'}           | ${'/?something/@#$%/@#$%/-/issues/1234'}      | ${defaultPath}
      ${'http://something/@#$%/@#$%/-/issues/1234'}      | ${'http://something/@#$%/@#$%/-/issues/1234'} | ${defaultPath}
    `(
      'gets correct request params for the reference "$reference"',
      ({ reference, target_issue_iid, target_project_id }) => {
        const params = getAddRelatedIssueRequestParams(reference, defaultPath);

        expect(params).toMatchObject({ target_issue_iid, target_project_id });
      },
    );
  });

  describe('normalizeGraphQLVulnerability', () => {
    it('returns null when vulnerability is null', () => {
      expect(normalizeGraphQLVulnerability(null)).toBe(null);
    });

    it('normalizes the GraphQL response when the vulnerability is not null', () => {
      expect(
        normalizeGraphQLVulnerability({
          confirmedBy: { id: 'gid://gitlab/User/16' },
          resolvedBy: { id: 'gid://gitlab/User/16' },
          dismissedBy: { id: 'gid://gitlab/User/16' },
          state: 'DISMISSED',
          id: 'gid://gitlab/Vulnerability/54',
        }),
      ).toEqual({
        confirmedById: 16,
        resolvedById: 16,
        dismissedById: 16,
        state: 'dismissed',
        id: 54,
      });
    });
  });

  describe('normalizeGraphQLLastStateTransition', () => {
    const vulnerability = {
      stateTransitions: [
        {
          author: { id: 'gid://gitlab/User/16' },
          comment: 'test',
          createdAt: '2023-03-07T09:20:31.852Z',
          fromState: 'detected',
          toState: 'confirmed',
          dismissalReason: null,
        },
      ],
    };

    const graphQLVulnerability = {
      stateTransitions: {
        nodes: [
          {
            dismissalReason: 'USED_IN_TESTS',
          },
        ],
      },
    };

    const normalizedLastStateTransition = {
      dismissalReason: 'used_in_tests',
    };

    it(`returns object with only normalized graphQLVulnerability last stateTransition when initial vulnerability doesn't have stateTransitions`, () => {
      expect(
        normalizeGraphQLLastStateTransition(graphQLVulnerability, { stateTransitions: [] }),
      ).toEqual({
        stateTransitions: [normalizedLastStateTransition],
      });
    });

    it('concatenates initial vulnerability stateTransitions with normalized graphQLVulnerability last stateTransition', () => {
      expect(normalizeGraphQLLastStateTransition(graphQLVulnerability, vulnerability)).toEqual({
        stateTransitions: [...vulnerability.stateTransitions, normalizedLastStateTransition],
      });
    });
  });

  describe('formatIdentifierExternalIds', () => {
    const identifiers = {
      externalType: 'external type',
      externalId: 'external id',
      name: 'name',
    };

    it('returns the correct format', () => {
      const { externalType, externalId, name } = identifiers;

      expect(formatIdentifierExternalIds(identifiers)).toEqual(
        `[${externalType}]-[${externalId}]-[${name}]`,
      );
    });
  });

  describe('isSupportedIdentifier', () => {
    it.each`
      type       | expected
      ${'cwe'}   | ${true}
      ${'CWE'}   | ${true}
      ${'owasp'} | ${true}
      ${'OWASP'} | ${false}
      ${'cve'}   | ${false}
      ${'CVE'}   | ${false}
    `('renders $expected for $type', ({ type, expected }) => {
      expect(isSupportedIdentifier(type)).toBe(expected);
    });
  });

  describe('getRefFromBlobPath', () => {
    it('should extract the Git SHA from a valid blob path', () => {
      const path = '/group/project/-/blob/cdeda7ae724a332e008d17245209d5edd9ba6499/src/file.js';
      expect(getRefFromBlobPath(path)).toBe('cdeda7ae724a332e008d17245209d5edd9ba6499');
    });

    it('should return an empty string for a path without a valid Git SHA', () => {
      const path = '/group/project/-/blob/master/src/file.js';
      expect(getRefFromBlobPath(path)).toBe('');
    });

    it('should return an empty string for a path without "blob/"', () => {
      const path = '/group/project/-/tree/cdeda7ae724a332e008d17245209d5edd9ba6499/src/file.js';
      expect(getRefFromBlobPath(path)).toBe('');
    });

    it('should return an empty string for an empty path', () => {
      expect(getRefFromBlobPath('')).toBe('');
    });

    it('should return an empty string for a non-string input', () => {
      expect(getRefFromBlobPath(null)).toBe('');
      expect(getRefFromBlobPath(undefined)).toBe('');
      expect(getRefFromBlobPath(123)).toBe('');
      expect(getRefFromBlobPath({})).toBe('');
    });

    it("should extract the Git SHA even if it's not at the end of the path", () => {
      const path =
        '/group/project/-/blob/cdeda7ae724a332e008d17245209d5edd9ba6499/src/file.js?ref_type=heads';
      expect(getRefFromBlobPath(path)).toBe('cdeda7ae724a332e008d17245209d5edd9ba6499');
    });
  });

  describe('getTabIndexForCodeFlowPage', () => {
    it('should return 1 when tab query parameter is present', () => {
      const route = { query: { tab: 'code_flow' } };
      expect(getTabIndexForCodeFlowPage(route)).toBe(1);
    });

    it('should return 0 when tab query parameter is not present', () => {
      const route = { query: {} };
      expect(getTabIndexForCodeFlowPage(route)).toBe(0);
    });

    it('should return 0 when route is undefined', () => {
      expect(getTabIndexForCodeFlowPage(undefined)).toBe(0);
    });

    it('should return 0 when query is undefined', () => {
      const route = {};
      expect(getTabIndexForCodeFlowPage(route)).toBe(0);
    });
  });

  describe('setTabIndexForCodeFlowPage', () => {
    let mockRouter;

    beforeEach(() => {
      mockRouter = {
        push: jest.fn(),
      };
    });

    it('should call router.push with correct parameters when index is different', () => {
      setTabIndexForCodeFlowPage(mockRouter, { path: '/vulnerability/123', index: 1 });
      expect(mockRouter.push).toHaveBeenCalledWith({
        path: '/vulnerability/123',
        query: { tab: 'code_flow' },
      });
    });

    it('should not call router.push when index is the same as selectedIndex', () => {
      setTabIndexForCodeFlowPage(mockRouter, {
        path: '/vulnerability/123',
        index: 1,
        selectedIndex: 1,
      });
      expect(mockRouter.push).not.toHaveBeenCalled();
    });
  });
});
