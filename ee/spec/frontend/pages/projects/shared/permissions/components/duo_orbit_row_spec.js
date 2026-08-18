import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';
import DuoOrbitRow from 'ee/pages/projects/shared/permissions/components/duo_orbit_row.vue';
import orbitUpdateMutation from 'ee/orbit/graphql/mutations/orbit_update.mutation.graphql';
import { fetchGraphStatus } from 'ee/orbit/api/orbit_api';

jest.mock('~/alert');
jest.mock('ee/orbit/api/orbit_api', () => ({
  fetchGraphStatus: jest.fn(),
}));

Vue.use(VueApollo);

describe('DuoOrbitRow', () => {
  let wrapper;
  let mutationHandler;

  const defaultOrbit = {
    enabled: false,
    canEnable: false,
    rootGroupPath: 'gitlab-org',
    graphPath: '/-/dashboard/orbit',
  };

  const successResponse = {
    data: {
      orbitUpdate: {
        group: {
          id: 'gid://gitlab/Group/1',
          name: 'gitlab-org',
          fullPath: 'gitlab-org',
          knowledgeGraphEnabled: true,
          __typename: 'Group',
        },
        errors: [],
        __typename: 'OrbitUpdatePayload',
      },
    },
  };

  const createComponent = ({
    orbit = {},
    handler = jest.fn().mockResolvedValue(successResponse),
  } = {}) => {
    mutationHandler = handler;
    wrapper = mountExtended(DuoOrbitRow, {
      apolloProvider: createMockApollo([[orbitUpdateMutation, mutationHandler]]),
      propsData: {
        orbit: { ...defaultOrbit, ...orbit },
        projectFullPath: 'gitlab-org/gitlab',
      },
    });
  };

  const findRow = () => wrapper.findComponent(DuoReadinessRow);
  const findEnableButton = () => wrapper.findByTestId('orbit-enable-button');
  const findQueryGraphButton = () => wrapper.findByTestId('orbit-query-graph-button');

  beforeEach(() => {
    fetchGraphStatus.mockResolvedValue({ data: { indexing: { last_completed_at: null } } });
  });

  describe('when Orbit is not enabled', () => {
    it('renders a neutral to-do row that names who can turn it on', () => {
      createComponent();

      expect(findRow().props('title')).toBe('GitLab Orbit');
      expect(findRow().props('status')).toBe('todo');
      expect(findRow().props('description')).toBe(
        'A knowledge graph that helps agents reason across your whole project. Only a Group Owner can turn it on.',
      );
    });

    it('does not read the graph status', () => {
      createComponent();

      expect(fetchGraphStatus).not.toHaveBeenCalled();
    });

    describe('when the user cannot enable it', () => {
      it('offers no control', () => {
        createComponent();

        expect(findEnableButton().exists()).toBe(false);
        expect(findQueryGraphButton().exists()).toBe(false);
      });
    });

    describe('when the user can enable it', () => {
      it('offers Enable', () => {
        createComponent({ orbit: { canEnable: true } });

        expect(findEnableButton().text()).toBe('Enable');
        expect(findRow().props('description')).toBe(
          'A knowledge graph that helps agents reason across your whole project.',
        );
      });
    });
  });

  describe('enabling', () => {
    it('calls the mutation for the root group and flips the row to done', async () => {
      createComponent({ orbit: { canEnable: true } });

      findEnableButton().trigger('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: { groupPath: 'gitlab-org', enabled: true },
      });
      expect(findRow().props('status')).toBe('done');
      expect(findQueryGraphButton().exists()).toBe(true);
      expect(fetchGraphStatus).toHaveBeenCalledWith('gitlab-org/gitlab');
    });

    it('keeps the row as to-do and alerts when the mutation returns errors', async () => {
      createComponent({
        orbit: { canEnable: true },
        handler: jest.fn().mockResolvedValue({
          data: {
            orbitUpdate: { group: null, errors: ['not allowed'], __typename: 'OrbitUpdatePayload' },
          },
        }),
      });

      findEnableButton().trigger('click');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Something went wrong while turning on GitLab Orbit.',
        }),
      );
      expect(findRow().props('status')).toBe('todo');
    });
  });

  describe('when Orbit is enabled', () => {
    it('reads the graph status and shows freshness', async () => {
      fetchGraphStatus.mockResolvedValue({
        data: { indexing: { last_completed_at: '2020-07-05T10:00:00Z' } },
      });
      createComponent({ orbit: { enabled: true } });
      await waitForPromises();

      expect(fetchGraphStatus).toHaveBeenCalledWith('gitlab-org/gitlab');
      expect(findRow().props('description')).toMatch(
        /^Indexed .+\. Agents get repo-wide context\.$/,
      );
      expect(findQueryGraphButton().attributes('href')).toBe('/-/dashboard/orbit');
    });

    describe('when the status read fails', () => {
      it('falls back to a generic description', async () => {
        fetchGraphStatus.mockRejectedValue(new Error('unavailable'));
        createComponent({ orbit: { enabled: true } });
        await waitForPromises();

        expect(findRow().props('description')).toBe('Agents get repo-wide context.');
      });
    });
  });
});
