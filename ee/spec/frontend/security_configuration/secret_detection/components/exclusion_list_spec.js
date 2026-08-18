import { mount, shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlTable,
  GlButton,
  GlToggle,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlModal,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { EXCLUSION_TYPE_MAP } from 'ee/security_configuration/secret_detection/constants';
import { stubComponent } from 'helpers/stub_component';
import ExclusionList from 'ee/security_configuration/secret_detection/components/exclusion_list.vue';
import { getTimeago } from '~/lib/utils/datetime_utility';
import UpdateMutation from 'ee/security_configuration/secret_detection/graphql/project_security_exclusion_update.mutation.graphql';
import { projectSecurityExclusions } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('ExclusionList', () => {
  let wrapper;
  let apolloProvider;

  const mockExclusion = projectSecurityExclusions[0];
  const mockToastShow = jest.fn();
  const mutateToggleStatus = jest.fn().mockResolvedValue({
    data: {
      projectSecurityExclusionUpdate: {
        errors: [],
        securityExclusion: {
          ...mockExclusion,
          active: false,
        },
      },
    },
  });

  const modalStub = { show: jest.fn(), hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });

  const createComponentFactory =
    (mountFn = shallowMount) =>
    ({ props = {}, resolver = mutateToggleStatus } = {}) => {
      apolloProvider = createMockApollo([[UpdateMutation, resolver]]);

      return mountFn(ExclusionList, {
        apolloProvider,
        propsData: {
          exclusions: projectSecurityExclusions,
          ...props,
        },
        provide: {
          projectFullPath: 'group/project',
        },
        stubs: {
          GlModal: GlModalStub,
        },
        mocks: {
          $toast: {
            show: mockToastShow,
          },
        },
      });
    };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory(mount);

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRowCells = (idx) => findTable().find('tbody').findAll('tr').at(idx).findAll('td');
  const findAddButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('Component rendering', () => {
    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('displays the correct heading text', () => {
      expect(wrapper.text()).toContain(
        'Specify file paths, raw values, and regex that should be excluded by secret detection in this project.',
      );
    });

    it('renders the "Add exclusion" button', () => {
      const addButton = findAddButton();
      expect(addButton.exists()).toBe(true);
      expect(addButton.text()).toBe('Add exclusion');
    });
  });

  describe('Add exclusion button', () => {
    it('emits correct event when clicked', async () => {
      await findAddButton().vm.$emit('click');
      expect(wrapper.emitted('add-exclusion')).toHaveLength(1);
    });
  });

  describe('Table', () => {
    it('renders the GlTable component with correct fields', () => {
      const table = findTable();
      expect(table.exists()).toBe(true);
      expect(table.props('fields')).toHaveLength(6);
      expect(table.props('fields').map((field) => field.key)).toEqual([
        'status',
        'type',
        'content',
        'enforcement',
        'modified',
        'actions',
      ]);
    });

    it('renders the GlTable with correct attributes', () => {
      const table = findTable();
      expect(table.attributes('selectable')).toBeDefined();
      expect(table.attributes('hover')).toBeDefined();
      expect(table.attributes('select-mode')).toBe('single');
      expect(table.attributes('stacked')).toBe('md');
      expect(table.attributes('select-mode')).toBe('single');
    });

    it('emits correct even on row clicked', async () => {
      wrapper = createFullComponent();
      const rowCells = findTableRowCells(0);
      await rowCells.at(0).trigger('click');
      expect(wrapper.emitted('view-exclusion')).toEqual([[mockExclusion]]);
    });

    it('renders correct values in table cells', () => {
      wrapper = createFullComponent();
      const rowCells = findTableRowCells(0);
      const exclusion = mockExclusion;

      expect(rowCells).toHaveLength(6);
      expect(rowCells.at(0).text()).toBe('Toggle exclusion');
      expect(rowCells.at(0).findComponent(GlToggle).props('value')).toBe(exclusion.active);
      expect(rowCells.at(1).text()).toBe(EXCLUSION_TYPE_MAP[exclusion.type].text);
      expect(rowCells.at(2).text()).toBe(exclusion.value);
      expect(rowCells.at(3).text()).toContain('Secret push protection');
      expect(rowCells.at(4).text()).toContain(getTimeago().format(exclusion.updatedAt));
    });
  });

  describe('Dropdown items', () => {
    beforeEach(() => {
      wrapper = createFullComponent();
    });

    it('renders the dropdown with correct items', () => {
      const actionCell = findTableRowCells(0).at(5);
      expect(actionCell.findComponent(GlDisclosureDropdown).exists()).toBe(true);

      const dropdownItems = actionCell.findAllComponents(GlDisclosureDropdownItem);
      expect(dropdownItems).toHaveLength(2);
      expect(dropdownItems.at(0).text()).toBe('Edit');
      expect(dropdownItems.at(1).text()).toBe('Delete');
    });

    it('emits correct event when edit is clicked', async () => {
      const actionCell = findTableRowCells(0).at(5);
      const editButton = actionCell
        .findAllComponents(GlDisclosureDropdownItem)
        .at(0)
        .find('button');

      await editButton.trigger('click');
      expect(wrapper.emitted('edit-exclusion')).toEqual([[mockExclusion]]);
    });

    it('calls deleteModal.show() when delete is clicked', async () => {
      const actionCell = findTableRowCells(0).at(5);
      const deleteButton = actionCell
        .findAllComponents(GlDisclosureDropdownItem)
        .at(1)
        .find('button');

      await deleteButton.trigger('click');
      expect(modalStub.show).toHaveBeenCalled();
    });
  });

  describe('Status toggle', () => {
    it('calls mutation on toggle change with correct payload', async () => {
      wrapper = createFullComponent();
      const toggle = findTableRowCells(0).at(0).findComponent(GlToggle);
      const newStatus = !mockExclusion.active;

      await toggle.vm.$emit('change', newStatus);

      expect(mutateToggleStatus).toHaveBeenCalledWith({
        input: {
          id: mockExclusion.id,
          active: newStatus,
        },
      });

      await waitForPromises();
      expect(mockToastShow).toHaveBeenCalledWith(`Exclusion disabled successfully.`);
    });

    it('captures exception in Sentry when unexpected error occurs', async () => {
      jest.spyOn(Sentry, 'captureException');
      const mockErrorResolver = jest.fn().mockRejectedValue(new Error('Unexpected error'));

      wrapper = createFullComponent({ resolver: mockErrorResolver });
      const toggle = findTableRowCells(0).at(0).findComponent(GlToggle);
      const newStatus = !mockExclusion.active;

      await toggle.vm.$emit('change', newStatus);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Unexpected error',
          title: 'Failed to update the exclusion:',
        }),
      );

      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Unexpected error'));
    });

    it('displays an error message when deletion fails', async () => {
      const errorMessage = 'Something went wrong';
      const mockErrorResolver = jest.fn().mockResolvedValue({
        data: {
          projectSecurityExclusionUpdate: {
            errors: [errorMessage],
            securityExclusion: null,
          },
        },
      });

      wrapper = createFullComponent({ resolver: mockErrorResolver });
      const toggle = findTableRowCells(0).at(0).findComponent(GlToggle);
      const newStatus = !mockExclusion.active;

      await toggle.vm.$emit('change', newStatus);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        title: 'Failed to update the exclusion:',
      });
    });
  });
});
