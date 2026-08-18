import {
  mockGroupNamespaceMetadata,
  mockProjectNamespaceMetadata,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';
import fetch, {
  extractNamespaceMetadata,
} from 'ee/analytics/analytics_dashboards/data_sources/namespace_metadata';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';

describe('Namespace metadata data source', () => {
  let obj;
  const namespace = 'gitlab-org';
  const setAlerts = jest.fn();

  const mockGroupNamespaceMetadataQueryResponse = {
    group: {
      id: 'gid://gitlab/Group/225',
      fullName: 'GitLab Org',
      avatarUrl: '/avatar.png',
      visibility: 'public',
      __typename: 'Group',
    },
    project: null,
  };

  const mockProjectNamespaceMetadataQueryResponse = {
    project: {
      id: 'gid://gitlab/Project/7',
      fullName: 'GitLab Org / GitLab',
      avatarUrl: '/avatar.png',
      visibility: 'internal',
      __typename: 'Project',
    },
    group: null,
  };
  const { group: mockGroupNamespaceDataResponse } = mockGroupNamespaceMetadataQueryResponse;
  const { project: mockProjectNamespaceDataResponse } = mockProjectNamespaceMetadataQueryResponse;

  describe('extractNamespaceMetadata', () => {
    it.each`
      namespaceType | isProjectNamespace | namespaceDataResponse               | expectedNamespaceData
      ${'group'}    | ${false}           | ${mockGroupNamespaceDataResponse}   | ${mockGroupNamespaceMetadata}
      ${'project'}  | ${true}            | ${mockProjectNamespaceDataResponse} | ${mockProjectNamespaceMetadata}
    `(
      'returns the $namespaceType namespace metadata as expected',
      ({ isProjectNamespace, namespaceDataResponse, expectedNamespaceData }) => {
        expect(
          extractNamespaceMetadata({ data: namespaceDataResponse, isProjectNamespace }),
        ).toEqual(expectedNamespaceData);
      },
    );
  });

  describe('fetch', () => {
    describe('namespace', () => {
      beforeEach(() => {
        jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });
      });

      it('uses the default namespace', async () => {
        await fetch({ namespace });

        expect(defaultClient.query).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              fullPath: namespace,
            },
          }),
        );
      });

      describe('with namespace override', () => {
        const namespaceOverride = 'some-namespace-override-path';

        beforeEach(async () => {
          await fetch({ namespace, query: { namespace: namespaceOverride } });
        });

        it('applies the namespace override', () => {
          expect(defaultClient.query).toHaveBeenCalledWith(
            expect.objectContaining({
              variables: {
                fullPath: namespaceOverride,
              },
            }),
          );
        });
      });

      describe('with no namespace', () => {
        it('returns an empty object', async () => {
          obj = await fetch({ namespace: null });

          expect(obj).toEqual({});
        });
      });
    });

    describe.each`
      namespaceTypeDescription | queryResponse                                | namespaceMetadata
      ${'group namespace'}     | ${mockGroupNamespaceMetadataQueryResponse}   | ${mockGroupNamespaceMetadata}
      ${'project namespace'}   | ${mockProjectNamespaceMetadataQueryResponse} | ${mockProjectNamespaceMetadata}
    `(
      '$namespaceTypeDescription query successfully completes',
      ({ queryResponse, namespaceMetadata }) => {
        beforeEach(async () => {
          jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: queryResponse });

          obj = await fetch({ namespace });
        });

        it(`will fetch the namespace's metadata`, () => {
          expect(obj).toEqual(namespaceMetadata);
        });
      },
    );

    describe('with no data', () => {
      beforeEach(async () => {
        jest.spyOn(defaultClient, 'query').mockResolvedValue({ group: null, project: null });

        obj = await fetch({ namespace });
      });

      it('returns an empty object', () => {
        expect(obj).toEqual({});
      });
    });

    describe('with an error', () => {
      beforeEach(async () => {
        jest.spyOn(defaultClient, 'query').mockRejectedValue({});

        obj = await fetch({ namespace, setAlerts });
      });

      it('calls `setAlerts` with the correct error message', () => {
        expect(setAlerts).toHaveBeenCalledWith({
          title: 'Failed to load dashboard panel.',
          errors: expect.arrayContaining(['Failed to load namespace metadata.']),
        });
      });
    });
  });
});
