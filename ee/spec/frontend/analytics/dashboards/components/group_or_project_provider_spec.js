import VueApollo from 'vue-apollo';
import Vue from 'vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';
import GetGroupOrProjectQuery from '~/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import { mockGroup, mockProject } from '../mock_data';

Vue.use(VueApollo);

describe('GroupOrProjectProvider', () => {
  let wrapper;
  let mockHandler;

  const fullPath = 'fake/full/path';
  const defaultScopedSlotSpy = jest.fn();
  const scopedSlots = {
    default: defaultScopedSlotSpy,
  };

  const createComponent = async ({ groupOrProjectResolver, group, project }) => {
    const apolloProvider = createMockApollo([
      [
        GetGroupOrProjectQuery,
        groupOrProjectResolver || jest.fn().mockResolvedValueOnce({ data: { group, project } }),
      ],
    ]);

    wrapper = shallowMountExtended(GroupOrProjectProvider, {
      apolloProvider,
      propsData: {
        fullPath,
      },
      scopedSlots,
    });

    await waitForPromises();
  };

  afterEach(() => {
    defaultScopedSlotSpy.mockRestore();
  });

  describe('default', () => {
    beforeEach(async () => {
      mockHandler = jest.fn().mockResolvedValueOnce({ data: { group: mockGroup, project: null } });
      await createComponent({ groupOrProjectResolver: mockHandler });
    });

    it('requests the group or project namespace', () => {
      expect(mockHandler).toHaveBeenCalled();
    });

    it('emits `done` when the request completes', () => {
      expect(wrapper.emitted('done')).toBeDefined();
    });

    it('sets isNamespaceLoading=false', () => {
      expect(defaultScopedSlotSpy).toHaveBeenCalledWith(
        expect.objectContaining({ isNamespaceLoading: false }),
      );
    });
  });

  describe('loading', () => {
    beforeEach(async () => {
      mockHandler = jest.fn().mockImplementation(() => new Promise(() => {}));
      await createComponent({ groupOrProjectResolver: mockHandler });
    });

    it('sets isNamespaceLoading=true', () => {
      expect(defaultScopedSlotSpy).toHaveBeenCalledWith(
        expect.objectContaining({ isNamespaceLoading: true }),
      );
    });
  });

  describe('slot data', () => {
    it.each`
      type         | group        | project        | isProject
      ${'group'}   | ${mockGroup} | ${null}        | ${false}
      ${'project'} | ${null}      | ${mockProject} | ${true}
    `(
      'correctly sets the scope data given a $type namespace',
      async ({ group, project, isProject }) => {
        await createComponent({ group, project });

        expect(defaultScopedSlotSpy).toHaveBeenCalledWith({
          group,
          project,
          isProject,
          isNamespaceLoading: false,
        });
      },
    );
  });

  describe('with a failing request', () => {
    beforeEach(async () => {
      mockHandler = jest.fn().mockRejectedValue();

      await createComponent({ groupOrProjectResolver: mockHandler });
    });

    it('emits `error` for a request failure', () => {
      expect(wrapper.emitted('error')).toEqual([['Failed to fetch Namespace: fake/full/path']]);
    });

    it('sets isNamespaceLoading=false', () => {
      expect(defaultScopedSlotSpy).toHaveBeenCalledWith(
        expect.objectContaining({ isNamespaceLoading: false }),
      );
    });
  });
});
