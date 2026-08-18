import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StreamNamespaceFilters from 'ee/audit_events/components/stream/stream_namespace_filters.vue';
import getNamespaceFiltersQuery from 'ee/audit_events/graphql/queries/get_namespace_filters.query.graphql';

import { AUDIT_STREAMS_FILTERING, MAXIMUM_NAMESPACE_FILTERS } from 'ee/audit_events/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockAuditEventDefinitions, getMockNamespaceFilters } from '../../mock_data';

Vue.use(VueApollo);

const namespaceFilters = getMockNamespaceFilters();
const allGroups = namespaceFilters.data.group.descendantGroups.nodes;
const allProjects = namespaceFilters.data.group.projects.nodes;
const getNamespaceFiltersQueryFn = jest.fn().mockResolvedValue(namespaceFilters);
const makeFakeApollo = () =>
  createMockApollo([[getNamespaceFiltersQuery, getNamespaceFiltersQueryFn]]);

describe('StreamNamespaceFilters', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(StreamNamespaceFilters, {
      propsData: {
        value: [],
        ...props,
      },
      apolloProvider: makeFakeApollo(),
      provide: {
        auditEventDefinitions: mockAuditEventDefinitions,
        groupPath: 'group1',
      },
    });
  };

  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSelectionCount = () => wrapper.findByTestId('namespace-filter-selection-count');

  beforeEach(() => createComponent());

  it('renders the listbox as multi-select with the expected props', () => {
    expect(findCollapsibleListbox().props()).toMatchObject(
      expect.objectContaining({
        items: expect.any(Array),
        multiple: true,
        searchable: true,
        toggleClass: 'gl-max-w-full',
      }),
    );
    expect(findCollapsibleListbox().classes('gl-max-w-full')).toBe(true);
  });

  describe('while the source query is loading', () => {
    it('passes searching state to the listbox', () => {
      expect(findCollapsibleListbox().props('searching')).toBe(true);
    });
  });

  describe('once the source query has resolved', () => {
    beforeEach(waitForPromises);

    describe('selection', () => {
      it('emits `input` with a single entry when one path is selected', () => {
        const target = allProjects[1];

        findCollapsibleListbox().vm.$emit('select', [target.fullPath]);

        expect(wrapper.emitted('input')).toStrictEqual([
          [
            [
              {
                namespace: target.fullPath,
                name: target.name,
              },
            ],
          ],
        ]);
      });

      it('emits `input` with all selected entries when multiple paths are selected', () => {
        const target1 = allGroups[0];
        const target2 = allProjects[0];

        findCollapsibleListbox().vm.$emit('select', [target1.fullPath, target2.fullPath]);

        expect(wrapper.emitted('input')[0][0]).toStrictEqual([
          { namespace: target1.fullPath, name: target1.name },
          { namespace: target2.fullPath, name: target2.name },
        ]);
      });

      it('preserves previously selected entries when re-selecting after a search narrowed the source', async () => {
        createComponent({
          value: [{ namespace: allGroups[0].fullPath, name: allGroups[0].name }],
        });
        await waitForPromises();

        findCollapsibleListbox().vm.$emit('select', [
          allGroups[0].fullPath,
          allProjects[0].fullPath,
        ]);

        expect(wrapper.emitted('input')[0][0]).toStrictEqual([
          { namespace: allGroups[0].fullPath, name: allGroups[0].name },
          { namespace: allProjects[0].fullPath, name: allProjects[0].name },
        ]);
      });

      it('emits an empty array when `reset` fires', () => {
        findCollapsibleListbox().vm.$emit('reset');

        expect(wrapper.emitted('input')).toStrictEqual([[[]]]);
      });

      it('caps the emitted selection at MAXIMUM_NAMESPACE_FILTERS', () => {
        const tooMany = [
          ...allGroups.map((g) => g.fullPath),
          ...allProjects.map((p) => p.fullPath),
          'extra/path',
        ];
        expect(MAXIMUM_NAMESPACE_FILTERS).toBe(5);

        findCollapsibleListbox().vm.$emit('select', tooMany);

        const emitted = wrapper.emitted('input')[0][0];
        expect(emitted.length).toBeLessThanOrEqual(MAXIMUM_NAMESPACE_FILTERS);
      });
    });

    describe('search', () => {
      it('passes the search term through to the apollo query', async () => {
        await findCollapsibleListbox().vm.$emit('search', 'project');
        await nextTick();

        expect(getNamespaceFiltersQueryFn).toHaveBeenCalledWith({
          fullPath: 'group1',
          search: 'project',
        });
      });
    });

    describe('toggle text', () => {
      it('shows the placeholder when nothing is selected', () => {
        expect(findCollapsibleListbox().props('toggleText')).toBe(
          AUDIT_STREAMS_FILTERING.SELECT_NAMESPACE,
        );
      });

      it('shows the namespace name when a single entry is selected', async () => {
        createComponent({
          value: [{ namespace: allProjects[0].fullPath, name: allProjects[0].name }],
        });
        await waitForPromises();

        expect(findCollapsibleListbox().props('toggleText')).toBe(allProjects[0].name);
      });

      it('shows a comma-separated list for a small number of selected entries', async () => {
        createComponent({
          value: [
            { namespace: allGroups[0].fullPath, name: allGroups[0].name },
            { namespace: allProjects[0].fullPath, name: allProjects[0].name },
          ],
        });
        await waitForPromises();

        const text = findCollapsibleListbox().props('toggleText');
        expect(text).toContain(allGroups[0].name);
        expect(text).toContain(allProjects[0].name);
      });

      it('falls back to the namespace path when the source has not provided a name', async () => {
        createComponent({
          value: [{ namespace: 'unloaded/path' }],
        });
        await waitForPromises();

        expect(findCollapsibleListbox().props('toggleText')).toBe('unloaded/path');
      });
    });

    describe('selection counter', () => {
      it('shows "0 of 5 selected" when nothing is selected', () => {
        expect(findSelectionCount().text()).toBe('0 of 5 selected');
      });

      it('shows "2 of 5 selected" when two entries are selected', async () => {
        createComponent({
          value: [
            { namespace: allGroups[0].fullPath, name: allGroups[0].name },
            { namespace: allProjects[0].fullPath, name: allProjects[0].name },
          ],
        });
        await waitForPromises();

        expect(findSelectionCount().text()).toBe('2 of 5 selected');
      });

      it('shows "5 of 5 selected" when the maximum is reached', async () => {
        createComponent({
          value: [
            { namespace: 'path/1' },
            { namespace: 'path/2' },
            { namespace: 'path/3' },
            { namespace: 'path/4' },
            { namespace: 'path/5' },
          ],
        });
        await waitForPromises();

        expect(findSelectionCount().text()).toBe('5 of 5 selected');
      });
    });
  });
});
