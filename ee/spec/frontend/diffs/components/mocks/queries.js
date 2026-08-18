import { FINDINGS_STATUS_PARSED } from '~/diffs/components/app.vue';

const mockError = new Error('mockedRequestError');
export const requestError = jest.fn().mockRejectedValue(mockError);

export const SAST_REPORT_DATA = {
  added: [
    {
      identifiers: [
        {
          name: 'Improper Limitation of a Pathname to a Restricted Directory',
          externalId: 'cwe-126',
          externalType: 'cwe',
          url: 'https://owasp.org/www-community/attacks/Path_Traversal',
        },
      ],
      uuid: '1',
      title: "Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')",
      unverified: false,
      description:
        "Found request data in a call to 'open'. An attacker can manipulate this input to access files outside the intended\n" +
        'directory. ',
      state: 'needs triage',
      severity: '1',
      foundByPipelineIid: '1',
      location: {},
      details: [],
    },
  ],
};

export const codeQualityErrorAndParsed = jest
  .fn()
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            status: 'PARSING',
            report: {
              status: 'FAILED',
              newErrors: [],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 0,
                resolved: 0,
                total: 0,
              },
            },
          },
          sastReport: {
            status: 'ERROR',
            report: null,
          },
        },
      },
    },
  })
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            status: 'PARSED',
            report: {
              status: 'FAILED',
              newErrors: [
                {
                  description:
                    'Method `more_noise_hi` has 9 arguments (exceeds 4 allowed). Consider refactoring.',
                  fingerprint: '98506525c60c9fe7cf2dd48f8f15bc32',
                  severity: 'MAJOR',
                  filePath: 'noise.rb',
                  line: 16,
                  webUrl:
                    'http://gdk.test:3000/root/code-quality-test/-/blob/091ce33570e71766c6e46bb2b8985f3072a0d047/noise.rb#L16',
                  engineName: 'structure',
                },
              ],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 12,
                resolved: 0,
                total: 12,
              },
            },
          },
          sastReport: {
            status: 'ERROR',
            report: null,
          },
        },
      },
    },
  });

export const SASTErrorHandler = jest.fn().mockResolvedValueOnce({
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/123',
        title: 'Update file noise.rb',
        project: {
          id: 'testid',
          nameWithNamespace: 'test/name',
          fullPath: 'testPath',
        },
        hasSecurityReports: false,
        codequalityReportsComparer: {
          status: 'PARSING',
          report: {
            status: 'FAILED',
            newErrors: [],
            resolvedErrors: [],
            existingErrors: [],
            summary: {
              errored: 0,
              resolved: 0,
              total: 0,
            },
          },
        },
        sastReport: {
          status: 'ERROR',
          report: null,
        },
      },
    },
  },
});

export const SASTParsingAndParsedHandler = jest
  .fn()
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            status: 'PARSING',
            report: {
              status: 'FAILED',
              newErrors: [],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 0,
                resolved: 0,
                total: 0,
              },
            },
          },
          sastReport: {
            status: 'PARSING',
            report: null,
          },
        },
      },
    },
  })
  .mockResolvedValueOnce({
    data: {
      project: {
        id: 'gid://gitlab/Project/20',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/123',
          title: 'Update file noise.rb',
          project: {
            id: 'testid',
            nameWithNamespace: 'test/name',
            fullPath: 'testPath',
          },
          hasSecurityReports: false,
          codequalityReportsComparer: {
            status: 'PARSING',
            report: {
              status: 'FAILED',
              newErrors: [],
              resolvedErrors: [],
              existingErrors: [],
              summary: {
                errored: 12,
                resolved: 0,
                total: 12,
              },
            },
          },
          sastReport: {
            status: FINDINGS_STATUS_PARSED,
            report: null,
          },
        },
      },
    },
  });

export const codeQualityNewErrorsHandler = jest.fn().mockResolvedValue({
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/123',
        title: 'Update file noise.rb',
        project: {
          id: 'testid',
          nameWithNamespace: 'test/name',
          fullPath: 'testPath',
        },
        hasSecurityReports: false,
        codequalityReportsComparer: {
          status: 'PARSED',
          report: {
            status: 'FAILED',
            newErrors: [
              {
                description:
                  'Method `more_noise_hi` has 9 arguments (exceeds 4 allowed). Consider refactoring.',
                fingerprint: '98506525c60c9fe7cf2dd48f8f15bc32',
                severity: 'MAJOR',
                filePath: 'noise.rb',
                line: 16,
                webUrl:
                  'http://gdk.test:3000/root/code-quality-test/-/blob/091ce33570e71766c6e46bb2b8985f3072a0d047/noise.rb#L16',
                engineName: 'structure',
              },
            ],
            resolvedErrors: [],
            existingErrors: [],
            summary: {
              errored: 12,
              resolved: 0,
              total: 12,
            },
          },
        },
        sastReport: {
          status: 'ERROR',
          report: null,
        },
      },
    },
  },
});

export const SASTParsedHandler = jest.fn().mockResolvedValue({
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      mergeRequest: {
        id: 'gid://gitlab/MergeRequest/123',
        title: 'Update file noise.rb',
        project: {
          id: 'testid',
          nameWithNamespace: 'test/name',
          fullPath: 'testPath',
        },
        hasSecurityReports: false,
        codequalityReportsComparer: {
          status: 'PARSING',
          report: {
            status: 'FAILED',
            newErrors: [],
            resolvedErrors: [],
            existingErrors: [],
            summary: {
              errored: 12,
              resolved: 0,
              total: 12,
            },
          },
        },
        sastReport: {
          status: FINDINGS_STATUS_PARSED,
          report: SAST_REPORT_DATA,
        },
      },
    },
  },
});
