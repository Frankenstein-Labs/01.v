import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable, GlButton, GlLabel } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ProjectAttributesList from 'ee/security_configuration/security_attributes/components/project_attributes_list.vue';
import ProjectAttributesUpdateDrawer from 'ee/security_configuration/security_attributes/components/project_attributes_update_drawer.vue';
import getProjectSecurityAttributesQuery from 'ee/security_configuration/graphql/project_security_attributes.query.graphql';
import ProjectSecurityAttributesUpdateMutation from 'ee/security_configuration/graphql/project_security_attributes_update.mutation.graphql';
import getSecurityCategoriesAndAttributes from 'ee/security_configuration/graphql/group_security_categories_and_attributes.query.graphql';
import { mockSecurityAttributeCategories, mockSecurityAttributesWithCategories } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/alert');

describe('ProjectAttributesList', () => {
  let wrapper;
  let projectQueryHandler;

  let updateMutationHandler = jest.fn().mockResolvedValue({
    data: {
      securityAttributeProjectUpdate: { removedCount: 1, addedCount: 1, errors: [] },
    },
  });

  const groupCategoriesQueryHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/group',
        securityCategories: mockSecurityAttributeCategories,
      },
    },
  });

  const createComponent = (mountFn = shallowMountExtended, provide) => {
    projectQueryHandler = jest.fn().mockResolvedValue({
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          securityAttributes: { nodes: mockSecurityAttributesWithCategories },
        },
      },
    });

    const apolloProvider = createMockApollo([
      [getProjectSecurityAttributesQuery, projectQueryHandler],
      [ProjectSecurityAttributesUpdateMutation, updateMutationHandler],
      [getSecurityCategoriesAndAttributes, groupCategoriesQueryHandler],
    ]);

    wrapper = mountFn(ProjectAttributesList, {
      provide: {
        projectFullPath: 'path/to/project',
        groupFullPath: 'path/to/group',
        canManageAttributes: true,
        ...provide,
      },
      apolloProvider,
      stubs: {
        GlTable,
        GlButton,
        GlLabel,
        ProjectAttributesUpdateDrawer,
      },
      mocks: {
        $toast: { show: jest.fn() },
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRows = () => findTable().findAll('tbody tr');
  const findDrawer = () => wrapper.findComponent(ProjectAttributesUpdateDrawer);
  const findEditButton = () => wrapper.findAllComponents(GlButton).at(0);
  const findAddbutton = () =>
    wrapper
      .findAllComponents(GlButton)
      .filter((button) => button.text().includes('Add attributes'));

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(() => {
    createComponent();
  });

  describe('tracking and rendering', () => {
    it('tracks a page view event on mount', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      expect(trackEventSpy).toHaveBeenCalledWith('view_project_security_attributes', {}, undefined);
    });

    it('renders the informational text', () => {
      expect(wrapper.text()).toContain(
        'Security attributes help classify and organize your projects',
      );
    });

    it('renders the add attributes button', () => {
      expect(findAddbutton()).toHaveLength(1);
    });
  });

  describe('table rendering', () => {
    beforeEach(async () => {
      createComponent(mountExtended);
      await waitForPromises();
    });

    it('renders each attribute with category, name, and description', () => {
      const rows = findTableRows();
      expect(rows).toHaveLength(mockSecurityAttributesWithCategories.length);

      mockSecurityAttributesWithCategories.forEach((attr, i) => {
        const rowText = rows.at(i).text();
        expect(rowText).toContain(attr.securityCategory.name);
        expect(rowText).toContain(attr.name);
        expect(rowText).toContain(attr.description);
      });
    });
  });

  describe('edit drawer interactions', () => {
    beforeEach(async () => {
      createComponent(mountExtended);
      await waitForPromises();
    });

    it('opens the edit drawer when clicking the edit button', async () => {
      const openDrawerSpy = jest.spyOn(findDrawer().vm, 'openDrawer');
      await findEditButton().trigger('click');
      expect(openDrawerSpy).toHaveBeenCalled();
    });

    it('refreshes the project data when drawer emits "saved"', async () => {
      const refetchSpy = jest.spyOn(wrapper.vm.$apollo.queries.project, 'refetch');
      findDrawer().vm.$emit('saved');
      await nextTick();
      expect(refetchSpy).toHaveBeenCalled();
    });
  });

  describe('attribute removal', () => {
    it('removes an attribute and shows a toast notification', async () => {
      createComponent(mountExtended);
      await waitForPromises();

      const firstRow = findTableRows().at(0);
      const removeButton = firstRow.findAllComponents(GlButton).at(0);
      const expectedAttribute = mockSecurityAttributesWithCategories[0];

      await removeButton.trigger('click');
      await waitForPromises();

      expect(updateMutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            projectId: 'gid://gitlab/Project/1',
            removeAttributeIds: [expectedAttribute.id],
          }),
        }),
      );

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        `Successfully removed "${expectedAttribute.name}" security attribute from this project`,
      );
    });

    it('calls sentry and creates an alert on error', async () => {
      updateMutationHandler = jest.fn().mockRejectedValue(new Error());
      createComponent(mountExtended);
      await waitForPromises();

      const firstRow = findTableRows().at(0);
      const removeButton = firstRow.findAllComponents(GlButton).at(0);
      await removeButton.trigger('click');
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalled();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error has occurred while removing the security attribute.',
      });
    });
  });

  describe('without admin permission', () => {
    beforeEach(async () => {
      createComponent(mountExtended, { canManageAttributes: false });
      await waitForPromises();
    });

    it('does not show the edit button or the drawer', () => {
      expect(wrapper.findComponent(GlButton).exists()).toBe(false);
      expect(wrapper.findComponent(ProjectAttributesUpdateDrawer).exists()).toBe(false);
    });

    it('does not show actions', () => {
      expect(findTableRows().at(0).findComponent(GlButton).exists()).toBe(false);
    });

    it('does not show the add attributes button', () => {
      expect(findAddbutton()).toHaveLength(0);
    });
  });
});
