import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DevopsAdoptionAddDropdown from 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_add_dropdown.vue';
import {
  I18N_GROUP_DROPDOWN_TEXT,
  I18N_GROUP_DROPDOWN_HEADER,
  I18N_ADMIN_DROPDOWN_TEXT,
  I18N_ADMIN_DROPDOWN_HEADER,
  I18N_NO_SUB_GROUPS,
} from 'ee/analytics/devops_reports/devops_adoption/constants';
import bulkEnableDevopsAdoptionNamespacesMutation from 'ee/analytics/devops_reports/devops_adoption/graphql/mutations/bulk_enable_devops_adoption_namespaces.mutation.graphql';
import disableDevopsAdoptionNamespaceMutation from 'ee/analytics/devops_reports/devops_adoption/graphql/mutations/disable_devops_adoption_namespace.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  groupNodes,
  groupGids,
  devopsAdoptionNamespaceData,
  genericDeleteErrorMessage,
} from '../mock_data';

Vue.use(VueApollo);

const mutateAdd = jest.fn().mockResolvedValue({
  data: {
    bulkEnableDevopsAdoptionNamespaces: {
      enabledNamespaces: [devopsAdoptionNamespaceData.nodes[0]],
      errors: [],
    },
  },
});
const mutateDisable = jest.fn().mockResolvedValue({
  data: {
    disableDevopsAdoptionNamespace: {
      errors: [],
    },
  },
});

const mutateWithErrors = jest.fn().mockRejectedValue(genericDeleteErrorMessage);

describe('DevopsAdoptionAddDropdown', () => {
  let wrapper;

  const createComponent = ({
    enableNamespaceSpy = mutateAdd,
    disableNamespaceSpy = mutateDisable,
    provide = {},
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([
      [bulkEnableDevopsAdoptionNamespacesMutation, enableNamespaceSpy],
      [disableDevopsAdoptionNamespaceMutation, disableNamespaceSpy],
    ]);

    wrapper = shallowMountExtended(DevopsAdoptionAddDropdown, {
      apolloProvider: mockApollo,
      propsData: {
        groups: [],
        ...props,
      },
      provide,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        GlCollapsibleListbox,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays a listbox component', () => {
      expect(findListbox().exists()).toBe(true);
    });

    it('displays the correct text', () => {
      expect(findListbox().props('toggleText')).toBe(I18N_ADMIN_DROPDOWN_TEXT);
      expect(findListbox().props('headerText')).toBe(I18N_ADMIN_DROPDOWN_HEADER);
    });

    it('is disabled', () => {
      expect(findListbox().props('disabled')).toBe(true);
    });

    it('displays a tooltip', () => {
      const tooltip = getBinding(findListbox().element, 'gl-tooltip');

      expect(tooltip).toBeDefined();
      expect(tooltip.value).toBe(I18N_NO_SUB_GROUPS);
    });
  });

  describe('with isGroup === true', () => {
    it('displays the correct text', () => {
      createComponent({ provide: { isGroup: true } });

      expect(findListbox().props('toggleText')).toBe(I18N_GROUP_DROPDOWN_TEXT);
      expect(findListbox().props('headerText')).toBe(I18N_GROUP_DROPDOWN_HEADER);
    });
  });

  describe('with sub-groups available', () => {
    describe('displays the correct components', () => {
      beforeEach(() => {
        createComponent({ props: { hasSubgroups: true } });
      });

      it('is enabled', () => {
        expect(findListbox().props('disabled')).toBe(false);
      });

      it('does not display a tooltip', () => {
        const tooltip = getBinding(findListbox().element, 'gl-tooltip');

        expect(tooltip.value).toBe(false);
      });

      it('displays the no results message', () => {
        expect(findListbox().text()).toContain('No results…');
      });
    });

    describe('with group data', () => {
      it('displays the correct number of groups', () => {
        createComponent({ props: { hasSubgroups: true, groups: groupNodes } });

        expect(findListbox().props('items')).toHaveLength(groupNodes.length);
      });

      describe('on select', () => {
        describe.each`
          level      | enabledNamespaces
          ${'group'} | ${undefined}
          ${'group'} | ${devopsAdoptionNamespaceData}
          ${'admin'} | ${undefined}
          ${'admin'} | ${devopsAdoptionNamespaceData}
        `('$level level successful request', ({ groupGid, enabledNamespaces }) => {
          beforeEach(() => {
            createComponent({
              props: { hasSubgroups: true, groups: groupNodes, enabledNamespaces },
              provide: { groupGid },
            });
            findListbox().vm.$emit('select', [getIdFromGraphQLId(groupGids[0])]);
          });

          if (!enabledNamespaces) {
            it('makes a request to enable the selected group', () => {
              expect(mutateAdd).toHaveBeenCalledWith({
                displayNamespaceId: groupGid,
                namespaceIds: [groupGids[0]],
              });
            });

            it('emits the enabled-namespaces-added event', () => {
              const [params] = wrapper.emitted('enabled-namespaces-added')[0];
              expect(params).toEqual([devopsAdoptionNamespaceData.nodes[0]]);
            });
          } else {
            it('makes a request to disable the selected group', () => {
              expect(mutateDisable).toHaveBeenCalledWith({
                id: [devopsAdoptionNamespaceData.nodes[1].id],
              });
            });

            it('emits the enabled-namespaces-removed event', () => {
              const [params] = wrapper.emitted('enabled-namespaces-removed')[0];

              expect(params).toEqual([devopsAdoptionNamespaceData.nodes[1].id]);
            });
          }
        });

        describe('when multiple values are selected', () => {
          const groupGid = 'gid://gitlab/Group/1';

          // Generate a unique ID, that is guaranteed to be not in the list
          // of existing IDs. Illya doesn't like it, Lukas doesn't like it,
          // but it works
          const uniqueId = groupGids.reduce((acc, curr) => acc + getIdFromGraphQLId(curr), 0);

          beforeEach(() => {
            createComponent({
              props: {
                hasSubgroups: true,
                groups: groupNodes,
                enabledNamespaces: devopsAdoptionNamespaceData,
              },
              provide: { groupGid },
            });
            findListbox().vm.$emit('select', [getIdFromGraphQLId(groupGids[0]), uniqueId]);
          });

          it('makes a request to enable the newly selected group', () => {
            expect(mutateAdd).toHaveBeenCalledWith({
              displayNamespaceId: groupGid,
              namespaceIds: [`gid://gitlab/Group/${uniqueId}`],
            });
          });

          it('makes a request to disable the newly deselected group', () => {
            expect(mutateDisable).toHaveBeenCalledWith({
              id: [devopsAdoptionNamespaceData.nodes[1].id],
            });
          });
        });

        describe('on error', () => {
          beforeEach(async () => {
            jest.spyOn(Sentry, 'captureException');

            createComponent({
              enableNamespaceSpy: mutateWithErrors,
              props: { hasSubgroups: true, groups: groupNodes },
            });

            findListbox().vm.$emit('select', [groupGids[0]]);
            await waitForPromises();
          });

          it('calls sentry', async () => {
            await waitForPromises();
            expect(Sentry.captureException.mock.calls[0][0].networkError).toBe(
              genericDeleteErrorMessage,
            );
          });

          it('does not emit the enabled-namespaces-added event', () => {
            expect(wrapper.emitted('enabled-namespaces-added')).not.toBeDefined();
          });
        });
      });
    });

    describe('while loading', () => {
      beforeEach(() => {
        createComponent({ props: { isLoadingGroups: true } });
      });

      it('displays a loading icon', () => {
        expect(findListbox().props('loading')).toBe(true);
      });

      it('does not display any items', () => {
        expect(findListbox().props('items')).toHaveLength(0);
      });
    });

    describe('searching', () => {
      it('emits the fetch-groups event', () => {
        createComponent({ props: { hasSubgroups: true } });

        findListbox().vm.$emit('search', 'blah');

        jest.runAllTimers();

        const [params] = wrapper.emitted('fetch-groups')[0];

        expect(params).toBe('blah');
      });
    });
  });
});
