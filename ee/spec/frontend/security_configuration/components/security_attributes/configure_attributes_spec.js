import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import ConfigureAttributes from 'ee/security_configuration/components/security_attributes/configure_attributes.vue';
import CategoryList from 'ee/security_configuration/components/security_attributes/category_list.vue';
import CategoryForm from 'ee/security_configuration/components/security_attributes/category_form.vue';
import AttributeDrawer from 'ee/security_configuration/components/security_attributes/attribute_drawer.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSecurityAttributesQuery from 'ee/security_configuration/graphql/security_attributes.query.graphql';
import createSecurityCategoryMutation from 'ee/security_configuration/graphql/security_category_create.mutation.graphql';
import updateSecurityCategoryMutation from 'ee/security_configuration/graphql/security_category_update.mutation.graphql';
import deleteSecurityCategoryMutation from 'ee/security_configuration/graphql/security_category_delete.mutation.graphql';
import createSecurityAttributesMutation from 'ee/security_configuration/graphql/security_attributes_create.mutation.graphql';
import updateSecurityAttributeMutation from 'ee/security_configuration/graphql/security_attribute_update.mutation.graphql';
import deleteSecurityAttributeMutation from 'ee/security_configuration/graphql/security_attribute_delete.mutation.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  mockSecurityAttributeCategories,
  mockFailedCategoryCreateResponse,
  mockFailedAttributeCreateResponse,
  mockFailedAttributeUpdateResponse,
} from './mock_data';

jest.mock('~/vue_shared/plugins/global_toast');
jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
jest.mock('~/alert');

Vue.use(VueApollo);

const firstCategory = mockSecurityAttributeCategories[0];
const secondCategory = mockSecurityAttributeCategories[1];
const mockAttribute = mockSecurityAttributeCategories[0].securityAttributes[0];

describe('Configure attributes', () => {
  let wrapper;

  const handlers = {
    getSecurityAttributesQuery: jest.fn().mockResolvedValue({
      data: {
        group: {
          id: 'gid://gitlab/Group/group/1',
          securityCategories: mockSecurityAttributeCategories,
        },
      },
    }),
    createSecurityCategoryMutation: jest.fn().mockResolvedValue({
      data: {
        securityCategoryCreate: {
          securityCategory: mockSecurityAttributeCategories[0],
          errors: [],
        },
      },
    }),
    updateSecurityCategoryMutation: jest.fn().mockResolvedValue({
      data: {
        securityCategoryUpdate: {
          securityCategory: mockSecurityAttributeCategories[0],
          errors: [],
        },
      },
    }),
    deleteSecurityCategoryMutation: jest.fn().mockResolvedValue({
      data: {
        securityCategoryDestroy: {
          deletedCategoryGid: mockSecurityAttributeCategories[0].id,
          deletedAttributesGid: [],
          errors: [],
        },
      },
    }),
    createSecurityAttributesMutation: jest.fn().mockResolvedValue({
      data: {
        securityAttributeCreate: {
          securityAttributes: [
            { ...mockAttribute, editableState: '', securityCategory: { id: 'blah', name: 'blah' } },
          ],
          errors: [],
        },
      },
    }),
    updateSecurityAttributeMutation: jest.fn().mockResolvedValue({
      data: {
        securityAttributeUpdate: {
          securityAttribute: {
            ...mockAttribute,
            editableState: '',
            securityCategory: { id: 'blah', name: 'blah' },
          },
          errors: [],
        },
      },
    }),
    deleteSecurityAttributeMutation: jest.fn().mockResolvedValue({
      data: {
        securityAttributeDestroy: {
          deletedAttributeGid: mockSecurityAttributeCategories[0].securityAttributes[0].id,
          errors: [],
        },
      },
    }),
  };

  const createComponent = (
    requestHandlers = [
      [getSecurityAttributesQuery, handlers.getSecurityAttributesQuery],
      [createSecurityCategoryMutation, handlers.createSecurityCategoryMutation],
      [updateSecurityCategoryMutation, handlers.updateSecurityCategoryMutation],
      [deleteSecurityCategoryMutation, handlers.deleteSecurityCategoryMutation],
      [createSecurityAttributesMutation, handlers.createSecurityAttributesMutation],
      [updateSecurityAttributeMutation, handlers.updateSecurityAttributeMutation],
      [deleteSecurityAttributeMutation, handlers.deleteSecurityAttributeMutation],
    ],
  ) => {
    confirmAction.mockResolvedValue(true);
    const apolloProvider = createMockApollo(requestHandlers, [], {
      typePolicies: {
        Query: {
          fields: {
            group: {
              merge: true,
            },
          },
        },
      },
    });
    wrapper = shallowMount(ConfigureAttributes, {
      provide: { groupFullPath: 'path/to/group', namespaceId: 'namespace_id' },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
      apolloProvider,
    });
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  it('tracks a page view', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith('view_group_security_attributes', {}, undefined);
  });

  it('queries for the security attribute categories', () => {
    expect(handlers.getSecurityAttributesQuery).toHaveBeenCalledWith({
      fullPath: 'path/to/group',
    });
  });

  it('renders the list of categories', () => {
    expect(wrapper.findComponent(CategoryList).props()).toStrictEqual({
      securityCategories: mockSecurityAttributeCategories,
      selectedCategory: firstCategory,
    });
  });

  it('changes selected category when list emits select-category', async () => {
    expect(wrapper.findComponent(CategoryForm).props('selectedCategory')).toStrictEqual(
      firstCategory,
    );

    wrapper.findComponent(CategoryList).vm.$emit('select-category', secondCategory);
    await nextTick();

    expect(wrapper.findComponent(CategoryForm).props('selectedCategory')).toStrictEqual(
      secondCategory,
    );
  });

  it('opens the drawer when form emits add-attribute', async () => {
    wrapper.vm.$refs.attributeDrawer.open = jest.fn();

    wrapper.findComponent(CategoryForm).vm.$emit('add-attribute');
    await nextTick();

    expect(wrapper.vm.$refs.attributeDrawer.open).toHaveBeenCalledWith('add', undefined);
  });

  it('opens the drawer when form emits edit-attribute', async () => {
    wrapper.vm.$refs.attributeDrawer.open = jest.fn();

    wrapper
      .findComponent(CategoryForm)
      .vm.$emit('edit-attribute', mockSecurityAttributeCategories[0].securityAttributes[0]);
    await nextTick();

    expect(wrapper.vm.$refs.attributeDrawer.open).toHaveBeenCalledWith(
      'edit',
      expect.objectContaining({ name: 'Business Administrative' }),
    );
  });

  it('calls the category create mutation on save-category without id', async () => {
    const category = { name: 'Category' };
    wrapper.findComponent(CategoryForm).vm.$emit('save-category', category);
    await nextTick();

    expect(handlers.createSecurityCategoryMutation).toHaveBeenCalledWith(
      expect.objectContaining(category),
    );
  });

  it.each`
    handler                                                          | expectedMessage
    ${jest.fn().mockResolvedValue(mockFailedCategoryCreateResponse)} | ${'Namespace cannot have more than 20 categories'}
    ${jest.fn().mockRejectedValue()}                                 | ${'An error has occurred while saving the security category.'}
  `('shows an alert when category creation fails', async ({ handler, expectedMessage }) => {
    createComponent([
      [getSecurityAttributesQuery, handlers.getSecurityAttributesQuery],
      [createSecurityCategoryMutation, handler],
      [updateSecurityCategoryMutation, handlers.updateSecurityCategoryMutation],
      [deleteSecurityCategoryMutation, handlers.deleteSecurityCategoryMutation],
      [createSecurityAttributesMutation, handlers.createSecurityAttributesMutation],
      [updateSecurityAttributeMutation, handlers.updateSecurityAttributeMutation],
      [deleteSecurityAttributeMutation, handlers.deleteSecurityAttributeMutation],
    ]);

    const category = { name: 'Category' };
    wrapper.findComponent(CategoryForm).vm.$emit('save-category', category);
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message: expectedMessage,
    });
  });

  it('queues attributes for a new category and saves them once the category is saved', async () => {
    const category = { name: 'Category' };
    const attribute = { name: 'Attribute' };

    wrapper.vm.selectCategory(null);
    wrapper.findComponent(AttributeDrawer).vm.$emit('save-attribute', attribute);
    await nextTick();

    expect(handlers.createSecurityAttributesMutation).not.toHaveBeenCalled();

    wrapper.findComponent(CategoryForm).vm.$emit('save-category', category);
    await waitForPromises();

    expect(handlers.createSecurityCategoryMutation).toHaveBeenCalledWith(
      expect.objectContaining(category),
    );
    expect(handlers.createSecurityAttributesMutation).toHaveBeenCalledWith(
      expect.objectContaining({
        attributes: [attribute],
      }),
    );
  });

  it('calls the category update mutation on save-category with id', async () => {
    const category = { id: 'gid://gitlab/SecurityCategory/3', name: 'Category' };
    wrapper.findComponent(CategoryForm).vm.$emit('save-category', category);
    await nextTick();

    expect(handlers.updateSecurityCategoryMutation).toHaveBeenCalledWith(
      expect.objectContaining(category),
    );
  });

  it('calls the category delete mutation on delete-category', async () => {
    const category = { id: 'gid://gitlab/SecurityCategory/3', name: 'Category' };
    wrapper.findComponent(CategoryForm).vm.$emit('delete-category', category);
    await waitForPromises();

    expect(handlers.deleteSecurityCategoryMutation).toHaveBeenCalledWith({ id: category.id });
  });

  it('calls the attribute create mutation on save-attribute without id', async () => {
    const attribute = { name: 'Attribute' };
    wrapper.findComponent(AttributeDrawer).vm.$emit('save-attribute', attribute);
    await nextTick();

    expect(handlers.createSecurityAttributesMutation).toHaveBeenCalledWith(
      expect.objectContaining({
        attributes: [attribute],
      }),
    );
  });

  it.each`
    handler                                                                                   | expectedMessage
    ${jest.fn().mockResolvedValue(mockFailedAttributeCreateResponse)}                         | ${'Category cannot have more than 5 attributes.'}
    ${jest.fn().mockRejectedValue(new Error('Category cannot have more than 5 attributes.'))} | ${'Category cannot have more than 5 attributes.'}
    ${jest.fn().mockRejectedValue(new Error())}                                               | ${'An error has occurred while saving the security attribute.'}
  `('shows an alert when attribute creation fails', async ({ handler, expectedMessage }) => {
    createComponent([
      [getSecurityAttributesQuery, handlers.getSecurityAttributesQuery],
      [createSecurityCategoryMutation, handlers.createSecurityCategoryMutation],
      [updateSecurityCategoryMutation, handlers.updateSecurityCategoryMutation],
      [deleteSecurityCategoryMutation, handlers.deleteSecurityCategoryMutation],
      [createSecurityAttributesMutation, handler],
      [updateSecurityAttributeMutation, handlers.updateSecurityAttributeMutation],
      [deleteSecurityAttributeMutation, handlers.deleteSecurityAttributeMutation],
    ]);

    await waitForPromises();

    const attribute = { name: 'Attribute' };
    wrapper.findComponent(AttributeDrawer).vm.$emit('save-attribute', attribute);
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message: expectedMessage,
    });
  });

  it('calls the attribute update mutation on save-attribute with id', async () => {
    const attribute = { id: 'gid://gitlab/SecurityAttribute/123', name: 'Attribute' };
    wrapper.findComponent(AttributeDrawer).vm.$emit('save-attribute', attribute);
    await nextTick();

    expect(handlers.updateSecurityAttributeMutation).toHaveBeenCalledWith(attribute);
  });

  it.each`
    handler                                                                  | expectedMessage
    ${jest.fn().mockResolvedValue(mockFailedAttributeUpdateResponse)}        | ${'Name has already been taken'}
    ${jest.fn().mockRejectedValue(new Error('Name has already been taken'))} | ${'Name has already been taken'}
    ${jest.fn().mockRejectedValue(new Error())}                              | ${'An error has occurred while saving the security attribute.'}
  `('shows an alert when attribute update fails', async ({ handler, expectedMessage }) => {
    createComponent([
      [getSecurityAttributesQuery, handlers.getSecurityAttributesQuery],
      [createSecurityCategoryMutation, handlers.createSecurityCategoryMutation],
      [updateSecurityCategoryMutation, handlers.updateSecurityCategoryMutation],
      [deleteSecurityCategoryMutation, handlers.deleteSecurityCategoryMutation],
      [createSecurityAttributesMutation, handlers.createSecurityAttributesMutation],
      [updateSecurityAttributeMutation, handler],
      [deleteSecurityAttributeMutation, handlers.deleteSecurityAttributeMutation],
    ]);

    await waitForPromises();

    const attribute = { id: 'gid://gitlab/SecurityAttribute/123', name: 'Attribute' };
    wrapper.findComponent(AttributeDrawer).vm.$emit('save-attribute', attribute);
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message: expectedMessage,
    });
  });

  it('calls the attribute delete mutation on delete-attribute', async () => {
    const attribute = { id: 'gid://gitlab/SecurityAttribute/123', name: 'Attribute' };
    wrapper.findComponent(CategoryForm).vm.$emit('delete-attribute', attribute);
    await waitForPromises();

    expect(handlers.deleteSecurityAttributeMutation).toHaveBeenCalledWith({ id: attribute.id });
  });

  it('does not call the attribute delete mutation when ID is not present', async () => {
    const attribute = { id: null, name: 'Attribute', description: 'desc' };
    wrapper.findComponent(CategoryForm).vm.$emit('delete-attribute', attribute);
    await waitForPromises();

    expect(handlers.deleteSecurityAttributeMutation).not.toHaveBeenCalled();
  });
});
